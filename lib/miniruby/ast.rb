# typed: strong
# frozen_string_literal: true

module MiniRuby
  # Contains the definitions of all AST (Abstract Syntax Tree) nodes.
  # AST is the data structure that is returned by the parser.
  module AST
    # A string that represents a single level of indentation
    # in S-expressions
    INDENT_UNIT = '  '

    # Abstract class representing an AST node.
    class Node
      extend T::Sig
      extend T::Helpers

      abstract!

      sig { returns(Span) }
      attr_accessor :span

      sig { params(span: Span).void }
      def initialize(span: Span::ZERO)
        @span = span
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        other.is_a?(self.class)
      end

      # Get the Ruby-like representation of the AST
      sig { abstract.params(indent: Integer).returns(String) }
      def to_s(indent = 0); end

      # Inspect the AST in the S-expression format
      sig { abstract.params(indent: Integer).returns(String) }
      def inspect(indent = 0); end
    end

    # Represents a program
    class ProgramNode < Node
      sig { returns(T::Array[StatementNode]) }
      attr_reader :statements

      sig { params(statements: T::Array[StatementNode], span: Span).void }
      def initialize(statements:, span: Span::ZERO)
        @span = span
        @statements = statements
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(ProgramNode)

        @statements == other.statements
      end

      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        buffer = String.new

        @statements.each do |stmt|
          buffer << stmt.to_s(indent)
        end

        buffer
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        buff = String.new

        buff << "#{INDENT_UNIT * indent}(program"
        @statements.each do |stmt|
          buff << "\n" << stmt.inspect(indent + 1)
        end
        buff << ')'
        buff
      end
    end

    # Represents a single statement (line) of code
    class StatementNode < Node
      abstract!
    end

    # Represents a statement with an expression like `2 + 3 - 5;`
    class ExpressionStatementNode < StatementNode
      sig { returns(ExpressionNode) }
      attr_reader :expression

      sig { params(expression: ExpressionNode, span: Span).void }
      def initialize(expression:, span: Span::ZERO)
        @span = span
        @expression = expression
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(ExpressionStatementNode)

        @expression == other.expression
      end

      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        "#{INDENT_UNIT * indent}#{@expression}\n"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        buff = String.new
        buff << "#{INDENT_UNIT * indent}(expr_stmt"
        buff << "\n" << @expression.inspect(indent + 1)
        buff << ')'
        buff
      end
    end

    # Represents an expression like `2 + 3`
    # that can be a part of a larger expression/statement like `2 + 3 - 5`
    class ExpressionNode < Node
      abstract!
    end

    # Represents an invalid node
    class InvalidNode < ExpressionNode
      sig { returns(Token) }
      attr_reader :token

      sig { params(token: Token, span: Span).void }
      def initialize(token:, span: Span::ZERO)
        @span = span
        @token = token
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(InvalidNode)

        @token == other.token
      end

      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        "#{INDENT_UNIT * indent}<invalid: `#{token}`>"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}(invalid #{token.inspect})"
      end
    end

    # Represents an expression with a binary operator like `2 + 3`, `a == 4`, `5 < 2`
    class BinaryExpressionNode < ExpressionNode
      sig { returns(Token) }
      attr_reader :operator

      sig { returns(ExpressionNode) }
      attr_reader :left

      sig { returns(ExpressionNode) }
      attr_reader :right

      sig { params(operator: Token, left: ExpressionNode, right: ExpressionNode, span: Span).void }
      def initialize(operator:, left:, right:, span: Span::ZERO)
        @span = span
        @operator = operator
        @left = left
        @right = right
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(BinaryExpressionNode)

        @operator == other.operator &&
          @left == other.left &&
          @right == other.right
      end

      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        "#{INDENT_UNIT * indent}#{@left} #{@operator} #{@right}"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        buff = String.new
        buff << "#{INDENT_UNIT * indent}(bin_expr"

        buff << "\n#{INDENT_UNIT * (indent + 1)}#{@operator}"
        buff << "\n" << @left.inspect(indent + 1)
        buff << "\n" << @right.inspect(indent + 1)

        buff << ')'
        buff
      end
    end

    # Represents an identifier like `a`, `foo`
    class IdentifierNode < ExpressionNode
      sig { returns(String) }
      attr_reader :value

      sig { params(value: String, span: Span).void }
      def initialize(value:, span: Span::ZERO)
        @span = span
        @value = value
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(IdentifierNode)

        @value == other.value
      end

      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        "#{INDENT_UNIT * indent}#{@value}"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}#{@value}"
      end
    end

    # Represents an assignment expression like `a = 5`, `b = 2 + 5 * 5`
    class AssignmentExpressionNode < ExpressionNode
      sig { returns(ExpressionNode) }
      attr_reader :target

      sig { returns(ExpressionNode) }
      attr_reader :value

      sig { params(target: ExpressionNode, value: ExpressionNode, span: Span).void }
      def initialize(target:, value:, span: Span::ZERO)
        @span = span
        @target = target
        @value = value
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(AssignmentExpressionNode)

        @target == other.target &&
          @value == other.value
      end

      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        "#{INDENT_UNIT * indent}#{@target} = #{@value}"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        buff = String.new
        buff << "#{INDENT_UNIT * indent}(assignment"

        buff << "\n" << @target.inspect(indent + 1)
        buff << "\n" << @value.inspect(indent + 1)

        buff << ')'
        buff
      end
    end

    # Represents an expression with a unary operator like `+3`, `-a`
    class UnaryExpressionNode < ExpressionNode
      sig { returns(Token) }
      attr_reader :operator

      sig { returns(ExpressionNode) }
      attr_reader :value

      sig { params(operator: Token, value: ExpressionNode, span: Span).void }
      def initialize(operator:, value:, span: Span::ZERO)
        @span = span
        @operator = operator
        @value = value
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(UnaryExpressionNode)

        @operator == other.operator &&
          @value == other.value
      end

      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        "#{INDENT_UNIT * indent}#{@operator}#{@value}"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        buff = String.new
        buff << "#{INDENT_UNIT * indent}(unary_expr"

        buff << "\n#{INDENT_UNIT * (indent + 1)}#{@operator}"
        buff << "\n" << @value.inspect(indent + 1)

        buff << ')'
        buff
      end
    end

    # Represents a return like `return 3`, `return 1 + 5 * a`
    class ReturnExpressionNode < ExpressionNode
      sig { returns(T.nilable(ExpressionNode)) }
      attr_reader :value

      sig { params(value: T.nilable(ExpressionNode), span: Span).void }
      def initialize(value: nil, span: Span::ZERO)
        @span = span
        @value = value
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(ReturnExpressionNode)

        @value == other.value
      end

      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        buff = String.new
        buff << "#{INDENT_UNIT * indent}return"
        buff << " #{@value}" if @value

        buff
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        buff = String.new
        buff << "#{INDENT_UNIT * indent}(return"
        buff << " #{@value.inspect}" if @value
        buff << ')'

        buff
      end
    end

    # Represents an if expression like `if foo; a = 5; end`
    class IfExpressionNode < ExpressionNode
      sig { returns(ExpressionNode) }
      attr_reader :condition

      sig { returns(T::Array[StatementNode]) }
      attr_reader :then_body

      sig { returns(T.nilable(T::Array[StatementNode])) }
      attr_reader :else_body

      sig do
        params(
          condition: ExpressionNode,
          then_body: T::Array[StatementNode],
          else_body: T.nilable(T::Array[StatementNode]),
          span:      Span,
        ).void
      end
      def initialize(condition:, then_body:, else_body: nil, span: Span::ZERO)
        @span = span
        @condition = condition
        @then_body = then_body
        @else_body = else_body
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(IfExpressionNode)

        @condition == other.condition &&
          @then_body == other.then_body &&
          @else_body == other.else_body
      end

      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        buff = String.new
        indent_str = INDENT_UNIT * indent
        buff << "#{indent_str}if #{@condition}\n"

        @then_body.each do |stmt|
          buff << stmt.to_s(indent + 1)
        end

        els = @else_body
        if els
          buff << "#{indent_str}else\n"
          els.each do |stmt|
            buff << stmt.to_s(indent + 1)
          end
        end
        buff << "#{indent_str}end"

        buff
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        buff = String.new
        buff << "#{INDENT_UNIT * indent}(if"

        buff << "\n" << @condition.inspect(indent + 1)

        buff << "\n#{INDENT_UNIT * (indent + 1)}(then"
        @then_body.each do |stmt|
          buff << "\n" << stmt.inspect(indent + 2)
        end
        buff << ')'

        els = @else_body
        if els
          buff << "\n#{INDENT_UNIT * (indent + 1)}(else"
          els.each do |stmt|
            buff << "\n" << stmt.inspect(indent + 2)
          end
          buff << ')'
        end

        buff << ')'
        buff
      end
    end

    # Represents a while expression like `while foo; a = 5; end`
    class WhileExpressionNode < ExpressionNode
      sig { returns(ExpressionNode) }
      attr_reader :condition

      sig { returns(T::Array[StatementNode]) }
      attr_reader :then_body

      sig do
        params(
          condition: ExpressionNode,
          then_body: T::Array[StatementNode],
          span:      Span,
        ).void
      end
      def initialize(condition:, then_body:, span: Span::ZERO)
        @span = span
        @condition = condition
        @then_body = then_body
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(WhileExpressionNode)

        @condition == other.condition &&
          @then_body == other.then_body
      end

      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        buff = String.new
        indent_str = INDENT_UNIT * indent
        buff << "#{indent_str}while #{@condition}\n"

        @then_body.each do |stmt|
          buff << stmt.to_s(indent + 1)
        end

        buff << "#{indent_str}end"

        buff
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        buff = String.new
        buff << "#{INDENT_UNIT * indent}(while"

        buff << "\n" << @condition.inspect(indent + 1)

        buff << "\n#{INDENT_UNIT * (indent + 1)}(then"
        @then_body.each do |stmt|
          buff << "\n" << stmt.inspect(indent + 2)
        end
        buff << ')'

        buff << ')'
        buff
      end
    end

    # Represents a function call like `foo(1, bar)`
    class FunctionCallNode < ExpressionNode
      sig { returns(String) }
      attr_reader :name

      sig { returns(T::Array[ExpressionNode]) }
      attr_reader :arguments

      sig do
        params(
          name:      String,
          arguments: T::Array[ExpressionNode],
          span:      Span,
        ).void
      end
      def initialize(name:, arguments: [], span: Span::ZERO)
        @span = span
        @name = name
        @arguments = arguments
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(FunctionCallNode)

        @name == other.name &&
          @arguments == other.arguments
      end

      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        buff = String.new
        indent_str = INDENT_UNIT * indent

        buff << "#{indent_str}#{@name}("
        @arguments.each.with_index do |arg, i|
          buff << ', ' if i > 0
          buff << arg.to_s
        end
        buff << ')'

        buff
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        buff = String.new
        buff << "#{INDENT_UNIT * indent}(call\n"

        buff << "#{INDENT_UNIT * (indent + 1)}#{@name}"
        @arguments.each do |arg|
          buff << "\n" << arg.inspect(indent + 1)
        end
        buff << ')'

        buff
      end
    end

    # Represents a false literal eg. `false`
    class FalseLiteralNode < ExpressionNode
      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        "#{INDENT_UNIT * indent}false"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}false"
      end
    end

    # Represents a true literal eg. `true`
    class TrueLiteralNode < ExpressionNode
      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        "#{INDENT_UNIT * indent}true"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}true"
      end
    end

    # Represents a nil literal eg. `nil`
    class NilLiteralNode < ExpressionNode
      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        "#{INDENT_UNIT * indent}nil"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}nil"
      end
    end

    # Represents a self literal eg. `self`
    class SelfLiteralNode < ExpressionNode
      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        "#{INDENT_UNIT * indent}self"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}self"
      end
    end

    # Represents a float literal eg. `123.5`
    class FloatLiteralNode < ExpressionNode
      sig { returns(String) }
      attr_reader :value

      sig { params(value: String, span: Span).void }
      def initialize(value:, span: Span::ZERO)
        @span = span
        @value = value
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(FloatLiteralNode)

        @value == other.value
      end

      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        "#{INDENT_UNIT * indent}#{value}"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}#{value}"
      end
    end

    # Represents an integer literal eg. `123`
    class IntegerLiteralNode < ExpressionNode
      sig { returns(String) }
      attr_reader :value

      sig { params(value: String, span: Span).void }
      def initialize(value:, span: Span::ZERO)
        @span = span
        @value = value
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(IntegerLiteralNode)

        @value == other.value
      end

      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        "#{INDENT_UNIT * indent}#{value}"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}#{value}"
      end
    end

    # Represents a string literal eg. `"foo"`
    class StringLiteralNode < ExpressionNode
      sig { returns(String) }
      attr_reader :value

      sig { params(value: String, span: Span).void }
      def initialize(value:, span: Span::ZERO)
        @span = span
        @value = value
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(StringLiteralNode)

        @value == other.value
      end

      sig { override.params(indent: Integer).returns(String) }
      def to_s(indent = 0)
        "#{INDENT_UNIT * indent}#{value.inspect}"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}#{value.inspect}"
      end
    end

  end
end
