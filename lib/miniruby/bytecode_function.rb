# typed: strict
# frozen_string_literal: true

module MiniRuby
  # A chunk of bytecode produced by the compiler.
  # Can be executed by the Virtual Machine.
  class BytecodeFunction
    extend T::Sig

    sig { returns(String) }
    attr_reader :name

    sig { returns(String) }
    attr_reader :filename

    sig { returns(Span) }
    attr_reader :span

    sig { returns(T::Array[Object]) }
    attr_reader :value_pool

    # A byte-buffer containing instructions
    sig { returns(String) }
    attr_accessor :instructions

    sig do
      params(
        name: String,
        filename: String,
        instructions: String,
        value_pool: T::Array[Object],
        span: Span,
      ).void
    end
    def initialize(name:, filename: '<main>', instructions: String.new.b, value_pool: [], span: Span::ZERO)
      @name = name
      @filename = filename
      @instructions = instructions
      @value_pool = value_pool
      @span = span
    end

    sig { params(bytes: T::Array[Integer]).void }
    def add_bytes!(bytes)
      bytes.each do |byte|
        @instructions << byte.chr
      end
    end

    sig { params(bytes: Integer).void }
    def add_bytes(*bytes)
      add_bytes!(bytes)
    end

    # Adds a value to the value pool and returns its index.
    # Throws when the index is larger than 255.
    sig { params(value: Object).returns(Integer) }
    def add_value(value)
      id = @value_pool.length
      if id > 255
        throw ArgumentError, "could not add value to the pool, exceeded 256 elements"
      end

      @value_pool << value
      id
    end

    sig { void }
    def disassemble_stdout
      disassemble($stdout)
    end

    sig { returns(String) }
    def disassemble_string
      buff = StringIO.new
      disassemble(T.unsafe(buff))

      buff.string
    end

    sig { params(out: IO).void }
    def disassemble(out)
      out.puts "== Disassembly of #{@name} at: #{@filename} =="
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

    private

    sig { params(out: IO, offset: Integer).returns(Integer) }
    def disassemble_instruction(out, offset)
      out.printf("%04d  ", offset)
      opcode = T.must @instructions.getbyte(offset)

      case opcode
      when Opcode::NOOP, Opcode::POP, Opcode::DUP, Opcode::INSPECT_STACK,
        Opcode::ADD, Opcode::SUBTRACT, Opcode::MULTIPLY,
        Opcode::DIVIDE, Opcode::NEGATE, Opcode::EQUAL,
        Opcode::GREATER, Opcode::GREATER_EQUAL, Opcode::LESS, Opcode::LESS_EQUAL,
        Opcode::NOT, Opcode::TRUE, Opcode::FALSE, Opcode::NIL, Opcode::RETURN
        disassemble_one_byte_instruction(out, Opcode.name(opcode), offset)
      when Opcode::GET_LOCAL, Opcode::SET_LOCAL, Opcode::PREP_LOCALS
        disassemble_numeric_operand(out, offset)
      when Opcode::LOAD_VALUE, Opcode::CALL
        disassemble_value(out, offset)
      else
        dump_bytes(out, offset, 1)
        out.printf("unknown operation %d (0x%X)\n", opcode, opcode)
        offset + 1
      end
    end

    sig do
      params(
        out: IO,
        name: String,
        offset: Integer,
      ).returns(Integer)
    end
    def disassemble_one_byte_instruction(out, name, offset)
      dump_bytes(out, offset, 1)
      out.puts(name)
      return offset + 1
    end

    # The maximum number of bytes a single
    # instruction can take up.
    MAX_INSTRUCTION_BYTE_COUNT = 3

    sig { params(out: IO, offset: Integer, count: Integer).void }
    def dump_bytes(out, offset, count)
      i = offset
      while i < offset+count
        out.printf("%02X ", @instructions.getbyte(i))
        i += 1
      end

      i = count
      while i < MAX_INSTRUCTION_BYTE_COUNT
        out.print("   ")
        i += 1
      end
    end

    sig { params(out: IO, offset: Integer, bytes: Integer).returns(T::Boolean) }
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

    sig { params(out: IO, offset: Integer).returns(Integer) }
    def disassemble_numeric_operand(out, offset)
      bytes = 2
      return offset + 1 unless check_bytes(out, offset, 2)

      opcode = T.must @instructions.getbyte(offset)

      dump_bytes(out, offset, bytes)
      print_opcode(out, opcode)

      a = T.must @instructions.getbyte(offset+1)
      print_num_field(out, a)
      out.puts

      return offset + bytes
    end

    sig { params(out: IO, opcode: Integer).void }
    def print_opcode(out, opcode)
	    out.printf("%-18s", Opcode.name(opcode))
    end

    sig { params(out: IO, n: Integer).void }
    def print_num_field(out, n)
      out.printf("%-16d", n)
    end


    sig { params(out: IO, offset: Integer).returns(Integer) }
    def disassemble_value(out, offset)
      opcode = T.must @instructions.getbyte(offset)
      return offset + 1 unless check_bytes(out, offset, 2)

      value_index = T.must @instructions.getbyte(offset+1)

      dump_bytes(out, offset, 2)
      print_opcode(out, opcode)

      if value_index >= @value_pool.length
        out.printf("invalid value index %d (0x%X)\n", value_index, value_index)
        return offset + 2
      end

      value = @value_pool[value_index]
      out.printf("%d (%s)\n", value_index, value.inspect)

      return offset + 2
    end

  end
end
