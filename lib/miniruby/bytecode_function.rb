# typed: strict
# frozen_string_literal: true

require_relative 'io'

module MiniRuby
  # A chunk of bytecode produced by the compiler.
  # Can be executed by the Virtual Machine.
  class BytecodeFunction
    extend T::Sig

    class << self
      extend T::Sig

      #: (Array[Integer] bytes) -> String
      def pack_instructions!(bytes)
        bytes.pack('c*')
      end

      #: (*Integer bytes) -> String
      def pack_instructions(*bytes)
        pack_instructions!(bytes)
      end

      #: (String instructions) -> Array[Integer]
      def unpack_instructions(instructions)
        instructions.unpack('c*') #: as untyped
      end
    end

    #: String
    attr_reader :name

    #: String
    attr_reader :filename

    #: Span
    attr_reader :span

    #: Array[Object]
    attr_reader :value_pool

    # A byte-buffer containing instructions
    #: String
    attr_accessor :instructions

    #: (?name: String, ?filename: String, ?instructions: String, ?value_pool: Array[Object], ?span: Span) -> void
    def initialize(name: '<main>', filename: '<main>', instructions: String.new.b, value_pool: [], span: Span::ZERO)
      @name = name
      @filename = filename
      @instructions = instructions
      @value_pool = value_pool
      @span = span
    end

    ZERO = new(name: 'zero') #: BytecodeFunction

    #: (Array[Integer] bytes) -> void
    def add_bytes!(bytes)
      bytes.each do |byte|
        @instructions << byte.chr
      end
    end

    #: (*Integer bytes) -> void
    def add_bytes(*bytes)
      add_bytes!(bytes)
    end

    MAX_VALUE_ID = 255

    # Adds a value to the value pool and returns its index.
    # Throws when the index is larger than 255.
    #: (Object value) -> Integer
    def add_value(value)
      id = @value_pool.find_index { _1 == value }
      return id if id

      id = @value_pool.length
      if id > MAX_VALUE_ID
        throw ArgumentError, "could not add value to the pool, exceeded #{MAX_VALUE_ID + 1} elements"
      end

      @value_pool << value
      id
    end

    #: -> void
    def disassemble_stdout
      disassemble($stdout)
    end

    #: -> String
    def disassemble_string
      buff = StringIO.new
      disassemble(buff)

      buff.string
    end

    #: (IO out) -> void
    def disassemble(out)
      out.puts "== BytecodeFunction #{@name} at: #{@filename} =="
      return if @instructions.length == 0

      offset = 0
      while true
        offset = disassemble_instruction(out, offset)
        break if offset >= @instructions.length
      end

      @value_pool.each do |value|
        next unless value.is_a?(BytecodeFunction)

        out.puts
        value.disassemble(out)
      end
    end

    #: (Object other) -> bool
    def ==(other)
      return false unless other.is_a?(BytecodeFunction)

      @name == other.name &&
        @filename == other.filename &&
        @instructions == other.instructions &&
        @value_pool == other.value_pool
    end

    #: -> String
    def inspect
      disassemble_string
    end

    private

    #: (IO out, Integer offset) -> Integer
    def disassemble_instruction(out, offset)
      out.printf('%04d  ', offset)
      opcode = @instructions.getbyte(offset) #: as !nil

      case opcode
      when Opcode::NOOP, Opcode::POP, Opcode::DUP, Opcode::INSPECT_STACK,
        Opcode::ADD, Opcode::SUBTRACT, Opcode::MULTIPLY,
        Opcode::DIVIDE, Opcode::NEGATE, Opcode::EQUAL,
        Opcode::GREATER, Opcode::GREATER_EQUAL, Opcode::LESS, Opcode::LESS_EQUAL,
        Opcode::NOT, Opcode::TRUE, Opcode::FALSE, Opcode::NIL, Opcode::RETURN, Opcode::SELF

        disassemble_one_byte_instruction(out, Opcode.name(opcode), offset)
      when Opcode::GET_LOCAL, Opcode::SET_LOCAL, Opcode::PREP_LOCALS,
        Opcode::JUMP, Opcode::JUMP_UNLESS, Opcode::LOOP

        disassemble_numeric_operand(out, offset)
      when Opcode::LOAD_VALUE, Opcode::CALL
        disassemble_value(out, offset)
      else
        dump_bytes(out, offset, 1)
        out.printf("unknown operation %d (0x%X)\n", opcode, opcode)
        offset + 1
      end
    end

    #: (IO out, String name, Integer offset) -> Integer
    def disassemble_one_byte_instruction(out, name, offset)
      dump_bytes(out, offset, 1)
      out.puts(name)
      offset + 1
    end

    # The maximum number of bytes a single
    # instruction can take up.
    MAX_INSTRUCTION_BYTE_COUNT = 3

    #: (IO out, Integer offset, Integer count) -> void
    def dump_bytes(out, offset, count)
      i = offset
      while i < offset + count
        out.printf('%02X ', @instructions.getbyte(i))
        i += 1
      end

      i = count
      while i < MAX_INSTRUCTION_BYTE_COUNT
        out.print('   ')
        i += 1
      end
    end

    #: (IO out, Integer offset, Integer bytes) -> bool
    def check_bytes(out, offset, bytes)
      left_bytes = @instructions.length - offset
      if left_bytes < bytes
        dump_bytes(out, offset, left_bytes)
        print_opcode(out, offset)
        out.puts('not enough bytes')
        return false
      end

      true
    end

    #: (IO out, Integer offset) -> Integer
    def disassemble_numeric_operand(out, offset)
      bytes = 2
      return offset + 1 unless check_bytes(out, offset, 2)

      opcode = @instructions.getbyte(offset) #: as !nil

      dump_bytes(out, offset, bytes)
      print_opcode(out, opcode)

      a = @instructions.getbyte(offset + 1) #: as !nil
      print_num_field(out, a)
      out.puts

      offset + bytes
    end

    #: (IO out, Integer opcode) -> void
    def print_opcode(out, opcode)
      out.printf('%-18s', Opcode.name(opcode))
    end

    #: (IO out, Integer n) -> void
    def print_num_field(out, n)
      out.printf('%-16d', n)
    end

    #: (IO out, Integer offset) -> Integer
    def disassemble_value(out, offset)
      opcode = @instructions.getbyte(offset) #: as !nil
      return offset + 1 unless check_bytes(out, offset, 2)

      value_index = @instructions.getbyte(offset + 1) #: as !nil

      dump_bytes(out, offset, 2)
      print_opcode(out, opcode)

      if value_index >= @value_pool.length
        out.printf("invalid value index %d (0x%X)\n", value_index, value_index)
        return offset + 2
      end

      value = @value_pool[value_index]
      out.printf("%d (%s)\n", value_index, value.inspect)

      offset + 2
    end

  end
end
