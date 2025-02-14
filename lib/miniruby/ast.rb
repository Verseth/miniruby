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
      attr_reader :span

      sig { params(span: Span).void }
      def initialize(span)
        @span = span
      end

      # Get the Ruby-like representation of the AST
      sig { abstract.returns(String) }
      def to_s; end

      # Inspect the AST in the S-expression format
      sig { abstract.params(indent: Integer).returns(String) }
      def inspect(indent = 0); end
    end

    # Represents an invalid node
    class InvalidNode < ExpressionNode
      sig { returns(Token) }
      attr_reader :token

      sig { params(span: Span, token: Token).void }
      def initialize(span, token)
        @span = span
        @token = token
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(InvalidNode)

        token == other.token
      end

      sig { override.returns(String) }
      def to_s
        "<invalid: `#{token}`>"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}(invalid #{token.inspect})"
      end
    end

    # Represents a program
    class ProgramNode < Node
      sig { returns(T::Array[StatementNode]) }
      attr_reader :statements

      sig { params(span: Span, statements: T::Array[StatementNode]).void }
      def initialize(span, statements)
        @span = span
        @statements = statements
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(ProgramNode)

        @statements == other.statements
      end

      sig { override.returns(String) }
      def to_s
        buffer = String.new

        @statements.each do |stmt|
          buffer << stmt
        end

        buffer
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        buff = String.new

        buff << "#{INDENT_UNIT * indent}(program"
        @statements.each do |stmt|
          buff << "\n"
          buff << stmt.inspect(indent + 1)
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

      sig { params(span: Span, expression: ExpressionNode).void }
      def initialize(span, expression)
        @span = span
        @expression = expression
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(ExpressionStatementNode)

        @expression == other.expression
      end

      sig { override.returns(String) }
      def to_s
        "#{@expression}\n"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
       "#{INDENT_UNIT * indent}(expr_stmt #{@expression.inspect(0)})"
      end
    end

    # Represents an expression like `2 + 3`
    # that can be a part of a larger expression/statement like `2 + 3 - 5`
    class ExpressionNode < Node
      abstract!
    end

    # Represents an expression with a binary operator like `2 + 3`, `a == 4`, `5 < 2`
    class BinaryExpressionNode < ExpressionNode
      sig { returns(Token) }
      attr_reader :operator

      sig { returns(ExpressionNode) }
      attr_reader :left

      sig { returns(ExpressionNode) }
      attr_reader :right

      sig { params(span: Span, op: Token, left: ExpressionNode, right: ExpressionNode).void }
      def initialize(span, op, left, right)
        @span = span
        @operator = op
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

      sig { override.returns(String) }
      def to_s
        "#{@left} #{@operator} #{@right}"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        buff = String.new
        buff << "#{INDENT_UNIT * indent}(bin_expr"

        buff << "\n" << @operator.to_s
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

      sig { params(span: Span, value: String).void }
      def initialize(span, value)
        @span = span
        @value = value
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(IdentifierNode)

        @value == other.value
      end

      sig { override.returns(String) }
      def to_s
        @value
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

      sig { params(span: Span, ident: ExpressionNode, val: ExpressionNode).void }
      def initialize(span, ident, val)
        @span = span
        @target = ident
        @value = val
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(AssignmentExpressionNode)

        @target == other.target &&
          @value == other.value
      end

      sig { override.returns(String) }
      def to_s
        "#{@target} = #{@value}"
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

      sig { params(span: Span, op: Token, val: ExpressionNode).void }
      def initialize(span, op, val)
        @span = span
        @operator = op
        @value = val
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(UnaryExpressionNode)

        @operator == other.operator &&
          @value == other.value
      end

      sig { override.returns(String) }
      def to_s
        "#{@operator}#{@value}"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        buff = String.new
        buff << "#{INDENT_UNIT * indent}(unary_expr"

        buff << "\n" << @operator.to_s
        buff << "\n" << @value.inspect(indent + 1)

        buff << ')'
        buff
      end
    end

    # Represents a return like `return 3`, `return 1 + 5 * a`
    class ReturnExpressionNode < ExpressionNode
      sig { returns(ExpressionNode) }
      attr_reader :value

      sig { params(span: Span, val: ExpressionNode).void }
      def initialize(span, val)
        @span = span
        @value = val
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(ReturnExpressionNode)

        @value == other.value
      end

      sig { override.returns(String) }
      def to_s
        "return #{@value}"
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}(return #{@value.inspect})"
      end
    end

    # Represents a false literal eg. `false`
    class FalseLiteralNode < ExpressionNode
      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        other.is_a?(FalseLiteralNode)
      end

      sig { override.returns(String) }
      def to_s
        'false'
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}false"
      end
    end

    # Represents a true literal eg. `true`
    class TrueLiteralNode < ExpressionNode
      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        other.is_a?(TrueLiteralNode)
      end

      sig { override.returns(String) }
      def to_s
        'true'
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}true"
      end
    end

    # Represents a nil literal eg. `nil`
    class NilLiteralNode < ExpressionNode
      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        other.is_a?(NilLiteralNode)
      end

      sig { override.returns(String) }
      def to_s
        'nil'
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}nil"
      end
    end

    # Represents a float literal eg. `123.5`
    class FloatLiteralNode < ExpressionNode
      sig { returns(String) }
      attr_reader :value

      sig { params(span: Span, value: String).void }
      def initialize(span, value)
        @span = span
        @value = value
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(FloatLiteralNode)

        value == other.value
      end

      sig { override.returns(String) }
      def to_s
        value
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

      sig { params(span: Span, value: String).void }
      def initialize(span, value)
        @span = span
        @value = value
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(IntegerLiteralNode)

        value == other.value
      end

      sig { override.returns(String) }
      def to_s
        value
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

      sig { params(span: Span, value: String).void }
      def initialize(span, value)
        @span = span
        @value = value
      end

      sig { params(other: Object).returns(T::Boolean) }
      def ==(other)
        return false unless other.is_a?(StringLiteralNode)

        value == other.value
      end

      sig { override.returns(String) }
      def to_s
        value.inspect
      end

      sig { override.params(indent: Integer).returns(String) }
      def inspect(indent = 0)
        "#{INDENT_UNIT * indent}#{value.inspect}"
      end
    end

  end
end
