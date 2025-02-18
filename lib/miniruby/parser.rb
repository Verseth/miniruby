# typed: strict
# frozen_string_literal: true

module MiniRuby
  # MiniRuby parser
  class Parser
    extend T::Sig

    require_relative 'parser/result'

    class << self
      extend T::Sig

      sig { params(source: String).returns(Result) }
      def parse(source)
        new(source).parse
      end

      private :new
    end

    sig { params(source: String).void }
    def initialize(source)
      # Lexer/Tokenizer that produces tokens
      @lexer = T.let(Lexer.new(source), Lexer)
      # Next token used for predicting productions
      @lookahead = T.let(Token.new(Token::NONE, Span::ZERO), Token)
      @errors = T.let([], T::Array[String])
    end

    sig { returns(Result) }
    def parse
      advance # populate @lookahead
      ast = parse_program
      Result.new(ast, @errors)
    end

    private

    # program = statements
    sig { returns(AST::ProgramNode) }
    def parse_program
      statements = parse_statements

      span = Span::ZERO
      if statements.length > 0
        span = statements.fetch(0).span.join(statements.fetch(-1).span)
      end

      AST::ProgramNode.new(statements:, span:)
    end

     # statements = statement*
     sig { params(stop_tokens: Symbol).returns(T::Array[AST::StatementNode]) }
     def parse_statements(*stop_tokens)
       statements = T.let([], T::Array[AST::StatementNode])
       swallow_statement_separators

       while true
         return statements if accept!([Token::END_OF_FILE, *stop_tokens])

         statements << parse_statement
       end
     end

    # statement = expression_statement
    sig { returns(AST::StatementNode) }
    def parse_statement
      parse_expression_statement
    end

    # expression_statement = expression ("\n" | ";")
    sig { returns(AST::StatementNode) }
    def parse_expression_statement
      expression = parse_expression
      span = expression.span
      if (separator = match(Token::NEWLINE, Token::SEMICOLON, Token::END_OF_FILE))
        span = span.join(separator.span)
      else
        error_expected('a statement separator')
      end

      swallow_statement_separators
      AST::ExpressionStatementNode.new(expression:, span:)
    end

    sig { returns(AST::ExpressionNode) }
    def parse_expression
      case @lookahead.type
      when Token::FALSE
        tok = advance
        AST::FalseLiteralNode.new(span: tok.span)
      when Token::TRUE
        tok = advance
        AST::TrueLiteralNode.new(span: tok.span)
      when Token::NIL
        tok = advance
        AST::NilLiteralNode.new(span: tok.span)
      when Token::INTEGER
        tok = advance
        AST::IntegerLiteralNode.new(span: tok.span, value: T.must(tok.value))
      when Token::FLOAT
        tok = advance
        AST::FloatLiteralNode.new(span: tok.span, value: T.must(tok.value))
      when Token::STRING
        tok = advance
        AST::StringLiteralNode.new(span: tok.span, value: T.must(tok.value))
      when Token::IDENTIFIER
        tok = advance
        AST::IdentifierNode.new(span: tok.span, value: T.must(tok.value))
      else
        token = advance
        add_error("unexpected token `#{tok}`") if token.type != Token::ERROR
        AST::InvalidNode.new(span: token.span, token:)
      end
    end

    # Move over to the next token.
    sig { returns(Token) }
    def advance
      previous = @lookahead
      @lookahead = @lexer.next
      handle_error_token(@lookahead) if @lookahead.type == Token::ERROR

      previous
    end

    # Add the content of an error token to the syntax error list.
    sig { params(err: Token).void }
    def handle_error_token(err)
      msg = err.value
      return unless msg

      add_error(msg)
    end

    # Register a syntax error
    sig { params(err: String).void }
    def add_error(err)
      @errors << err
    end

    # Checks whether the next token matches any the specified types.
    sig { params(token_types: Symbol).returns(T::Boolean) }
    def accept(*token_types)
      accept!(token_types)
    end

    # Checks whether the next token matches any the specified types.
    sig { params(token_types: T::Array[Symbol]).returns(T::Boolean) }
    def accept!(token_types)
      token_types.each do |type|
        return true if @lookahead.type == type
      end

      false
    end

    # Checks if the next token matches any of the given types,
    # if so it gets consumed.
    sig { params(token_types: Symbol).returns(T.nilable(Token)) }
    def match(*token_types)
      token_types.each do |type|
        return advance if accept(type)
      end

      nil
    end

    # Accept and ignore any number of consecutive newline tokens.
    sig { void }
    def swallow_newlines
      while true
        break unless match(Token::NEWLINE)
      end
    end

    # Accept and ignore any number of consecutive newline or semicolon tokens.
    sig { void }
    def swallow_statement_separators
      while true
        break unless match(Token::NEWLINE, Token::SEMICOLON)
      end
    end

    # Adds an error which tells the user that another type of token
    # was expected.
    sig { params(expected: String).void }
    def error_expected(expected)
      return if @lookahead.type == Token::ERROR

      add_error("unexpected #{@lookahead.type_name}, expected #{expected}")
    end


  end

end