# typed: strong
# frozen_string_literal: true

require 'set'

module MiniRuby
  # Represents a single token (word) produced by the lexer.
  class Token
    extend T::Sig

    class << self
      extend T::Sig

      # Converts a token type into a human-readable string.
      sig { params(type: Symbol).returns(String) }
      def type_to_string(type)
        case type
        when NONE
          'NONE'
        when END_OF_FILE
          'END_OF_FILE'
        when ERROR
          'ERROR'
        when COMMA
          ','
        when SEMICOLON
          ';'
        when NEWLINE
          'NEWLINE'
        when EQUAL
          '='
        when BANG
          '!'
        when EQUAL_EQUAL
          '=='
        when NOT_EQUAL
          '!='
        when GREATER
          '>'
        when GREATER_EQUAL
          '>='
        when LESS
          '<'
        when LESS_EQUAL
          '<='
        when PLUS
          '+'
        when MINUS
          '-'
        when STAR
          '*'
        when SLASH
          '/'
        when FLOAT
          'FLOAT'
        when INTEGER
          'INTEGER'
        when STRING
          'STRING'
        when IDENTIFIER
          'IDENTIFIER'
        when WHILE
          'while'
        when RETURN
          'return'
        when false
          'false'
        when true
          'true'
        when NIL
          'nil'
        else
          '<invalid>'
        end
      end
    end

    sig { returns(Symbol) }
    attr_reader :type

    sig { returns(T.nilable(String)) }
    attr_reader :value

    sig { returns(Span) }
    attr_reader :span

    sig { params(type: Symbol, span: Span, value: T.nilable(String)).void }
    def initialize(type, span, value = nil)
      @type = type
      @span = span
      @value = value
    end

    sig { params(other: Object).returns(T::Boolean) }
    def ==(other)
      return false unless other.is_a?(Token)

      type == other.type && value == other.value && span == other.span
    end

    sig { returns(String) }
    def inspect
      return "Token(#{type.inspect}, #{span.inspect})" if value.nil?

      "Token(#{type.inspect}, #{span.inspect}, #{value.inspect})"
    end

    sig { returns(T::Boolean) }
    def equality_operator?
      case @type
      when EQUAL_EQUAL, NOT_EQUAL
        true
      else
        false
      end
    end

    sig { returns(T::Boolean) }
    def additive_operator?
      case @type
      when PLUS, MINUS
        true
      else
        false
      end
    end

    sig { returns(T::Boolean) }
    def multiplicative_operator?
      case @type
      when STAR, SLASH
        true
      else
        false
      end
    end

    sig { returns(T::Boolean) }
    def comparison_operator?
      case @type
      when GREATER, GREATER_EQUAL, LESS, LESS_EQUAL
        true
      else
        false
      end
    end

    # Converts a token into a human-readable string.
    sig { returns(String) }
    def to_s
      case type
      when NONE
        'NONE'
      when END_OF_FILE
        'END_OF_FILE'
      when ERROR
        "<error: #{value}>"
      when COMMA
        ','
      when SEMICOLON
        ';'
      when NEWLINE
        'NEWLINE'
      when EQUAL
        '='
      when BANG
        '!'
      when EQUAL_EQUAL
        '=='
      when NOT_EQUAL
        '!='
      when GREATER
        '>'
      when GREATER_EQUAL
        '>='
      when LESS
        '<'
      when LESS_EQUAL
        '<='
      when PLUS
        '+'
      when MINUS
        '-'
      when STAR
        '*'
      when SLASH
        '/'
      when FLOAT, INTEGER, IDENTIFIER
        value.to_s
      when STRING
        T.cast(value.inspect, String)
      when false
        'false'
      when true
        'true'
      when NIL
        'nil'
      when IF
        'if'
      when WHILE
        'while'
      when RETURN
        'return'
      else
        '<invalid>'
      end
    end

    # String containing all valid decimal digits
    DIGITS = '0123456789'
    # String containing all valid hexadecimal digits
    HEX_DIGITS = '0123456789abcdefABCDEF'

    # Set of all keywords
    KEYWORDS = T.let(
      Set[
        'false',
        'true',
        'nil',
        'if',
        'while',
        'return'
      ],
      T::Set[String],
    )

    # List of all token types
    # ------------------------

    # Represents no token, a placeholder
    NONE = :none
    # Signifies that the entire string/file has been processed,
    # there will be no more tokens
    END_OF_FILE = :end_of_file
    # Holds an error message, means that the string/file could not be
    # successfully processed
    ERROR = :error
    # Comma `,`
    COMMA = :comma
    # Semicolon `;`
    SEMICOLON = :semicolon
    # Newline
    NEWLINE = :newline
    # Equal `=`
    EQUAL = :equal
    # Bang `!`
    BANG = :bang
    # Equal `==`
    EQUAL_EQUAL = :equal_equal
    # Equal `!=`
    NOT_EQUAL = :not_equal
    # Greater than `>`
    GREATER = :greater
    # Greater equal `>=`
    GREATER_EQUAL = :greater_equal
    # Less than `<`
    LESS = :less
    # Less equal `<=`
    LESS_EQUAL = :less_equal
    # Plus `+`
    PLUS = :plus
    # Minus `-`
    MINUS = :minus
    # Star `*`
    STAR = :star
    # Slash `/`
    SLASH = :slash
    # Integer literal eg. `123`
    INTEGER = :integer
    # Float literal eg. `12.3`
    FLOAT = :float
    # String literal eg. `"foo"`
    STRING = :string
    # Identifier eg. `foo`
    IDENTIFIER = :identifier

    # Keyword `false`
    FALSE = :false
    # Keyword `true`
    TRUE = :true
    # Keyword `nil`
    NIL = :nil
    # Keyword `if`
    IF = :if
    # Keyword `while`
    WHILE = :while
    # Keyword `return`
    RETURN = :return
  end
end
