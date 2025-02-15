# typed: true
# frozen_string_literal: true

require 'test_helper'

module MiniRuby
  class TestLexer < TestCase
    def test_lex
      expected = [
        Token.new(Token::GREATER, S(P(2), P(2))),
        Token.new(Token::GREATER_EQUAL, S(P(4), P(5))),
        Token.new(Token::LESS, S(P(7), P(7))),
        Token.new(Token::LESS_EQUAL, S(P(9), P(10))),
        Token.new(Token::EQUAL, S(P(12), P(12))),
        Token.new(Token::EQUAL_EQUAL, S(P(14), P(15))),
        Token.new(Token::NOT_EQUAL, S(P(17), P(18))),
        Token.new(Token::BANG, S(P(20), P(20))),
        Token.new(Token::STRING, S(P(22), P(28)), "foo\n"),
        Token.new(Token::SLASH, S(P(30), P(30))),
        Token.new(Token::STRING, S(P(32), P(38)), "ba\rr"),
        Token.new(Token::STAR, S(P(40), P(40))),
        Token.new(Token::STRING, S(P(42), P(52)), "elo\uffe9"),
        Token.new(Token::PLUS, S(P(54), P(54))),
        Token.new(Token::MINUS, S(P(56), P(56))),
        Token.new(Token::INTEGER, S(P(57), P(57)), '1'),
        Token.new(Token::COMMA, S(P(58), P(58))),
        Token.new(Token::PLUS, S(P(60), P(60))),
        Token.new(Token::FLOAT, S(P(61), P(64)), '0.25'),
        Token.new(Token::COMMA, S(P(65), P(65))),
        Token.new(Token::FLOAT, S(P(67), P(69)), '5e9'),
        Token.new(Token::COMMA, S(P(70), P(70))),
        Token.new(Token::FLOAT, S(P(72), P(76)), '5e-20'),
        Token.new(Token::COMMA, S(P(77), P(77))),
        Token.new(Token::FLOAT, S(P(79), P(83)), '14e+9'),
        Token.new(Token::COMMA, S(P(84), P(84))),
        Token.new(Token::FALSE, S(P(86), P(90))),
        Token.new(Token::COMMA, S(P(91), P(91))),
        Token.new(Token::TRUE, S(P(93), P(96))),
        Token.new(Token::COMMA, S(P(97), P(97))),
        Token.new(Token::NIL, S(P(99), P(101))),
        Token.new(Token::RETURN, S(P(103), P(108))),
        Token.new(Token::SEMICOLON, S(P(109), P(109))),
        Token.new(Token::WHILE, S(P(111), P(115))),
        Token.new(Token::NEWLINE, S(P(116), P(116))),
        Token.new(Token::IF, S(P(117), P(118))),
        Token.new(Token::IDENTIFIER, S(P(120), P(122)), 'foo'),
      ]
      input = '  > >= < <= = == != ! "foo\n" / "ba\rr" * "elo\uffe9" + -1, +0.25, 5e9, ' \
              "5e-20, 14e+9, false, true, nil return; while\nif foo"
      assert_equal expected, lex(input)
      assert_equal expected, lex(input)

      expected = [
        Token.new(Token::INTEGER, S(P(0), P(2)), '123'),
      ]
      assert_equal expected, lex('123')

      expected = [
        Token.new(Token::ERROR, S(P(0), P(3)), 'unterminated string literal'),
      ]
      assert_equal expected, lex('"foo')

      expected = [
        Token.new(Token::ERROR, S(P(0), P(9)), 'invalid escape `\g`'),
        Token.new(Token::INTEGER, S(P(11), P(13)), '123'),
      ]
      assert_equal expected, lex('"lol\gelo" 123')

      expected = [
        Token.new(Token::ERROR, S(P(0), P(10)), 'invalid unicode escape'),
        Token.new(Token::INTEGER, S(P(12), P(14)), '123'),
      ]
      assert_equal expected, lex('"lol\ugego" 123')

      expected = [
        Token.new(Token::IDENTIFIER, S(P(0), P(10)), 'fdg1234fsdf'),
        Token.new(Token::COMMA, S(P(11), P(11))),
        Token.new(Token::INTEGER, S(P(13), P(15)), '123'),
      ]
      assert_equal expected, lex('fdg1234fsdf, 123')

      expected = [
        Token.new(Token::IDENTIFIER, S(P(0), P(10)), 'fdg1234fsdf'),
      ]
      assert_equal expected, lex('fdg1234fsdf')

      expected = [
        Token.new(Token::INTEGER, S(P(0), P(2)), '123'),
        Token.new(Token::IDENTIFIER, S(P(3), P(5)), 'fge'),
      ]
      assert_equal expected, lex('123fge')

      expected = [
        Token.new(Token::FLOAT, S(P(0), P(6)), '123.985'),
      ]
      assert_equal expected, lex('123.985')

      expected = [
        Token.new(Token::INTEGER, S(P(0), P(0)), '0'),
      ]
      assert_equal expected, lex('0')

      expected = [
        Token.new(Token::ERROR, S(P(0), P(4)), 'illegal trailing zero in number literal'),
        Token.new(Token::STRING, S(P(6), P(10)), 'lol'),
      ]
      assert_equal expected, lex('05812 "lol"')

      expected = [
        Token.new(Token::FLOAT, S(P(0), P(3)), '0.12'),
      ]
      assert_equal expected, lex('0.12')

      expected = [
        Token.new(Token::FLOAT, S(P(0), P(2)), '5e9'),
      ]
      assert_equal expected, lex('5e9')

      expected = [
        Token.new(Token::FLOAT, S(P(0), P(2)), '5E9'),
      ]
      assert_equal expected, lex('5E9')

      expected = [
        Token.new(Token::FLOAT, S(P(0), P(3)), '5e+9'),
      ]
      assert_equal expected, lex('5e+9')

      expected = [
        Token.new(Token::FLOAT, S(P(0), P(3)), '5e-9'),
      ]
      assert_equal expected, lex('5e-9')

      expected = [
        Token.new(Token::FLOAT, S(P(0), P(4)), '1.5e9'),
      ]
      assert_equal expected, lex('1.5e9')

      expected = [
        Token.new(Token::FLOAT, S(P(0), P(5)), '1.5e+9'),
      ]
      assert_equal expected, lex('1.5e+9')

      expected = [
        Token.new(Token::FLOAT, S(P(0), P(5)), '1.5e-9'),
      ]
      assert_equal expected, lex('1.5e-9')
    end

    private

    def lex(source)
      Lexer.new(source).to_a
    end
  end
end
