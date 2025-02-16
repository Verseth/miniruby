# typed: true
# frozen_string_literal: true

require 'test_helper'
require 'debug'

module MiniRuby
  class TestCompiler < TestCase
    def test_integer
      result = compile('124')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::RETURN,
        ),
        value_pool:   [
          124,
        ],
      )
      assert_equal expected, result

      err = assert_raises Compiler::Error do
        compile('0124')
      end
      expected = Compiler::Error['illegal trailing zero in number literal']
      assert_equal expected, err
    end

    def test_float
      result = compile('12.4')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::RETURN,
        ),
        value_pool:   [
          12.4,
        ],
      )
      assert_equal expected, result

      result = compile('12e4')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::RETURN,
        ),
        value_pool:   [
          1.2e5,
        ],
      )
      assert_equal expected, result

      err = assert_raises Compiler::Error do
        compile('12.4.5')
      end
      expected = Compiler::Error['unexpected char `.`', 'unexpected INTEGER, expected a statement separator']
      assert_equal expected, err
    end

    def test_simple_literal
      result = compile('false')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::FALSE,
          Opcode::RETURN,
        ),
      )
      assert_equal expected, result

      result = compile('true')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::TRUE,
          Opcode::RETURN,
        ),
      )
      assert_equal expected, result

      result = compile('nil')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::NIL,
          Opcode::RETURN,
        ),
      )
      assert_equal expected, result
    end

    def test_locals
      err = assert_raises Compiler::Error do
        compile('foo')
      end
      expected = Compiler::Error['undefined local: foo']
      assert_equal expected, err

      result = compile(<<~RUBY)
        foo = 3
        foo + 5
      RUBY
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::PREP_LOCALS, 1,
          Opcode::LOAD_VALUE, 0,
          Opcode::SET_LOCAL, 1,
          Opcode::POP,
          Opcode::GET_LOCAL, 1,
          Opcode::LOAD_VALUE, 1,
          Opcode::ADD,
          Opcode::RETURN,
        ),
        value_pool:   [
          3,
          5,
        ],
      )
      assert_equal expected, result
    end

    def test_return
      result = compile('return')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::NIL,
          Opcode::RETURN,
          Opcode::RETURN,
        ),
      )
      assert_equal expected, result

      result = compile('return 5 + 2')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::LOAD_VALUE, 1,
          Opcode::ADD,
          Opcode::RETURN,
          Opcode::RETURN,
        ),
        value_pool:   [
          5,
          2,
        ],
      )
      assert_equal expected, result

      result = compile('a = return 5')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::PREP_LOCALS, 1,
          Opcode::LOAD_VALUE, 0,
          Opcode::RETURN,
          Opcode::SET_LOCAL, 1,
          Opcode::RETURN,
        ),
        value_pool:   [
          5,
        ],
      )
      assert_equal expected, result
    end

    def test_while
      result = compile(<<~RUBY)
        a = 0
        while a < 5
          a = a + 2
          !a
        end
      RUBY
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::PREP_LOCALS, 1,
          Opcode::LOAD_VALUE, 0,
          Opcode::SET_LOCAL, 1,
          Opcode::POP,
          Opcode::NIL,

          # condition
          Opcode::GET_LOCAL, 1,
          Opcode::LOAD_VALUE, 1,
          Opcode::LESS,
          Opcode::JUMP_UNLESS, 14,

          # then
          Opcode::POP,
          # a = a + 2
          Opcode::GET_LOCAL, 1,
          Opcode::LOAD_VALUE, 2,
          Opcode::ADD,
          Opcode::SET_LOCAL, 1,
          Opcode::POP,
          # !a
          Opcode::GET_LOCAL, 1,
          Opcode::NOT,
          Opcode::LOOP, 22,

          Opcode::RETURN,
        ),
        value_pool:   [
          0,
          5,
          2,
        ],
      )
      assert_equal expected, result
    end

    def test_if
      result = compile(<<~RUBY)
        a = 1
        if a != 5
          a = a + 2
          !a
        end
      RUBY
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::PREP_LOCALS, 1,
          Opcode::LOAD_VALUE, 0,
          Opcode::SET_LOCAL, 1,
          Opcode::POP,
          Opcode::GET_LOCAL, 1,
          Opcode::LOAD_VALUE, 1,
          Opcode::EQUAL,
          Opcode::NOT,
          Opcode::JUMP_UNLESS, 13,
          Opcode::GET_LOCAL, 1,
          Opcode::LOAD_VALUE, 2,
          Opcode::ADD,
          Opcode::SET_LOCAL, 1,
          Opcode::POP,
          Opcode::GET_LOCAL, 1,
          Opcode::NOT,
          Opcode::JUMP, 1,
          Opcode::NIL,
          Opcode::RETURN,
        ),
        value_pool:   [
          1,
          5,
          2,
        ],
      )
      assert_equal expected, result

      result = compile(<<~RUBY)
        a = 1
        if a != 5
          a = a + 2
          !a
        else
          b = 2
          a = b
        end
      RUBY
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::PREP_LOCALS, 2,

          # a = 1
          Opcode::LOAD_VALUE, 0,
          Opcode::SET_LOCAL, 1,
          Opcode::POP,

          # if a != 5
          Opcode::GET_LOCAL, 1,
          Opcode::LOAD_VALUE, 1,
          Opcode::EQUAL,
          Opcode::NOT,
          Opcode::JUMP_UNLESS, 13,

          # a = a + 2
          Opcode::GET_LOCAL, 1,
          Opcode::LOAD_VALUE, 2,
          Opcode::ADD,
          Opcode::SET_LOCAL, 1,
          Opcode::POP,

          # !a
          Opcode::GET_LOCAL, 1,
          Opcode::NOT,

          # jump over else
          Opcode::JUMP, 9,

          # b = 2
          Opcode::LOAD_VALUE, 2,
          Opcode::SET_LOCAL, 2,
          Opcode::POP,

          # a = b
          Opcode::GET_LOCAL, 2,
          Opcode::SET_LOCAL, 1,

          Opcode::RETURN,
        ),
        value_pool:   [
          1,
          5,
          2,
        ],
      )
      assert_equal expected, result
    end

    def test_unary_operators
      result = compile('!5')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::NOT,
          Opcode::RETURN,
        ),
        value_pool:   [
          5,
        ],
      )
      assert_equal expected, result

      result = compile('-10')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::NEGATE,
          Opcode::RETURN,
        ),
        value_pool:   [
          10,
        ],
      )
      assert_equal expected, result

      result = compile('+7')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::RETURN,
        ),
        value_pool:   [
          7,
        ],
      )
      assert_equal expected, result

      result = compile('!!!3')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::NOT,
          Opcode::NOT,
          Opcode::NOT,
          Opcode::RETURN,
        ),
        value_pool:   [
          3,
        ],
      )
      assert_equal expected, result

      result = compile('!(9 + 6)')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::LOAD_VALUE, 1,
          Opcode::ADD,
          Opcode::NOT,
          Opcode::RETURN,
        ),
        value_pool:   [
          9,
          6,
        ],
      )
      assert_equal expected, result
    end

    def test_multiplicative_operators
      result = compile('10 * 14 / 92')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::LOAD_VALUE, 1,
          Opcode::MULTIPLY,
          Opcode::LOAD_VALUE, 2,
          Opcode::DIVIDE,
          Opcode::RETURN,
        ),
        value_pool:   [
          10,
          14,
          92,
        ],
      )
      assert_equal expected, result

      result = compile('10 + 14 * 92')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::LOAD_VALUE, 1,
          Opcode::LOAD_VALUE, 2,
          Opcode::MULTIPLY,
          Opcode::ADD,
          Opcode::RETURN,
        ),
        value_pool:   [
          10,
          14,
          92,
        ],
      )
      assert_equal expected, result
    end

    def test_additive_operators
      result = compile('10 + 14 - 9.2')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::LOAD_VALUE, 1,
          Opcode::ADD,
          Opcode::LOAD_VALUE, 2,
          Opcode::SUBTRACT,
          Opcode::RETURN,
        ),
        value_pool:   [
          10,
          14,
          9.2,
        ],
      )
      assert_equal expected, result

      result = compile('10 + (14 - 9.2)')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::LOAD_VALUE, 1,
          Opcode::LOAD_VALUE, 2,
          Opcode::SUBTRACT,
          Opcode::ADD,
          Opcode::RETURN,
        ),
        value_pool:   [
          10,
          14,
          9.2,
        ],
      )
      assert_equal expected, result
    end

    def test_comparison_operators
      result = compile('5 > 2.5 < 9')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::LOAD_VALUE, 1,
          Opcode::GREATER,
          Opcode::LOAD_VALUE, 2,
          Opcode::LESS,
          Opcode::RETURN,
        ),
        value_pool:   [
          5,
          2.5,
          9,
        ],
      )
      assert_equal expected, result

      result = compile('5 > 2.5 + 9')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::LOAD_VALUE, 1,
          Opcode::LOAD_VALUE, 2,
          Opcode::ADD,
          Opcode::GREATER,
          Opcode::RETURN,
        ),
        value_pool:   [
          5,
          2.5,
          9,
        ],
      )
      assert_equal expected, result
    end

    def test_equality_operators
      result = compile('5 == 2.5 != 9')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::LOAD_VALUE, 1,
          Opcode::EQUAL,
          Opcode::LOAD_VALUE, 2,
          Opcode::EQUAL,
          Opcode::NOT,
          Opcode::RETURN,
        ),
        value_pool:   [
          5,
          2.5,
          9,
        ],
      )
      assert_equal expected, result

      result = compile('5 == 2.5 < 9')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::LOAD_VALUE, 0,
          Opcode::LOAD_VALUE, 1,
          Opcode::LOAD_VALUE, 2,
          Opcode::LESS,
          Opcode::EQUAL,
          Opcode::RETURN,
        ),
        value_pool:   [
          5,
          2.5,
          9,
        ],
      )
      assert_equal expected, result
    end

    def test_assignment_operator
      result = compile('a = b = 5')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::PREP_LOCALS, 2,
          Opcode::LOAD_VALUE, 0,
          Opcode::SET_LOCAL, 1,
          Opcode::SET_LOCAL, 2,
          Opcode::RETURN,
        ),
        value_pool:   [
          5,
        ],
      )
      assert_equal expected, result

      result = compile('a = 5 == 2.5')
      expected = BytecodeFunction.new(
        instructions: pack(
          Opcode::PREP_LOCALS, 1,
          Opcode::LOAD_VALUE, 0,
          Opcode::LOAD_VALUE, 1,
          Opcode::EQUAL,
          Opcode::SET_LOCAL, 1,
          Opcode::RETURN,
        ),
        value_pool:   [
          5,
          2.5,
        ],
      )
      assert_equal expected, result
    end

    private

    sig { params(bytes: Integer).returns(String) }
    def pack(*bytes)
      BytecodeFunction.pack_instructions!(bytes)
    end

    sig { params(source: String).returns(BytecodeFunction) }
    def compile(source)
      Compiler.compile_source(source:)
    end
  end
end
