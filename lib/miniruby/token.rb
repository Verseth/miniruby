# typed: strong
# frozen_string_literal: true


module MiniRuby
  # Represents a single token (word) produced by the lexer.
  class Token
    extend T::Sig

    class << self
      extend T::Sig

      # Converts a token type into a human-readable string.
      #: (Symbol type) -> String
      def type_to_string(type)
        case type
        when NONE
          'NONE'
        when END_OF_FILE
          'END_OF_FILE'
        when ERROR
          'ERROR'
        when LPAREN
          '('
        when RPAREN
          ')'
        when COMMA
          ','
        when DOT
          '.'
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
        else
          t = type.to_s
          return t if KEYWORDS.include?(t)

          '<invalid>'
        end
      end
    end

    #: Symbol
    attr_reader :type

    #: String?
    attr_reader :value

    #: Span
    attr_reader :span

    #: (Symbol type, Span span, ?String? value) -> void
    def initialize(type, span, value = nil)
      @type = type
      @span = span
      @value = value
    end

    #: (Object other) -> bool
    def ==(other)
      return false unless other.is_a?(Token)

      type == other.type && value == other.value
    end

    #: -> String
    def inspect
      return "Token(#{type.inspect}, #{span.inspect})" if value.nil?

      "Token(#{type.inspect}, #{span.inspect}, #{value.inspect})"
    end

    #: -> bool
    def equality_operator?
      case @type
      when EQUAL_EQUAL, NOT_EQUAL
        true
      else
        false
      end
    end

    #: -> bool
    def additive_operator?
      case @type
      when PLUS, MINUS
        true
      else
        false
      end
    end

    #: -> bool
    def multiplicative_operator?
      case @type
      when STAR, SLASH
        true
      else
        false
      end
    end

    #: -> bool
    def comparison_operator?
      case @type
      when GREATER, GREATER_EQUAL, LESS, LESS_EQUAL
        true
      else
        false
      end
    end

    #: -> String
    def type_name
      self.class.type_to_string(@type)
    end

    # Converts a token into a human-readable string.
    #: -> String
    def to_s
      case type
      when NONE
        'NONE'
      when END_OF_FILE
        'END_OF_FILE'
      when ERROR
        "<error: #{value}>"
      when LPAREN
        '('
      when RPAREN
        ')'
      when COMMA
        ','
      when DOT
        '.'
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
        value.inspect #: as String
      else
        t = type.to_s
        return t if KEYWORDS.include?(t)

        '<invalid>'
      end
    end

    # String containing all valid decimal digits
    DIGITS = '0123456789'
    # String containing all valid hexadecimal digits
    HEX_DIGITS = '0123456789abcdefABCDEF'

    # Set of all keywords
    KEYWORDS = Set[
      'false',
      'true',
      'nil',
      'if',
      'unless',
      'while',
      'return',
      'break',
      'next',
      'end',
      'else',
      'self',
    ] #: Set[String]

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
    # Left parentheses `(`
    LPAREN = :lparen
    # Right parentheses `)`
    RPAREN = :rparen
    # Comma `,`
    COMMA = :comma
    # Dot `.`
    DOT = :dot
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
    # Keyword `unless`
    UNLESS = :unless
    # Keyword `while`
    WHILE = :while
    # Keyword `return`
    RETURN = :return
    # Keyword `break`
    BREAK = :break
    # Keyword `next`
    NEXT = :next
    # Keyword `end`
    END_K = :end
    # Keyword `else`
    ELSE = :else
    # Keyword `self`
    SELF = :self
  end
end
