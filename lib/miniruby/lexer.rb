# typed: strict
# frozen_string_literal: true

require_relative 'token'

module MiniRuby
  # A lexical analyzer (tokenizer) for JSON
  class Lexer
    extend T::Sig
    extend T::Generic
    include Enumerable

    # Type parameter for `Enumerable`
    # Declares the type that the lexer returns for tokens
    Elem = type_member { { fixed: Token } }

    class << self
      extend T::Sig

      sig { params(source: String).returns(T::Array[Token]) }
      def lex(source)
        new(source).to_a
      end
    end

    sig { params(source: String).void }
    def initialize(source)
      @source = source

      # offset of the first character of the current lexeme
      @start_cursor = T.let(0, Integer)
      # offset of the next character
      @cursor = T.let(0, Integer)
    end

    sig { returns(Token) }
    def next
      return Token.new(Token::END_OF_FILE, Span.new(Position.new(0), Position.new(0))) unless more_tokens?

      scan_token
    end

    sig { override.params(block: T.nilable(T.proc.params(arg0: Token).void)).returns(T.untyped) }
    def each(&block)
      return enum_for(T.must(__method__)) unless block

      loop do
        tok = self.next
        break if tok.type == Token::END_OF_FILE

        block.call(tok)
      end

      self
    end

    private

    sig { returns(T::Boolean) }
    def more_tokens?
      @cursor < @source.length
    end

    sig { params(type: Symbol).returns(Token) }
    def token_with_consumed_value(type)
      token(type, token_value)
    end

    sig { params(type: Symbol, value: T.nilable(String)).returns(Token) }
    def token(type, value = nil)
      span = Span.new(Position.new(@start_cursor), Position.new(@cursor - 1))
      @start_cursor = @cursor
      Token.new(type, span, value)
    end

    # Returns the current token value.
    sig { returns(String) }
    def token_value
      T.must @source[@start_cursor...@cursor]
    end

    sig { returns([String, T::Boolean]) }
    def advance_char
      return '', false unless more_tokens?

      char = next_char

      @cursor += 1
      [char, true]
    end

    sig { returns(String) }
    def next_char
      T.must @source[@cursor]
    end

    # Gets the next UTF-8 encoded character
    # without incrementing the cursor.
    sig { returns(String) }
    def peek_char
      return '' unless more_tokens?

      char, = next_char
      char
    end

    # Advance the next `n` characters
    sig { params(n: Integer).returns(T::Boolean) }
    def advance_chars(n)
      n.times do
        _, ok = advance_char
        return false unless ok
      end

      true
    end

    # Checks if the given character matches
    # the next UTF-8 encoded character in source code.
    # If they match, the cursor gets incremented.
    sig { params(char: String).returns(T::Boolean) }
    def match_char(char)
      return false unless more_tokens?

      if peek_char == char
        advance_char
        return true
      end

      false
    end

    # Consumes the next character if it's from the valid set.
    sig { params(valid_chars: String).returns(T::Boolean) }
    def match_chars(valid_chars)
      return false unless more_tokens?

      p = peek_char
      if p != '' && valid_chars.include?(p)
        advance_char
        return true
      end

      false
    end

    # Rewinds the cursor back n chars.
    sig { params(n: Integer).void }
    def backup_chars(n)
      @cursor -= n
    end

    # Skips the current accumulated token.
    sig { void }
    def skip_token
      @start_cursor = @cursor
    end

    sig { returns(Token) }
    def scan_token
      loop do
        char, ok = advance_char
        return token(Token::END_OF_FILE) unless ok

        case char
        when ','
          return token(Token::COMMA)
        when ';'
          return token(Token::SEMICOLON)
        when '('
          return token(Token::LPAREN)
        when ')'
          return token(Token::RPAREN)
        when '!'
          return token(Token::NOT_EQUAL) if match_char('=')

          return token(Token::BANG)
        when '='
          return token(Token::EQUAL_EQUAL) if match_char('=')

          return token(Token::EQUAL)
        when '>'
          return token(Token::GREATER_EQUAL) if match_char('=')

          return token(Token::GREATER)
        when '<'
          return token(Token::LESS_EQUAL) if match_char('=')

          return token(Token::LESS)
        when '+'
          return token(Token::PLUS)
        when '-'
          return token(Token::MINUS)
        when '*'
          return token(Token::STAR)
        when '/'
          return token(Token::SLASH)
        when '"'
          return scan_string
        when "\n"
          return token(Token::NEWLINE)
        when ' ', "\r", "\t"
          skip_token
          next
        else
          if char.match?(/[[:alpha:]]/)
            return scan_identifier
          elsif char.match?(/\d/)
            return scan_number(char)
          end

          return token(Token::ERROR, "unexpected char `#{char}`")
        end
      end
    end

    sig { params(char: String).returns(T::Boolean) }
    def identifier_char?(char)
      char.match?(/[[:alpha:][:digit:]_]/)
    end

    sig { returns(Token) }
    def scan_identifier
      advance_char while identifier_char?(peek_char)

      value = token_value
      return token(value.to_sym) if Token::KEYWORDS.include?(value)

      token(Token::IDENTIFIER, value)
    end

    sig { void }
    def consume_digits
      loop do
        p = peek_char
        break if p == '' || !Token::DIGITS.include?(peek_char)

        _, ok = advance_char
        break unless ok
      end
    end

    # Checks if the next `n` characters are from the valid set.
    sig { params(valid_chars: String, n: Integer).returns(T::Boolean) }
    def accept_chars(valid_chars, n)
      result = T.let(true, T::Boolean)
      n.times do
        unless match_chars(valid_chars)
          result = false
          break
        end
      end

      backup_chars(n)

      result
    end

    sig { params(init_char: String).returns(Token) }
    def scan_number(init_char)
      if init_char == '0'
        p = peek_char
        if accept_chars(Token::DIGITS, 1)
          consume_digits
          return token(
            Token::ERROR,
            'illegal trailing zero in number literal',
          )
        end
      end

      consume_digits

      is_float = false

      if match_char('.')
        is_float = true
        p = peek_char
        if p == ''
          return token(
            Token::ERROR,
            'unexpected EOF',
          )
        end

        unless Token::DIGITS.include?(p)
          return token(
            Token::ERROR,
            "unexpected char in number literal: `#{p}`",
          )
        end

        consume_digits
      end

      if match_char('e') || match_char('E')
        is_float = true
        match_char('+') || match_char('-')
        p = peek_char
        if p == ''
          return token(
            Token::ERROR,
            'unexpected EOF',
          )
        end
        unless Token::DIGITS.include?(p)
          return token(
            Token::ERROR,
            "unexpected char in number literal: `#{p}`",
          )
        end
        consume_digits
      end

      if is_float
        return token_with_consumed_value(Token::FLOAT)
      end

      token_with_consumed_value(Token::INTEGER)
    end

    sig { void }
    def swallow_rest_of_the_string
      loop do
        # swallow the rest of the string
        ch, more_tokens = advance_char
        break if !more_tokens || ch == '"'
      end
    end

    sig { returns(Token) }
    def scan_string
      value_buffer = String.new
      loop do
        char, ok = advance_char
        return token(Token::ERROR, 'unterminated string literal') unless ok
        return token(Token::STRING, value_buffer) if char == '"'

        if char != '\\'
          value_buffer << char
          next
        end

        char, ok = advance_char
        return token(Token::ERROR, 'unterminated string literal') unless ok

        case char
        when '"'
          value_buffer << '"'
        when '\\'
          value_buffer << '\\'
        when '/'
          value_buffer << '/'
        when 'b'
          value_buffer << "\b"
        when 'f'
          value_buffer << "\f"
        when 'n'
          value_buffer << "\n"
        when 'r'
          value_buffer << "\r"
        when 't'
          value_buffer << "\t"
        when 'u'
          unless accept_chars(Token::HEX_DIGITS, 4)
            swallow_rest_of_the_string
            return token(Token::ERROR, 'invalid unicode escape')
          end

          advance_chars(4)
          last4 = T.must @source[@cursor - 4...@cursor]
          value_buffer << [last4.hex].pack('U')
        else
          swallow_rest_of_the_string
          return token(Token::ERROR, "invalid escape `\\#{char}`")
        end
      end
    end
  end
end
