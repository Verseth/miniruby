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

      # Get the Ruby-like representation of the AST
      sig { abstract.returns(String) }
      def to_s; end

      # Inspect the AST in the S-expression format
      sig { abstract.params(indent: Integer).returns(String) }
      def inspect(indent = 0); end
    end

    # Represents an invalid node
    class InvalidNode < Node
      sig { returns(Token) }
      attr_reader :token

      sig { params(token: Token).void }
      def initialize(token)
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

    # Represents a false literal eg. `false`
    class FalseLiteralNode < Node
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
    class TrueLiteralNode < Node
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
    class NilLiteralNode < Node
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
    class FloatLiteralNode < Node
      sig { returns(String) }
      attr_reader :value

      sig { params(value: String).void }
      def initialize(value)
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
    class IntegerLiteralNode < Node
      sig { returns(String) }
      attr_reader :value

      sig { params(value: String).void }
      def initialize(value)
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
    class StringLiteralNode < Node
      sig { returns(String) }
      attr_reader :value

      sig { params(value: String).void }
      def initialize(value)
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
