# typed: true
# frozen_string_literal: true

require 'test_helper'
require 'debug'

module MiniRuby
  class TestVM < TestCase
    def test_integer
      result = interpret('124')
      assert_equal 124, result

      err = assert_raises Compiler::Error do
        interpret('0124')
      end
      expected = Compiler::Error['illegal trailing zero in number literal']
      assert_equal expected, err
    end

    def test_float
      result = interpret('12.4')
      assert_equal 12.4, result

      result = interpret('12e4')
      assert_equal 1.2e5, result

      err = assert_raises Compiler::Error do
        interpret('12.4.5')
      end
      expected = Compiler::Error['unexpected char `.`', 'unexpected INTEGER, expected a statement separator']
      assert_equal expected, err
    end

    def test_simple_literal
      result = interpret('false')
      assert_equal false, result

      result = interpret('true')
      assert_equal true, result

      result = interpret('nil')
      assert_nil result

      result = interpret('self')
      assert_equal Object, result.class
    end

    def test_locals
      err = assert_raises Compiler::Error do
        interpret('foo')
      end
      expected = Compiler::Error['undefined local: foo']
      assert_equal expected, err

      result = interpret(<<~RUBY)
        foo = 3
        foo + 5
      RUBY
      assert_equal 8, result
    end

    def test_return
      result = interpret('return')
      assert_nil result

      result = interpret('return 5 + 2')
      assert_equal 7, result

      result = interpret('a = return 5')
      assert_equal 5, result
    end

    def test_function_call
      result, stdout = interpret_stdout('puts("foo")')
      assert_nil result
      assert_equal "foo\n", stdout

      result, stdout = interpret_stdout('print("foo" + " " + "bar")')
      assert_nil result
      assert_equal 'foo bar', stdout

      result = interpret('gets()', stdin: StringIO.new('elo'))
      assert_equal 'elo', result

      result = interpret('len("foo")')
      assert_equal 3, result
    end

    def test_while
      result, stdout = interpret_stdout(<<~RUBY)
        a = 0
        while a < 5
          a = a + 2
          puts(a)
        end

        a
      RUBY
      assert_equal 6, result
      assert_equal "2\n4\n6\n", stdout
    end

    def test_if
      result, stdout = interpret_stdout(<<~RUBY)
        a = 1
        if a != 5
          puts("if")
          a + 2
        end
      RUBY
      assert_equal 3, result
      assert_equal "if\n", stdout

      result, stdout = interpret_stdout(<<~RUBY)
        a = 1
        if a == 5
          puts("if")
          a = a + 2
        else
          puts("else")
          10
        end
      RUBY
      assert_equal 10, result
      assert_equal "else\n", stdout

      result, stdout = interpret_stdout(<<~RUBY)
        a = 1
        if a != 5
          puts("if")
          a = a + 2
        else
          puts("else")
          10
        end
      RUBY
      assert_equal 3, result
      assert_equal "if\n", stdout
    end

    def test_unary_operators
      result = interpret('!5')
      assert_equal false, result

      result = interpret('-10')
      assert_equal(-10, result)

      result = interpret('+7')
      assert_equal 7, result

      result = interpret('!!!3')
      assert_equal false, result

      result = interpret('!!3')
      assert_equal true, result

      result = interpret('!(9 + 6)')
      assert_equal false, result
    end

    def test_multiplicative_operators
      result = interpret('10 * 14 / 80.0')
      assert_equal 1.75, result

      result = interpret('10 + 14 * 92')
      assert_equal 1298, result
    end

    def test_additive_operators
      result = interpret('10 + 14 - 9.2')
      assert_equal 14.8, result

      result = interpret('10 + (14 * 9.5)')
      assert_equal 143.0, result
    end

    def test_comparison_operators
      result = interpret('5 > 2.5')
      assert_equal true, result

      result = interpret('5 < 2.5')
      assert_equal false, result
    end

    def test_equality_operators
      result = interpret('5 == 2.5')
      assert_equal false, result

      result = interpret('5 != 2.5')
      assert_equal true, result
    end

    def test_assignment_operator
      result = interpret('a = b = 5')
      assert_equal 5, result

      result = interpret('a = 5 == 2.5')
      assert_equal false, result
    end

    private

    sig { params(source: String, stdout: IO, stdin: IO).returns(Object) }
    def interpret(source, stdout: $stdout, stdin: $stdin)
      VM.interpret(source, stdout:, stdin:)
    end

    sig { params(source: String, stdin: IO).returns([Object, String]) }
    def interpret_stdout(source, stdin: $stdin)
      stdout = StringIO.new
      result = VM.interpret(source, stdout:, stdin:)

      [result, stdout.string]
    end
  end
end
