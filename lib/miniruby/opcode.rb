# typed: true
# frozen_string_literal: true

module MiniRuby
  # Contains the definitions of all operation codes
  # supported by the Virtual Machine.
  module Opcode
    extend T::Sig

    @next_id = T.let(0, Integer)
    @name_to_opcode = T.let({}, T::Hash[String, Integer])
    @opcode_to_name = T.let({}, T::Hash[Integer, String])

    class << self
      extend T::Sig

      sig { returns(Integer) }
      def next_id
        i = @next_id
        @next_id += 1

        i
      end

      # Converts an opcode to its name, returns 'UNKNOWN' when
      # there is no opcode with the given index.
      sig { params(opcode: Integer).returns(String) }
      def name(opcode)
        @opcode_to_name.fetch(opcode, 'UNKNOWN')
      end

      # Returns the opcode related to the given name.
      # Returns -1 when there is no opcode with the given name.
      sig { params(name: String).returns(Integer) }
      def from_name(name)
        @name_to_opcode.fetch(name, -1)
      end

      sig { params(opcodes: Integer).void }
      def define(**opcodes)
        @name_to_opcode = opcodes.transform_keys(&:to_s)
        @opcode_to_name = @name_to_opcode.invert
      end
    end

    define(
      # No operation, placeholder
      NOOP:          NOOP = T.let(next_id, Integer),
      # Pops a value off the stack
      POP:           POP = T.let(next_id, Integer),
      # Pushes the value on top of the stack (duplicates it).
      DUP:           DUP = T.let(next_id, Integer),
      # Prints the stack, for debugging
      INSPECT_STACK: INSPECT_STACK = T.let(next_id, Integer),

      # Arithmetic
      # ==========

      # Pops two values off the stack, adds them together and pushes the result
      ADD:           ADD = T.let(next_id, Integer),
      # Pops two values off the stack, subtracts them and pushes the result
      SUBTRACT:      SUBTRACT = T.let(next_id, Integer),
      # Pops two values off the stack, multiplies them and pushes the result
      MULTIPLY:      MULTIPLY = T.let(next_id, Integer),
      # Pops two values off the stack, divides them and pushes the result
      DIVIDE:        DIVIDE = T.let(next_id, Integer),
      # Pops on value off the stack, negates it numerically and pushes the result (1 => -1)
      NEGATE:        NEGATE = T.let(next_id, Integer),

      # Comparison
      # ==========

      # Pops two values off the stack, checks if they're equal, pushes a boolean value
      EQUAL:         EQUAL = T.let(next_id, Integer),
      # Pops two values off the stack, checks if the first is greater, pushes a boolean value
      GREATER:       GREATER = T.let(next_id, Integer),
      # Pops two values off the stack, checks if the first is greater or equal, pushes a boolean value
      GREATER_EQUAL: GREATER_EQUAL = T.let(next_id, Integer),
      # Pops two values off the stack, checks if the first is less, pushes a boolean value
      LESS:          LESS = T.let(next_id, Integer),
      # Pops two values off the stack, checks if the first is less or equal, pushes a boolean value
      LESS_EQUAL:    LESS_EQUAL = T.let(next_id, Integer),

      # Logic
      # ==========

      # Pops one value off the stack, negates it logically and pushes the result (true => false)
      NOT:           NOT = T.let(next_id, Integer),

      # Values
      # ==========

      # Expects a single byte operand, pushes a value the with the given index to the stack
      LOAD_VALUE:    LOAD_VALUE = T.let(next_id, Integer),
      # Pushes `true` to the stack
      TRUE:          TRUE = T.let(next_id, Integer),
      # Pushes `false` to the stack
      FALSE:         FALSE = T.let(next_id, Integer),
      # Pushes `nil` to the stack
      NIL:           NIL = T.let(next_id, Integer),

      # Control flow
      # ==========

      # Returns form the current function
      RETURN:        RETURN = T.let(next_id, Integer),
      # Expects a single byte operand.
      # Jumps `n` bytes forward.
      JUMP:          JUMP = T.let(next_id, Integer),
      # Expects a single byte operand.
      # Jumps `n` bytes backward.
      LOOP:          LOOP = T.let(next_id, Integer),
      # Expects a single byte operand, pops one value off the stack.
      # Jumps `n` bytes forward if the value is falsy.
      JUMP_UNLESS:   JUMP_UNLESS = T.let(next_id, Integer),
      # Expects a single byte operand.
      # Calls the function with the given name.
      CALL:          CALL = T.let(next_id, Integer),

      # Variables
      # ==========

      # Expects a single byte operand.
      # Prepares slots for local variables.
      PREP_LOCALS:   PREP_LOCALS = T.let(next_id, Integer),
      # Expects a single byte operand.
      # Pushes the value of the local variable with the given index.
      GET_LOCAL:     GET_LOCAL = T.let(next_id, Integer),
      # Expects a single byte operand.
      # Assigns the value on top of the stack to the local variable with the given index.
      SET_LOCAL:     SET_LOCAL = T.let(next_id, Integer),
      # Pushes `self` onto the stack
      SELF:          SELF = T.let(next_id, Integer),
    )
  end
end
