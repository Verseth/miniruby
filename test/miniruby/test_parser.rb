# typed: true
# frozen_string_literal: true

require 'test_helper'

module MiniRuby
  class TestParser < TestCase
    def test_integer
      result = parse('124')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::IntegerLiteralNode.new(value: '124'),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('0124')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::InvalidNode.new(
              token: Token.new(Token::ERROR, S(P(0), P(3)), 'illegal trailing zero in number literal'),
            ),
          ),
        ],
      )
      assert_equal true, result.err?
      assert_equal ['illegal trailing zero in number literal'], result.errors
      assert_equal expected, result.ast
    end

    def test_string
      result = parse('"foo"')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::StringLiteralNode.new(value: 'foo'),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('"bar\n\t"')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::StringLiteralNode.new(value: "bar\n\t"),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('"foo')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::InvalidNode.new(
              token: Token.new(Token::ERROR, S(P(0), P(3)), 'unterminated string literal'),
            ),
          ),
        ],
      )
      assert_equal true, result.err?
      assert_equal ['unterminated string literal'], result.errors
      assert_equal expected, result.ast

      result = parse('"f\oo"')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::InvalidNode.new(
              token: Token.new(Token::ERROR, S(P(0), P(3)), 'invalid escape `\\o`'),
            ),
          ),
        ],
      )
      assert_equal true, result.err?
      assert_equal ['invalid escape `\\o`'], result.errors
      assert_equal expected, result.ast
    end

    def test_float
      result = parse('12.4')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::FloatLiteralNode.new(value: '12.4'),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('12e4')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::FloatLiteralNode.new(value: '12e4'),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('12.4.5')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::FloatLiteralNode.new(value: '12.4'),
          ),
          AST::ExpressionStatementNode.new(
            expression: AST::InvalidNode.new(token: Token.new(Token::ERROR, S(P(4), P(4)), 'unexpected char `.`')),
          ),
          AST::ExpressionStatementNode.new(
            expression: AST::IntegerLiteralNode.new(value: '5'),
          ),
        ],
      )
      assert_equal true, result.err?
      assert_equal ['unexpected char `.`', 'unexpected INTEGER, expected a statement separator'], result.errors
      assert_equal expected, result.ast
    end

    def test_simple_literal
      result = parse('false')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::FalseLiteralNode.new,
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('true')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::TrueLiteralNode.new,
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('nil')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::NilLiteralNode.new,
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('self')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::SelfLiteralNode.new,
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast
    end

    def test_identifier
      result = parse('foo')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::IdentifierNode.new(value: 'foo'),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('foo_bar')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::IdentifierNode.new(value: 'foo_bar'),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('foo-bar')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::BinaryExpressionNode.new(
              operator: Token.new(Token::MINUS, S(P(3), P(3))),
              left:     AST::IdentifierNode.new(value: 'foo'),
              right:    AST::IdentifierNode.new(value: 'bar'),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('FooBar')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::IdentifierNode.new(value: 'FooBar'),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast
    end

    def test_return
      result = parse('return')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::ReturnExpressionNode.new,
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('return foo + 2')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::ReturnExpressionNode.new(
              value: AST::BinaryExpressionNode.new(
                operator: Token.new(Token::PLUS, S(P(11), P(11))),
                left:     AST::IdentifierNode.new(value: 'foo'),
                right:    AST::IntegerLiteralNode.new(value: '2'),
              ),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('a = return 5')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::AssignmentExpressionNode.new(
              target: AST::IdentifierNode.new(value: 'a'),
              value:  AST::ReturnExpressionNode.new(
                value: AST::IntegerLiteralNode.new(value: '5'),
              ),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast
    end

    def test_while
      result = parse(<<~RUBY)
        while a != 5
          a = a + 2
          !a
        end
      RUBY
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::WhileExpressionNode.new(
              condition: AST::BinaryExpressionNode.new(
                operator: Token.new(Token::NOT_EQUAL, S(P(8), P(9))),
                left:     AST::IdentifierNode.new(value: 'a'),
                right:    AST::IntegerLiteralNode.new(value: '5'),
              ),
              then_body: [
                AST::ExpressionStatementNode.new(
                  expression: AST::AssignmentExpressionNode.new(
                    target: AST::IdentifierNode.new(value: 'a'),
                    value:  AST::BinaryExpressionNode.new(
                      operator: Token.new(Token::PLUS, S(P(15), P(15))),
                      left:     AST::IdentifierNode.new(value: 'a'),
                      right:    AST::IntegerLiteralNode.new(value: '2'),
                    ),
                  ),
                ),
                AST::ExpressionStatementNode.new(
                  expression: AST::UnaryExpressionNode.new(
                    operator: Token.new(Token::BANG, S(P(22), P(22))),
                    value:    AST::IdentifierNode.new(value: 'a'),
                  ),
                ),
              ],
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast
    end

    def test_if
      result = parse(<<~RUBY)
        if a != 5
          a = a + 2
          !a
        end
      RUBY
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::IfExpressionNode.new(
              condition: AST::BinaryExpressionNode.new(
                operator: Token.new(Token::NOT_EQUAL, S(P(8), P(9))),
                left:     AST::IdentifierNode.new(value: 'a'),
                right:    AST::IntegerLiteralNode.new(value: '5'),
              ),
              then_body: [
                AST::ExpressionStatementNode.new(
                  expression: AST::AssignmentExpressionNode.new(
                    target: AST::IdentifierNode.new(value: 'a'),
                    value:  AST::BinaryExpressionNode.new(
                      operator: Token.new(Token::PLUS, S(P(15), P(15))),
                      left:     AST::IdentifierNode.new(value: 'a'),
                      right:    AST::IntegerLiteralNode.new(value: '2'),
                    ),
                  ),
                ),
                AST::ExpressionStatementNode.new(
                  expression: AST::UnaryExpressionNode.new(
                    operator: Token.new(Token::BANG, S(P(22), P(22))),
                    value:    AST::IdentifierNode.new(value: 'a'),
                  ),
                ),
              ],
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse(<<~RUBY)
        if a != 5
          a = a + 2
          !a
        else nil
      RUBY
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::IfExpressionNode.new(
              condition: AST::BinaryExpressionNode.new(
                operator: Token.new(Token::NOT_EQUAL, S(P(8), P(9))),
                left:     AST::IdentifierNode.new(value: 'a'),
                right:    AST::IntegerLiteralNode.new(value: '5'),
              ),
              then_body: [
                AST::ExpressionStatementNode.new(
                  expression: AST::AssignmentExpressionNode.new(
                    target: AST::IdentifierNode.new(value: 'a'),
                    value:  AST::BinaryExpressionNode.new(
                      operator: Token.new(Token::PLUS, S(P(15), P(15))),
                      left:     AST::IdentifierNode.new(value: 'a'),
                      right:    AST::IntegerLiteralNode.new(value: '2'),
                    ),
                  ),
                ),
                AST::ExpressionStatementNode.new(
                  expression: AST::UnaryExpressionNode.new(
                    operator: Token.new(Token::BANG, S(P(22), P(22))),
                    value:    AST::IdentifierNode.new(value: 'a'),
                  ),
                ),
              ],
              else_body: [
                AST::ExpressionStatementNode.new(
                  expression: AST::NilLiteralNode.new,
                ),
              ],
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse(<<~RUBY)
        if a != 5
          a = a + 2
          !a
        else
          b = 2
          a = b
        end
      RUBY
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::IfExpressionNode.new(
              condition: AST::BinaryExpressionNode.new(
                operator: Token.new(Token::NOT_EQUAL, S(P(8), P(9))),
                left:     AST::IdentifierNode.new(value: 'a'),
                right:    AST::IntegerLiteralNode.new(value: '5'),
              ),
              then_body: [
                AST::ExpressionStatementNode.new(
                  expression: AST::AssignmentExpressionNode.new(
                    target: AST::IdentifierNode.new(value: 'a'),
                    value:  AST::BinaryExpressionNode.new(
                      operator: Token.new(Token::PLUS, S(P(15), P(15))),
                      left:     AST::IdentifierNode.new(value: 'a'),
                      right:    AST::IntegerLiteralNode.new(value: '2'),
                    ),
                  ),
                ),
                AST::ExpressionStatementNode.new(
                  expression: AST::UnaryExpressionNode.new(
                    operator: Token.new(Token::BANG, S(P(22), P(22))),
                    value:    AST::IdentifierNode.new(value: 'a'),
                  ),
                ),
              ],
              else_body: [
                AST::ExpressionStatementNode.new(
                  expression: AST::AssignmentExpressionNode.new(
                    target: AST::IdentifierNode.new(value: 'b'),
                    value:  AST::IntegerLiteralNode.new(value: '2'),
                  ),
                ),
                AST::ExpressionStatementNode.new(
                  expression: AST::AssignmentExpressionNode.new(
                    target: AST::IdentifierNode.new(value: 'a'),
                    value:  AST::IdentifierNode.new(value: 'b'),
                  ),
                ),
              ],
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse(<<~RUBY)
        if a != 5
          a = a + 2
          !a
        else if b
          b = 2
          a = b
        end
      RUBY
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::IfExpressionNode.new(
              condition: AST::BinaryExpressionNode.new(
                operator: Token.new(Token::NOT_EQUAL, S(P(8), P(9))),
                left:     AST::IdentifierNode.new(value: 'a'),
                right:    AST::IntegerLiteralNode.new(value: '5'),
              ),
              then_body: [
                AST::ExpressionStatementNode.new(
                  expression: AST::AssignmentExpressionNode.new(
                    target: AST::IdentifierNode.new(value: 'a'),
                    value:  AST::BinaryExpressionNode.new(
                      operator: Token.new(Token::PLUS, S(P(15), P(15))),
                      left:     AST::IdentifierNode.new(value: 'a'),
                      right:    AST::IntegerLiteralNode.new(value: '2'),
                    ),
                  ),
                ),
                AST::ExpressionStatementNode.new(
                  expression: AST::UnaryExpressionNode.new(
                    operator: Token.new(Token::BANG, S(P(22), P(22))),
                    value:    AST::IdentifierNode.new(value: 'a'),
                  ),
                ),
              ],
              else_body: [
                AST::ExpressionStatementNode.new(
                  expression: AST::IfExpressionNode.new(
                    condition: AST::IdentifierNode.new(value: 'b'),
                    then_body: [
                      AST::ExpressionStatementNode.new(
                        expression: AST::AssignmentExpressionNode.new(
                          target: AST::IdentifierNode.new(value: 'b'),
                          value:  AST::IntegerLiteralNode.new(value: '2'),
                        ),
                      ),
                      AST::ExpressionStatementNode.new(
                        expression: AST::AssignmentExpressionNode.new(
                          target: AST::IdentifierNode.new(value: 'a'),
                          value:  AST::IdentifierNode.new(value: 'b'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast
    end

    def test_unary_operators
      result = parse('!a')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::UnaryExpressionNode.new(
              operator: Token.new(Token::BANG, S(P(0), P(0))),
              value:    AST::IdentifierNode.new(value: 'a'),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('-a')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::UnaryExpressionNode.new(
              operator: Token.new(Token::MINUS, S(P(0), P(0))),
              value:    AST::IdentifierNode.new(value: 'a'),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('+a')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::UnaryExpressionNode.new(
              operator: Token.new(Token::PLUS, S(P(0), P(0))),
              value:    AST::IdentifierNode.new(value: 'a'),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('!!!a')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::UnaryExpressionNode.new(
              operator: Token.new(Token::BANG, S(P(0), P(0))),
              value:    AST::UnaryExpressionNode.new(
                operator: Token.new(Token::BANG, S(P(1), P(1))),
                value:    AST::UnaryExpressionNode.new(
                  operator: Token.new(Token::BANG, S(P(2), P(2))),
                  value:    AST::IdentifierNode.new(value: 'a'),
                ),
              ),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('!(1 + 2)')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::UnaryExpressionNode.new(
              operator: Token.new(Token::BANG, S(P(0), P(0))),
              value:    AST::BinaryExpressionNode.new(
                operator: Token.new(Token::PLUS, S(P(4), P(4))),
                left:     AST::IntegerLiteralNode.new(value: '1'),
                right:    AST::IntegerLiteralNode.new(value: '2'),
              ),
            ),
          ),
        ],
      )
      assert_equal false, result.err?, result.errors
      assert_equal expected, result.ast
    end

    def test_multiplicative_operators
      result = parse('a * b / c')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::BinaryExpressionNode.new(
              operator: Token.new(Token::SLASH, S(P(6), P(6))),
              left:     AST::BinaryExpressionNode.new(
                operator: Token.new(Token::STAR, S(P(2), P(2))),
                left:     AST::IdentifierNode.new(value: 'a'),
                right:    AST::IdentifierNode.new(value: 'b'),
              ),
              right:    AST::IdentifierNode.new(value: 'c'),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse("a *\nb /\nc")
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::BinaryExpressionNode.new(
              operator: Token.new(Token::SLASH, S(P(6), P(6))),
              left:     AST::BinaryExpressionNode.new(
                operator: Token.new(Token::STAR, S(P(2), P(2))),
                left:     AST::IdentifierNode.new(value: 'a'),
                right:    AST::IdentifierNode.new(value: 'b'),
              ),
              right:    AST::IdentifierNode.new(value: 'c'),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('a + b * c')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::BinaryExpressionNode.new(
              operator: Token.new(Token::PLUS, S(P(2), P(2))),
              left:     AST::IdentifierNode.new(value: 'a'),
              right:    AST::BinaryExpressionNode.new(
                operator: Token.new(Token::STAR, S(P(6), P(6))),
                left:     AST::IdentifierNode.new(value: 'b'),
                right:    AST::IdentifierNode.new(value: 'c'),
              ),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast
    end

    def test_additive_operators
      result = parse('a + b - c')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::BinaryExpressionNode.new(
              operator: Token.new(Token::MINUS, S(P(6), P(6))),
              left:     AST::BinaryExpressionNode.new(
                operator: Token.new(Token::PLUS, S(P(2), P(2))),
                left:     AST::IdentifierNode.new(value: 'a'),
                right:    AST::IdentifierNode.new(value: 'b'),
              ),
              right:    AST::IdentifierNode.new(value: 'c'),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('a + (b - c)')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::BinaryExpressionNode.new(
              operator: Token.new(Token::PLUS, S(P(2), P(2))),
              left:     AST::IdentifierNode.new(value: 'a'),
              right:    AST::BinaryExpressionNode.new(
                operator: Token.new(Token::MINUS, S(P(7), P(7))),
                left:     AST::IdentifierNode.new(value: 'b'),
                right:    AST::IdentifierNode.new(value: 'c'),
              ),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse("a +\nb -\nc")
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::BinaryExpressionNode.new(
              operator: Token.new(Token::MINUS, S(P(6), P(6))),
              left:     AST::BinaryExpressionNode.new(
                operator: Token.new(Token::PLUS, S(P(2), P(2))),
                left:     AST::IdentifierNode.new(value: 'a'),
                right:    AST::IdentifierNode.new(value: 'b'),
              ),
              right:    AST::IdentifierNode.new(value: 'c'),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast
    end

    def test_comparison_operators
      result = parse('a > b < c')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::BinaryExpressionNode.new(
              operator: Token.new(Token::LESS, S(P(6), P(6))),
              left:     AST::BinaryExpressionNode.new(
                operator: Token.new(Token::GREATER, S(P(2), P(2))),
                left:     AST::IdentifierNode.new(value: 'a'),
                right:    AST::IdentifierNode.new(value: 'b'),
              ),
              right:    AST::IdentifierNode.new(value: 'c'),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse("a >\nb <\nc")
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::BinaryExpressionNode.new(
              operator: Token.new(Token::LESS, S(P(6), P(6))),
              left:     AST::BinaryExpressionNode.new(
                operator: Token.new(Token::GREATER, S(P(2), P(2))),
                left:     AST::IdentifierNode.new(value: 'a'),
                right:    AST::IdentifierNode.new(value: 'b'),
              ),
              right:    AST::IdentifierNode.new(value: 'c'),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('a > b + c')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::BinaryExpressionNode.new(
              operator: Token.new(Token::GREATER, S(P(2), P(2))),
              left:     AST::IdentifierNode.new(value: 'a'),
              right:    AST::BinaryExpressionNode.new(
                operator: Token.new(Token::PLUS, S(P(6), P(6))),
                left:     AST::IdentifierNode.new(value: 'b'),
                right:    AST::IdentifierNode.new(value: 'c'),
              ),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast
    end

    def test_equality_operators
      result = parse('a == b != c')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::BinaryExpressionNode.new(
              operator: Token.new(Token::NOT_EQUAL, S(P(7), P(8))),
              left:     AST::BinaryExpressionNode.new(
                operator: Token.new(Token::EQUAL_EQUAL, S(P(2), P(3))),
                left:     AST::IdentifierNode.new(value: 'a'),
                right:    AST::IdentifierNode.new(value: 'b'),
              ),
              right:    AST::IdentifierNode.new(value: 'c'),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse("a ==\nb !=\nc")
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::BinaryExpressionNode.new(
              operator: Token.new(Token::NOT_EQUAL, S(P(7), P(8))),
              left:     AST::BinaryExpressionNode.new(
                operator: Token.new(Token::EQUAL_EQUAL, S(P(2), P(3))),
                left:     AST::IdentifierNode.new(value: 'a'),
                right:    AST::IdentifierNode.new(value: 'b'),
              ),
              right:    AST::IdentifierNode.new(value: 'c'),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('a == b < c')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::BinaryExpressionNode.new(
              operator: Token.new(Token::EQUAL_EQUAL, S(P(2), P(3))),
              left:     AST::IdentifierNode.new(value: 'a'),
              right:    AST::BinaryExpressionNode.new(
                operator: Token.new(Token::LESS, S(P(7), P(7))),
                left:     AST::IdentifierNode.new(value: 'b'),
                right:    AST::IdentifierNode.new(value: 'c'),
              ),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast
    end

    def test_assignment_operator
      result = parse('a = b = c')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::AssignmentExpressionNode.new(
              target: AST::IdentifierNode.new(value: 'a'),
              value:  AST::AssignmentExpressionNode.new(
                target: AST::IdentifierNode.new(value: 'b'),
                value:  AST::IdentifierNode.new(value: 'c'),
              ),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse("a =\nb =\nc")
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::AssignmentExpressionNode.new(
              target: AST::IdentifierNode.new(value: 'a'),
              value:  AST::AssignmentExpressionNode.new(
                target: AST::IdentifierNode.new(value: 'b'),
                value:  AST::IdentifierNode.new(value: 'c'),
              ),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast

      result = parse('a = b == c')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::AssignmentExpressionNode.new(
              target: AST::IdentifierNode.new(value: 'a'),
              value:  AST::BinaryExpressionNode.new(
                operator: Token.new(Token::EQUAL_EQUAL, S(P(6), P(7))),
                left:     AST::IdentifierNode.new(value: 'b'),
                right:    AST::IdentifierNode.new(value: 'c'),
              ),
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast
    end

    def test_call
      result = parse('foo()')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::FunctionCallNode.new(
              name: 'foo',
            ),
          ),
        ],
      )
      assert_equal false, result.err?, result.errors
      assert_equal expected, result.ast

      result = parse('foo(1)')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::FunctionCallNode.new(
              name:      'foo',
              arguments: [
                AST::IntegerLiteralNode.new(value: '1'),
              ],
            ),
          ),
        ],
      )
      assert_equal false, result.err?, result.errors
      assert_equal expected, result.ast

      result = parse('foo(1,)')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::FunctionCallNode.new(
              name:      'foo',
              arguments: [
                AST::IntegerLiteralNode.new(value: '1'),
              ],
            ),
          ),
        ],
      )
      assert_equal false, result.err?, result.errors
      assert_equal expected, result.ast

      result = parse('foo(1, 2 + 5)')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::FunctionCallNode.new(
              name:      'foo',
              arguments: [
                AST::IntegerLiteralNode.new(value: '1'),
                AST::BinaryExpressionNode.new(
                  operator: Token.new(Token::PLUS, Span::ZERO),
                  left:     AST::IntegerLiteralNode.new(value: '2'),
                  right:    AST::IntegerLiteralNode.new(value: '5'),
                ),
              ],
            ),
          ),
        ],
      )
      assert_equal false, result.err?, result.errors
      assert_equal expected, result.ast
      result = parse("foo(\n1,\n2 + 5,\n)")
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::FunctionCallNode.new(
              name:      'foo',
              arguments: [
                AST::IntegerLiteralNode.new(value: '1'),
                AST::BinaryExpressionNode.new(
                  operator: Token.new(Token::PLUS, Span::ZERO),
                  left:     AST::IntegerLiteralNode.new(value: '2'),
                  right:    AST::IntegerLiteralNode.new(value: '5'),
                ),
              ],
            ),
          ),
        ],
      )
      assert_equal false, result.err?, result.errors
      assert_equal expected, result.ast

      result = parse('foo(1, bar("baz"))')
      expected = AST::ProgramNode.new(
        statements: [
          AST::ExpressionStatementNode.new(
            expression: AST::FunctionCallNode.new(
              name:      'foo',
              arguments: [
                AST::IntegerLiteralNode.new(value: '1'),
                AST::FunctionCallNode.new(
                  name:      'bar',
                  arguments: [
                    AST::StringLiteralNode.new(value: 'baz'),
                  ],
                ),
              ],
            ),
          ),
        ],
      )
      assert_equal false, result.err?, result.errors
      assert_equal expected, result.ast
    end

    private

    sig { params(source: String).returns(Parser::Result) }
    def parse(source)
      Parser.parse(source)
    end
  end
end
