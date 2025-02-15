# typed: true
# frozen_string_literal: true

require 'test_helper'

module MiniRuby
  class TestParser < TestCase
    def test_integer
      result = parse('124')
      expected = AST::ProgramNode.new(
        S(P(0), P(0)),
        [
          AST::ExpressionStatementNode.new(
            S(P(0), P(0)),
            AST::IntegerLiteralNode.new(
              S(P(0), P(0)),
              '124',
            ),
          ),
        ],
      )
      assert_equal false, result.err?
      assert_equal expected, result.ast
    end

    private

    sig { params(source: String).returns(Parser::Result) }
    def parse(source)
      Parser.parse(source)
    end
  end
end
