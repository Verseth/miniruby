# typed: strict
# frozen_string_literal: true

module MiniRuby
  # MiniRuby parser
  class Parser
    extend T::Sig

    require_relative 'parser/result'

    class << self
      extend T::Sig

      #: (String source) -> Result
      def parse(source)
        new(source).parse
      end

      private :new
    end

    #: (String source) -> void
    def initialize(source)
      # Lexer/Tokenizer that produces tokens
      @lexer = Lexer.new(source) #: Lexer
      # Next token used for predicting productions
      @lookahead = Token.new(Token::NONE, Span::ZERO) #: Token
      @errors = [] #: Array[String]
    end

    #: -> Result
    def parse
      advance # populate @lookahead
      ast = parse_program
      Result.new(ast, @errors)
    end

    private

    # program = statements
    #: -> AST::ProgramNode
    def parse_program
      statements = parse_statements

      span = Span::ZERO
      if statements.length > 0
        span = statements.fetch(0).span.join(statements.fetch(-1).span)
      end

      AST::ProgramNode.new(statements:, span:)
    end

    # statements = statement*
    #: (*Symbol stop_tokens) -> Array[AST::StatementNode]
    def parse_statements(*stop_tokens)
      statements = [] #: Array[AST::StatementNode]
      swallow_statement_separators

      while true
        return statements if accept!([Token::END_OF_FILE, *stop_tokens])

        statements << parse_statement
      end
    end

    # statement = expression_statement
    #: -> AST::StatementNode
    def parse_statement
      parse_expression_statement
    end

    # expression_statement = expression ("\n" | ";")
    #: -> AST::StatementNode
    def parse_expression_statement
      expression = parse_modifier_expression
      span = expression.span
      if (separator = match(Token::NEWLINE, Token::SEMICOLON, Token::END_OF_FILE))
        span = span.join(separator.span)
      else
        error_expected('a statement separator')
      end

      swallow_statement_separators
      AST::ExpressionStatementNode.new(expression:, span:)
    end

    # modifier_expression = expression | expression ("if" | "unless") expression
    #: -> AST::ExpressionNode
    def parse_modifier_expression
      left = parse_expression

      case @lookahead.type
      when Token::IF, Token::UNLESS
        operator = advance
        swallow_newlines

        right = parse_expression
        span = left.span.join(right.span)
        left = AST::ModifierExpressionNode.new(
          span:,
          operator:,
          left:,
          right:,
        )
      else
        left
      end
    end

    # expression = assignment_expression
    #: -> AST::ExpressionNode
    def parse_expression
      parse_assignment_expression
    end

    # assignment_expression = expression "=" assignment_expression | logical_or_expression
    #: -> AST::ExpressionNode
    def parse_assignment_expression
      target = parse_logical_or_expression
      return target unless match(Token::EQUAL)

      case target
      when AST::IdentifierNode, AST::AttributeAccessExpressionNode
      else
        add_error("unexpected `#{target.class}`, expected an identifier")
      end
      swallow_newlines
      value = parse_assignment_expression
      span = target.span.join(value.span)

      AST::AssignmentExpressionNode.new(span:, target:, value:)
    end

    # logical_or_expression = logical_and_expression | logical_or_expression ("||" | "??") logical_and_expression
    #: -> AST::ExpressionNode
    def parse_logical_or_expression
      left = parse_logical_and_expression

      while @lookahead.logical_orlike_operator?
        operator = advance
        swallow_newlines

        right = parse_logical_and_expression
        span = left.span.join(right.span)
        left = AST::BinaryExpressionNode.new(
          span:,
          operator:,
          left:,
          right:,
        )
      end

      left
    end

    # logical_and_expression = equality_expression | logical_and_expression "&&" equality_expression
    #: -> AST::ExpressionNode
    def parse_logical_and_expression
      left = parse_equality_expression

      while @lookahead.logical_and_operator?
        operator = advance
        swallow_newlines

        right = parse_equality_expression
        span = left.span.join(right.span)
        left = AST::BinaryExpressionNode.new(
          span:,
          operator:,
          left:,
          right:,
        )
      end

      left
    end

    # equality_expression = equality_expression ("==" | "!=") comparison_expression | comparison_expression
    #: -> AST::ExpressionNode
    def parse_equality_expression
      left = parse_comparison_expression

      while @lookahead.equality_operator?
        operator = advance
        swallow_newlines

        right = parse_comparison_expression
        span = left.span.join(right.span)
        left = AST::BinaryExpressionNode.new(
          span:,
          operator:,
          left:,
          right:,
        )
      end

      left
    end

    # comparison_expression = comparison_expression (">" | ">=" | "<" | "<=") additive_expression | additive_expression
    #: -> AST::ExpressionNode
    def parse_comparison_expression
      left = parse_additive_expression

      while @lookahead.comparison_operator?
        operator = advance
        swallow_newlines

        right = parse_additive_expression
        span = left.span.join(right.span)
        left = AST::BinaryExpressionNode.new(
          span:,
          operator:,
          left:,
          right:,
        )
      end

      left
    end

    # additive_expression = additive_expression ("+" | "-") multiplicative_expression | multiplicative_expression
    #: -> AST::ExpressionNode
    def parse_additive_expression
      left = parse_multiplicative_expression

      while @lookahead.additive_operator?
        operator = advance
        swallow_newlines

        right = parse_multiplicative_expression
        span = left.span.join(right.span)
        left = AST::BinaryExpressionNode.new(
          span:,
          operator:,
          left:,
          right:,
        )
      end

      left
    end

    # multiplicative_expression = multiplicative_expression ("*" | "/") unary_expression | unary_expression
    #: -> AST::ExpressionNode
    def parse_multiplicative_expression
      left = parse_unary_expression

      while @lookahead.multiplicative_operator?
        operator = advance
        swallow_newlines

        right = parse_unary_expression
        span = left.span.join(right.span)
        left = AST::BinaryExpressionNode.new(
          span:,
          operator:,
          left:,
          right:,
        )
      end

      left
    end

    # unary_expression = function_call | ("!" | "-" | "+") unary_expression
    #: -> AST::ExpressionNode
    def parse_unary_expression
      if (operator = match(Token::BANG, Token::MINUS, Token::PLUS))
        swallow_newlines
        value = parse_unary_expression
        span = operator.span.join(value.span)

        return AST::UnaryExpressionNode.new(
          span:,
          operator:,
          value:,
        )
      end

      parse_function_call
    end

    # function_call = IDENTIFIER "(" argument_list ")" | attribute
    #: -> AST::ExpressionNode
    def parse_function_call
      ident = parse_attribute
      return ident unless ident.is_a?(AST::IdentifierNode) && match(Token::LPAREN)

      swallow_newlines
      arg_list = parse_argument_list
      swallow_newlines

      rparen, ok = consume(Token::RPAREN)
      return AST::InvalidNode.new(span: rparen.span, token: rparen) unless ok

      span = ident.span.join(rparen.span)
      AST::FunctionCallNode.new(
        span:,
        name:      ident.value,
        arguments: arg_list,
      )
    end

    #: -> Array[AST::ExpressionNode]
    def parse_argument_list
      return [] if accept(Token::RPAREN)

      args = [parse_expression]
      while true
        break if accept(Token::END_OF_FILE, Token::RPAREN)
        break unless match(Token::COMMA)

        swallow_newlines
        break if accept(Token::END_OF_FILE, Token::RPAREN)

        args << parse_expression
      end

      args
    end

    #: -> AST::ExpressionNode
    def parse_attribute
      l = left = parse_primary_expression
      return l unless l.is_a?(AST::IdentifierNode)

      while true
        return left unless match(Token::DOT)

        name, ok = consume(Token::IDENTIFIER)
        return AST::InvalidNode.new(span: name.span, token: name) unless ok

        ident = AST::IdentifierNode.new(span: name.span, value: T.must(name.value))

        left = AST::AttributeAccessExpressionNode.new(
          span:     left.span.join(ident.span),
          receiver: left,
          field:    ident,
        )
      end
    end

    #: -> AST::ExpressionNode
    def parse_primary_expression
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
      when Token::SELF
        tok = advance
        AST::SelfLiteralNode.new(span: tok.span)
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
        parse_identifier
      when Token::RETURN
        parse_return_expression
      when Token::BREAK
        parse_break_expression
      when Token::NEXT
        parse_next_expression
      when Token::IF
        parse_if_expression
      when Token::UNLESS
        parse_unless_expression
      when Token::WHILE
        parse_while_expression
      when Token::LPAREN
        parse_parenthesized_expression
      else
        token = advance
        add_error("unexpected token `#{tok}`") if token.type != Token::ERROR
        AST::InvalidNode.new(span: token.span, token:)
      end
    end

    #: -> AST::IdentifierNode
    def parse_identifier
      tok = advance
      AST::IdentifierNode.new(span: tok.span, value: T.must(tok.value))
    end

    # parenthesized_expression = "(" expression ")"
    #: -> AST::ExpressionNode
    def parse_parenthesized_expression
      lparen = advance
      expr = parse_modifier_expression
      rparen, = consume(Token::RPAREN)
      expr.span = lparen.span.join(rparen.span)

      expr
    end

    # return_expression = "return" [expression]
    #: -> AST::ReturnExpressionNode
    def parse_return_expression
      return_token = advance
      if accept(Token::END_OF_FILE, Token::NEWLINE, Token::SEMICOLON, Token::IF, Token::UNLESS)
        return AST::ReturnExpressionNode.new(span: return_token.span)
      end

      value = parse_expression
      span = return_token.span.join(value.span)

      AST::ReturnExpressionNode.new(span:, value:)
    end

    # break_expression = "break" [expression]
    #: -> AST::BreakExpressionNode
    def parse_break_expression
      break_token = advance
      if accept(Token::END_OF_FILE, Token::NEWLINE, Token::SEMICOLON, Token::IF, Token::UNLESS)
        return AST::BreakExpressionNode.new(span: break_token.span)
      end

      value = parse_expression
      span = break_token.span.join(value.span)

      AST::BreakExpressionNode.new(span:, value:)
    end

    # next_expression = "next" [expression]
    #: -> AST::NextExpressionNode
    def parse_next_expression
      next_token = advance
      if accept(Token::END_OF_FILE, Token::NEWLINE, Token::SEMICOLON, Token::IF, Token::UNLESS)
        return AST::NextExpressionNode.new(span: next_token.span)
      end

      value = parse_expression
      span = next_token.span.join(value.span)

      AST::NextExpressionNode.new(span:, value:)
    end

    # if_expression = "if" expression SEPARATOR statements ["else" (expression | SEPARATOR statements)] "end"
    #: -> AST::ExpressionNode
    def parse_if_expression
      if_token = advance
      condition = parse_expression

      separator, ok = consume(Token::SEMICOLON, Token::NEWLINE)
      return AST::InvalidNode.new(span: separator.span, token: separator) unless ok

      then_body = parse_statements(Token::END_K, Token::ELSE)
      else_body = nil #: Array[MiniRuby::AST::StatementNode]?
      span = if_token.span

      if match(Token::ELSE)
        if match(Token::NEWLINE, Token::SEMICOLON)
          # else; a + 5; end
          else_body = parse_statements(Token::END_K)
          end_tok, ok = consume(Token::END_K)
          return AST::InvalidNode.new(span: end_tok.span, token: end_tok) unless ok

          span = span.join(end_tok.span)
        else
          # else a + 5
          expression = parse_expression
          else_body = [AST::ExpressionStatementNode.new(span: expression.span, expression:)]
          span = span.join(expression.span)
        end
      else
        end_tok, ok = consume(Token::END_K)
        return AST::InvalidNode.new(span: end_tok.span, token: end_tok) unless ok

        span = span.join(end_tok.span)
      end

      AST::IfExpressionNode.new(span:, condition:, then_body:, else_body:)
    end

    # unless_expression = "unless" expression SEPARATOR statements "end"
    #: -> AST::ExpressionNode
    def parse_unless_expression
      unless_token = advance
      condition = parse_expression

      separator, ok = consume(Token::SEMICOLON, Token::NEWLINE)
      return AST::InvalidNode.new(span: separator.span, token: separator) unless ok

      then_body = parse_statements(Token::END_K)
      span = unless_token.span

      end_tok, ok = consume(Token::END_K)
      return AST::InvalidNode.new(span: end_tok.span, token: end_tok) unless ok

      span = span.join(end_tok.span)

      AST::UnlessExpressionNode.new(span:, condition:, then_body:)
    end

    # if_expression = "while" expression SEPARATOR statements "end"
    #: -> AST::ExpressionNode
    def parse_while_expression
      while_token = advance
      condition = parse_expression

      separator, ok = consume(Token::SEMICOLON, Token::NEWLINE)
      return AST::InvalidNode.new(span: separator.span, token: separator) unless ok

      then_body = parse_statements(Token::END_K)

      end_tok, ok = consume(Token::END_K)
      return AST::InvalidNode.new(span: end_tok.span, token: end_tok) unless ok

      span = while_token.span.join(end_tok.span)
      AST::WhileExpressionNode.new(span:, condition:, then_body:)
    end

    # Move over to the next token.
    #: -> Token
    def advance
      previous = @lookahead
      @lookahead = @lexer.next
      handle_error_token(@lookahead) if @lookahead.type == Token::ERROR

      previous
    end

    # Add the content of an error token to the syntax error list.
    #: (Token err) -> void
    def handle_error_token(err)
      msg = err.value
      return unless msg

      add_error(msg)
    end

    # Register a syntax error
    #: (String err) -> void
    def add_error(err)
      @errors << err
    end

    # Checks if the next token matches any of the given types,
    # if so it gets consumed.
    #: (*Symbol token_types) -> Token?
    def match(*token_types)
      token_types.each do |type|
        return advance if accept(type)
      end

      nil
    end

    # Checks whether the next token matches any the specified types.
    #: (*Symbol token_types) -> bool
    def accept(*token_types)
      accept!(token_types)
    end

    # Checks whether the next token matches any the specified types.
    #: (Array[Symbol] token_types) -> bool
    def accept!(token_types)
      token_types.each do |type|
        return true if @lookahead.type == type
      end

      false
    end

    #: (*Symbol token_types) -> [Token, bool]
    def consume(*token_types)
      return advance, false if @lookahead.type == Token::ERROR

      if token_types.any? { _1 == @lookahead.type }
        return advance, true
      end

      msg = token_types.map { Token.type_to_string(_1) }
                       .join(' or ')
      error_expected(msg)
      [advance, false]
    end

    # Adds an error which tells the user that another type of token
    # was expected.
    #: (String expected) -> void
    def error_expected(expected)
      return if @lookahead.type == Token::ERROR

      add_error("unexpected #{@lookahead.type_name}, expected #{expected}")
    end

    # Accept and ignore any number of consecutive newline tokens.
    #: -> void
    def swallow_newlines
      break unless match(Token::NEWLINE) while true # rubocop:disable Style/NestedModifier
    end

    # Accept and ignore any number of consecutive newline or semicolon tokens.
    #: -> void
    def swallow_statement_separators
      break unless match(Token::NEWLINE, Token::SEMICOLON) while true # rubocop:disable Style/NestedModifier
    end

  end
end
