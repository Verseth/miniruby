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

  end
end