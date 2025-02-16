# typed: strict
# frozen_string_literal: true

module MiniRuby
  # MiniRuby bytecode compiler.
  # Takes in an AST and produces a bytecode function
  # that can be executed by the VM.
  class Compiler
    extend T::Sig

    sig { returns(String) }
    attr_reader :name

    sig { returns(BytecodeFunction) }
    attr_reader :bytecode

    sig { returns(Integer) }
    attr_reader :predefined_locals

    sig { returns(Integer) }
    attr_reader :last_local_index

    sig { returns(T::Array[String]) }
    attr_reader :errors

    sig { returns(T::Hash[String, Integer]) }
    attr_reader :locals

    sig { params(name: String, filename: String, span: Span).void }
    def initialize(name:, filename: '<main>', span: Span::ZERO)
      @name = name
      @span = span
      @bytecode = T.let(BytecodeFunction.new(name:, filename:, span:), BytecodeFunction)
      @last_local_index = T.let(-1, Integer)
      @predefined_locals = T.let(1, Integer)
      @errors = T.let([], T::Array[String])
      @locals = T.let({}, T::Hash[String, Integer])

      # reserve a slot for `self`
      define_local('#self')
    end

    private

    sig { params(node: AST::ProgramNode).void }
    def compile_program(node)
      compile_statements(node.statements)
      emit(Opcode::RETURN)
      prepare_locals()
    end

    sig { void }
    def prepare_locals
      local_count = @last_local_index + 1 - @predefined_locals
      return if local_count == 0

      new_instructions = String.new.b
      new_instructions << Opcode::PREP_LOCALS << local_count << @bytecode.instructions
      @bytecode.instructions = new_instructions
    end

    sig { params(statements: T::Array[AST::StatementNode]).void }
    def compile_statements(statements)
      statements.each.with_index do |statement, i|
        compile_statement(statement)
        emit(Opcode::POP) if i < statements.length - 1
      end
    end

    sig { params(node: AST::StatementNode).void }
    def compile_statement(node)
      case node
      when AST::ExpressionStatementNode
        compile_expression(node.expression)
      else
        raise "invalid statement node: #{node.inspect}"
      end
    end

    sig { params(node: AST::ExpressionNode).void }
    def compile_expression(node)
      case node
      when AST::NilLiteralNode
        emit(Opcode::NIL)
      when AST::TrueLiteralNode
        emit(Opcode::TRUE)
      when AST::FalseLiteralNode
        emit(Opcode::FALSE)
      when AST::IntegerLiteralNode
        emit_value(Integer(node.value))
      when AST::FloatLiteralNode
        emit_value(Float(node.value))
      when AST::UnaryExpressionNode
        compile_unary_expression(node)
      when AST::BinaryExpressionNode
        compile_binary_expression(node)
      when AST::AssignmentExpressionNode
        compile_assignment_expression(node)
      when AST::IdentifierNode
        compile_identifier(node)
      when AST::ReturnExpressionNode
        compile_return_expression(node)
      when AST::IfExpressionNode
        compile_if_expression(node)
      when AST::WhileExpressionNode
        compile_while_expression(node)
      end
    end

    sig { params(node: AST::WhileExpressionNode).void }
    def compile_while_expression(node)
      emit(Opcode::NIL)
      # loop start
      start = next_instruction_offset

      # condition and jump
      compile_expression(node.condition)
      loop_body_offset = emit_jump(Opcode::JUMP_UNLESS)

      emit(Opcode::POP, )

      # then branch
      compile_statements(node.then_body)
      loop_body_offset = emit_jump(Opcode::JUMP)

      # else brach
      patch_jump(then_jump_offset)
      else_body = node.else_body
      if else_body
        compile_statements(else_body)
      else
        emit(Opcode::NIL)
      end

      # jump over else
      patch_jump(else_jump_offset)
    end

    sig { params(node: AST::IfExpressionNode).void }
    def compile_if_expression(node)
      # condition and jump
      compile_expression(node.condition)
      then_jump_offset = emit_jump(Opcode::JUMP_UNLESS)

      # then branch
      compile_statements(node.then_body)
      else_jump_offset = emit_jump(Opcode::JUMP)

      # else brach
      patch_jump(then_jump_offset)
      else_body = node.else_body
      if else_body
        compile_statements(else_body)
      else
        emit(Opcode::NIL)
      end

      # jump over else
      patch_jump(else_jump_offset)
    end

    sig { params(node: AST::ReturnExpressionNode).void }
    def compile_return_expression(node)
      value = node.value
      if value
        compile_expression(value)
      else
        emit(Opcode::NIL)
      end

      emit(Opcode::RETURN)
    end

    sig { params(node: AST::IdentifierNode).void }
    def compile_identifier(node)
      local_name = node.value
      index = get_local(local_name)
      return if index < 0

      emit(Opcode::GET_LOCAL, index)
    end

    sig { params(node: AST::AssignmentExpressionNode).void }
    def compile_assignment_expression(node)
      compile_expression(node.value)

      target = node.target
      raise "invalid assignment target: #{target.inspect}" unless target.is_a?(AST::IdentifierNode)

      local_name = target.value
      index = define_or_get_local(local_name)
      return if index < 0

      emit(Opcode::SET_LOCAL, index)
    end

    sig { params(node: AST::BinaryExpressionNode).void }
    def compile_binary_expression(node)
      compile_expression(node.left)
      compile_expression(node.right)

      case node.operator.type
      when Token::PLUS
        emit(Opcode::ADD)
      when Token::MINUS
        emit(Opcode::SUBTRACT)
      when Token::STAR
        emit(Opcode::MULTIPLY)
      when Token::SLASH
        emit(Opcode::DIVIDE)
      when Token::EQUAL_EQUAL
        emit(Opcode::EQUAL)
      when Token::NOT_EQUAL
        emit(Opcode::EQUAL)
        emit(Opcode::NOT)
      when Token::GREATER
        emit(Opcode::GREATER)
      when Token::GREATER_EQUAL
        emit(Opcode::GREATER_EQUAL)
      when Token::LESS
        emit(Opcode::LESS)
      when Token::LESS_EQUAL
        emit(Opcode::LESS_EQUAL)
      else
        raise "invalid binary operator: #{node.operator.type_name}"
      end
    end

    sig { params(node: AST::UnaryExpressionNode).void }
    def compile_unary_expression(node)
      compile_expression(node.value)

      case node.operator.type
      when Token::MINUS
        emit(Opcode::NEGATE)
      when Token::BANG
        emit(Opcode::NOT)
      when Token::PLUS
      else
        raise "invalid unary operator: #{node.operator.type_name}"
      end
    end

    # Register a local variable. Returns the index of the local.
    sig { params(name: String).returns(Integer) }
    def get_local(name)
      index = @locals[name]
      return index if index

      @errors << "undefined local: #{name}"
      -1
    end

    # Get a local variable or define it if it does not exist. Returns the index of the local.
    sig { params(name: String).returns(Integer) }
    def define_or_get_local(name)
      index = @locals[name]
      return index if index

      define_local(name)
    end

    # The maximum number of local variables
    MAX_LOCALS = 256

    sig { params(name: String).returns(Integer) }
    def define_local(name)
      if @last_local_index == MAX_LOCALS-1
        @errors << "exceeded the maximum number of local variables (#{MAX_LOCALS}): #{name}"
        return -1
      end

      @locals[name] = @last_local_index += 1
    end

    # Emit the given bytes in the bytecode function
    sig { params(bytes: Integer).void }
    def emit(*bytes)
      @bytecode.add_bytes!(bytes)
    end

    sig { params(value: Object).void }
    def emit_value(value)
      case value
      when true
        emit(Opcode::TRUE)
      when false
        emit(Opcode::FALSE)
      when nil
        emit(Opcode::NIL)
      else
        emit_load_value(value)
      end
    end

    # The maximum number of values in the value pool
    MAX_VALUES = 256

    # Emits code that loads a value from the value pool
    sig { params(value: Object).returns(Integer) }
    def emit_load_value(value)
      index = @bytecode.add_value(value)
      return index if index < MAX_VALUES

      @errors << "value pool limit reached: #{MAX_VALUES}"
      return -1
    end

    # Emit an instruction that jumps forward with a placeholder offset.
    # Returns the offset of placeholder value that has to be patched.
    sig { params(opcode: Integer).returns(Integer) }
    def emit_jump(opcode)
      emit(opcode, 0xff)
      return next_instruction_offset - 1
    end

    # Return the offset of the next instruction.
    sig { returns(Integer) }
    def next_instruction_offset
      @bytecode.instructions.length
    end

    # The maximum jump value
    MAX_JUMP = 255

    # Overwrite the placeholder operand of a jump instruction
    sig { params(offset: Integer, target: Integer).void }
    def patch_jump(offset, target = next_instruction_offset-offset-1)
      if target > MAX_JUMP
        @errors << "too many bytes to jump over: #{target}"
        return
      end

      @bytecode.instructions.setbyte(offset, target)
    end

  end
end
