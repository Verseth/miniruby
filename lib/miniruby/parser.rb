# typed: strict
# frozen_string_literal: true

require_relative 'parser/result'

module MiniRuby
  # JSON parser
  class Parser
    extend T::Sig

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
    sig { returns(AST::Node) }
    def parse_program
      stmts = parse_statements

      span = Span::ZERO
      if stmts.length > 0
        span = stmts.fetch(0).span.join(stmts.fetch(-1).span)
      end

      AST::ProgramNode.new(span, stmts)
    end

    # statements = statement*
    sig { returns(T::Array[AST::StatementNode])}
    def parse_statements
      statements = T.let([], T::Array[AST::StatementNode])
      swallow_statement_separators

      while true
        return statements if accept(Token::END_OF_FILE)

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
      expr = parse_expression
      span = expr.span
      if (separator = match(Token::NEWLINE, Token::SEMICOLON, Token::END_OF_FILE))
        span = span.join(separator.span)
      else
        error_expected("a statement separator")
      end

      AST::ExpressionStatementNode.new(span, expr)
    end

    # expression = assignment_expression
    sig { returns(AST::ExpressionNode) }
    def parse_expression
      parse_assignment_expression
    end

    # assignment_expression = IDENTIFIER "=" assignment_expression | equality_expression
    sig { returns(AST::ExpressionNode) }
    def parse_assignment_expression
      target = parse_expression
      return target unless match(Token::EQUAL)

      unless target.is_a?(AST::IdentifierNode)
        add_error("unexpected `#{target.class}`, expected an identifier")
      end
      swallow_newlines
      value = parse_assignment_expression
      span = target.span.join(value.span)

      AST::AssignmentExpressionNode.new(span, target, value)
    end

    # equality_expression = equality_expression ("==" | "!=") comparison_expression | comparison_expression
    sig { returns(AST::ExpressionNode) }
    def parse_equality_expression
      left = parse_comparison_expression()

      while @lookahead.equality_operator?
        operator = advance()
        swallow_newlines()

        right = parse_comparison_expression()
        span = left.span.join(right.span)
        left = AST::BinaryExpressionNode.new(
          span,
          operator,
          left,
          right,
        )
      end

      return left
    end

    # comparison_expression = comparison_expression (">" | ">=" | "<" | "<=") additive_expression | additive_expression
    sig { returns(AST::ExpressionNode) }
    def parse_comparison_expression
      left = parse_additive_expression()

      while @lookahead.comparison_operator?
        operator = advance()
        swallow_newlines()

        right = parse_additive_expression()
        span = left.span.join(right.span)
        left = AST::BinaryExpressionNode.new(
          span,
          operator,
          left,
          right,
        )
      end

      return left
    end

    # additive_expression = additive_expression ("+" | "-") multiplicative_expression | multiplicative_expression
    sig { returns(AST::ExpressionNode) }
    def parse_additive_expression
      left = parse_multiplicative_expression()

      while @lookahead.additive_operator?
        operator = advance()
        swallow_newlines()

        right = parse_multiplicative_expression()
        span = left.span.join(right.span)
        left = AST::BinaryExpressionNode.new(
          span,
          operator,
          left,
          right,
        )
      end

      return left
    end

    # multiplicative_expression = multiplicative_expression ("*" | "/") unary_expression | unary_expression
    sig { returns(AST::ExpressionNode) }
    def parse_multiplicative_expression
      left = parse_unary_expression()

      while @lookahead.multiplicative_operator?
        operator = advance()
        swallow_newlines()

        right = parse_unary_expression()
        span = left.span.join(right.span)
        left = AST::BinaryExpressionNode.new(
          span,
          operator,
          left,
          right,
        )
      end

      return left
    end

    # unary_expression = primary_expression | ("!" | "-" | "+") unaryExpression
    sig { returns(AST::ExpressionNode) }
    def parse_unary_expression
      if (operator = match(Token::BANG, Token::MINUS, Token::PLUS))
        swallow_newlines
        value = parse_unary_expression
        span = operator.span.join(value.span)

        return AST::UnaryExpressionNode.new(
          span,
          operator,
          value,
        )
      end

      parse_primary_expression
    end

    sig { returns(AST::ExpressionNode) }
    def parse_primary_expression
      case @lookahead.type
      when Token::FALSE
        tok = advance
        AST::FalseLiteralNode.new(tok.span)
      when Token::TRUE
        tok = advance
        AST::TrueLiteralNode.new(tok.span)
      when Token::NIL
        tok = advance
        AST::NilLiteralNode.new(tok.span)
      when Token::INTEGER
        tok = advance
        AST::IntegerLiteralNode.new(tok.span, T.must(tok.value))
      when Token::FLOAT
        tok = advance
        AST::FloatLiteralNode.new(tok.span, T.must(tok.value))
      when Token::STRING
        tok = advance
        AST::StringLiteralNode.new(tok.span, T.must(tok.value))
      when Token::RETURN
        parse_return_expression
      else
        tok = advance
        add_error("unexpected token `#{tok}`") if tok.type != Token::ERROR
        AST::InvalidNode.new(tok.span, tok)
      end
    end

    # return_expression = "return" expression
    sig { returns(AST::ExpressionNode) }
    def parse_return_expression
      return_token = advance
      val = parse_expression
      span = return_token.span.join(val.span)

      AST::ReturnExpressionNode.new(span, val)
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

    # Checks if the next token matches any of the given types,
    # if so it gets consumed.
    sig { params(token_types: Symbol).returns(T.nilable(Token)) }
    def match(*token_types)
      token_types.each do |type|
        return advance if accept(type)
      end

      nil
    end

    # Checks whether the next token matches any the specified types.
    sig { params(token_types: Symbol).returns(T::Boolean) }
    def accept(*token_types)
      token_types.each do |type|
        return true if @lookahead.type == type
      end

      false
    end

    sig { params(token_type: Symbol).returns([Token, T::Boolean]) }
    def consume(token_type)
      return advance, false if @lookahead.type == Token::ERROR

      if @lookahead.type != token_type
        error_expected(Token.type_to_string(token_type))
        return advance, false
      end

      [advance, true]
    end

    # Adds an error which tells the user that another type of token
    # was expected.
    sig { params(expected: String).void }
    def error_expected(expected)
      add_error("unexpected `#{@lookahead}`, expected `#{expected}`")
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

  end
end
