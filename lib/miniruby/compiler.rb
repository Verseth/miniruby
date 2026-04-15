# typed: strict
# frozen_string_literal: true

require_relative 'call_info'

module MiniRuby
  # MiniRuby bytecode compiler.
  # Takes in an AST and produces a bytecode function
  # that can be executed by the VM.
  class Compiler
    extend T::Sig

    # Wraps a list of compiler errors.
    class Error < MiniRuby::Error
      extend T::Sig

      class << self
        extend T::Sig

        #: (*String errors) -> instance
        def [](*errors)
          new(errors)
        end
      end

      #: Array[String]
      attr_reader :errors

      #: (Array[String] errors) -> void
      def initialize(errors)
        @errors = errors
        super(@errors.join('; '))
      end

      #: (Object other) -> bool
      def ==(other)
        return false unless other.is_a?(Error)

        @errors == other.errors
      end

      #: -> String
      def inspect
        "#{self.class}#{@errors.inspect}"
      end
    end

    class << self
      extend T::Sig

      # Compile an AST node.
      #: (AST::ProgramNode node, ?name: String, ?filename: String, ?span: Span) -> BytecodeFunction
      def compile_ast(node, name: '<main>', filename: '<main>', span: Span::ZERO)
        compiler = new(name:, filename:, span:)
        compiler.compile_program(node)
        raise Error.new(compiler.errors) if compiler.err?

        compiler.bytecode
      end

      # Compile source code.
      #: (String source, ?name: String, ?filename: String) -> BytecodeFunction
      def compile_source(source, name: '<main>', filename: '<main>')
        result = Parser.parse(source)
        raise Error.new(result.errors) if result.err?

        node = result.ast
        compiler = new(name:, filename:, span: node.span)
        compiler.compile_program(node)
        raise Error.new(compiler.errors) if compiler.err?

        compiler.bytecode
      end
    end

    #: String
    attr_reader :name

    #: BytecodeFunction
    attr_reader :bytecode

    #: Integer
    attr_reader :predefined_locals

    #: Integer
    attr_reader :last_local_index

    #: Array[String]
    attr_reader :errors

    #: Hash[String, Integer]
    attr_reader :locals

    #: (name: String, ?filename: String, ?span: Span) -> void
    def initialize(name:, filename: '<main>', span: Span::ZERO)
      @name = name
      @span = span
      @bytecode = BytecodeFunction.new(name:, filename:, span:) #: BytecodeFunction
      @last_local_index = -1 #: Integer
      @predefined_locals = 1 #: Integer
      @errors = [] #: Array[String]
      @locals = {} #: Hash[String, Integer]

      # reserve a slot for `self`
      define_local('#self')
    end

    #: (AST::ProgramNode node) -> void
    def compile_program(node)
      compile_statements(node.statements)
      emit(Opcode::RETURN)
      prepare_locals
    end

    #: -> bool
    def err?
      @errors.length > 0
    end

    private

    #: -> void
    def prepare_locals
      local_count = @last_local_index + 1 - @predefined_locals
      return if local_count == 0

      new_instructions = String.new.b
      new_instructions << Opcode::PREP_LOCALS << local_count << @bytecode.instructions
      @bytecode.instructions = new_instructions
    end

    #: (Array[AST::StatementNode] statements) -> void
    def compile_statements(statements)
      statements.each.with_index do |statement, i|
        compile_statement(statement)
        emit(Opcode::POP) if i < statements.length - 1
      end
    end

    #: (AST::StatementNode node) -> void
    def compile_statement(node)
      case node
      when AST::ExpressionStatementNode
        compile_expression(node.expression)
      else
        raise ArgumentError, "invalid statement node: #{node.inspect}"
      end
    end

    #: (AST::ExpressionNode node) -> void
    def compile_expression(node)
      case node
      when AST::NilLiteralNode
        emit(Opcode::NIL)
      when AST::TrueLiteralNode
        emit(Opcode::TRUE)
      when AST::FalseLiteralNode
        emit(Opcode::FALSE)
      when AST::SelfLiteralNode
        emit(Opcode::SELF)
      when AST::IntegerLiteralNode
        emit_value(Integer(node.value))
      when AST::FloatLiteralNode
        emit_value(Float(node.value))
      when AST::StringLiteralNode
        emit_value(node.value)
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
      when AST::FunctionCallNode
        compile_function_call(node)
      end
    end

    #: (AST::FunctionCallNode node) -> void
    def compile_function_call(node)
      emit(Opcode::SELF)

      node.arguments.each do |arg|
        compile_expression(arg)
      end

      call_info = CallInfo.new(
        name:      node.name.to_sym,
        arg_count: node.arguments.length,
      )
      emit_load_value(call_info, Opcode::CALL)
    end

    #: (AST::WhileExpressionNode node) -> void
    def compile_while_expression(node)
      emit(Opcode::NIL)
      # loop start
      start = next_instruction_offset

      # condition and jump
      compile_expression(node.condition)
      loop_body_offset = emit_jump(Opcode::JUMP_UNLESS)

      # pop the return value of the last iteration
      emit(Opcode::POP)

      # then branch
      compile_statements(node.then_body)

      # jump to loop condition
      emit_loop(start)

      # after loop
      patch_jump(loop_body_offset)
    end

    #: (AST::IfExpressionNode node) -> void
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

    #: (AST::ReturnExpressionNode node) -> void
    def compile_return_expression(node)
      value = node.value
      if value
        compile_expression(value)
      else
        emit(Opcode::NIL)
      end

      emit(Opcode::RETURN)
    end

    #: (AST::IdentifierNode node) -> void
    def compile_identifier(node)
      local_name = node.value
      index = get_local(local_name)
      return if index < 0

      emit(Opcode::GET_LOCAL, index)
    end

    #: (AST::AssignmentExpressionNode node) -> void
    def compile_assignment_expression(node)
      compile_expression(node.value)

      target = node.target
      raise ArgumentError, "invalid assignment target: #{target.inspect}" unless target.is_a?(AST::IdentifierNode)

      local_name = target.value
      index = define_or_get_local(local_name)
      return if index < 0

      emit(Opcode::SET_LOCAL, index)
    end

    #: (AST::BinaryExpressionNode node) -> void
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
        raise ArgumentError, "invalid binary operator: #{node.operator.type_name}"
      end
    end

    #: (AST::UnaryExpressionNode node) -> void
    def compile_unary_expression(node)
      compile_expression(node.value)

      case node.operator.type
      when Token::MINUS
        emit(Opcode::NEGATE)
      when Token::BANG
        emit(Opcode::NOT)
      when Token::PLUS
      else
        raise ArgumentError, "invalid unary operator: #{node.operator.type_name}"
      end
    end

    # Register a local variable. Returns the index of the local.
    #: (String name) -> Integer
    def get_local(name)
      index = @locals[name]
      return index if index

      @errors << "undefined local: #{name}"
      -1
    end

    # Get a local variable or define it if it does not exist. Returns the index of the local.
    #: (String name) -> Integer
    def define_or_get_local(name)
      index = @locals[name]
      return index if index

      define_local(name)
    end

    # The maximum number of local variables
    MAX_LOCALS = 256

    #: (String name) -> Integer
    def define_local(name)
      if @last_local_index == MAX_LOCALS - 1
        @errors << "exceeded the maximum number of local variables (#{MAX_LOCALS}): #{name}"
        return -1
      end

      @locals[name] = @last_local_index += 1
    end

    # Emit the given bytes in the bytecode function
    #: (*Integer bytes) -> void
    def emit(*bytes)
      @bytecode.add_bytes!(bytes)
    end

    #: (Object value) -> void
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
    #: (Object value, ?Integer opcode) -> Integer
    def emit_load_value(value, opcode = Opcode::LOAD_VALUE)
      index = @bytecode.add_value(value)
      if index >= MAX_VALUES
        @errors << "value pool limit reached: #{MAX_VALUES}"
        return -1
      end

      emit(opcode, index)
      index
    end

    # Emit an instruction that jumps forward with a placeholder offset.
    # Returns the offset of placeholder value that has to be patched.
    #: (Integer opcode) -> Integer
    def emit_jump(opcode)
      emit(opcode, 0xff)
      next_instruction_offset - 1
    end

    # Emit an instruction that jumps back to the given Bytecode offset.
    #: (Integer start_offset) -> void
    def emit_loop(start_offset)
      emit(Opcode::LOOP)
      offset = next_instruction_offset - start_offset + 2
      if offset > MAX_JUMP
        @errors << "too many bytes to jump backward: #{offset}"
      end

      emit(offset)
    end

    # Return the offset of the next instruction.
    #: -> Integer
    def next_instruction_offset
      @bytecode.instructions.length
    end

    # The maximum jump value
    MAX_JUMP = 255

    # Overwrite the placeholder operand of a jump instruction
    #: (Integer offset, ?Integer target) -> void
    def patch_jump(offset, target = next_instruction_offset - offset - 1)
      if target > MAX_JUMP
        @errors << "too many bytes to jump over: #{target}"
        return
      end

      @bytecode.instructions.setbyte(offset, target)
    end

  end
end
