# typed: strict
# frozen_string_literal: true

require_relative 'call_info'
require_relative 'native_function'

module MiniRuby
  # MiniRuby stack based Virtual Machine.
  # Executes a chunk of bytecode produced by the compiler.
  class VM
    extend T::Sig

    class << self
      extend T::Sig

      sig do
        params(
          bytecode: BytecodeFunction,
          stdout:   IO,
          stdin:    IO,
        ).returns(Object)
      end
      def run(bytecode, stdout: $stdout, stdin: $stdin)
        vm = new(bytecode, stdout:, stdin:)
        vm.run
        vm.stack_top
      end

      sig { params(source: String, name: String, filename: String, stdout: IO, stdin: IO).returns(Object) }
      def interpret(source, name: '<main>', filename: '<main>', stdout: $stdout, stdin: $stdin)
        bytecode = Compiler.compile_source(source, name:, filename:)
        run(bytecode, stdout:, stdin:)
      end
    end

    sig { returns BytecodeFunction }
    attr_reader :bytecode

    sig { returns IO }
    attr_reader :stdout

    sig { returns IO }
    attr_reader :stdin

    sig do
      params(
        bytecode: BytecodeFunction,
        stdout:   IO,
        stdin:    IO,
      ).void
    end
    def initialize(bytecode, stdout: $stdout, stdin: $stdin)
      # the currently executed chunk of bytecode
      @bytecode = bytecode
      # standard output used by the VM
      @stdout = stdout
      # standard input used by the VM
      @stdin = stdin

      # The value stack
      @stack = T.let([Object.new], T::Array[Object])
      # Instruction pointer -- points to the next bytecode instruction
      @ip = T.let(0, Integer)
      # Stack pointer -- points to the offset on the stack where the next value will be pushed to
      @sp = T.let(1, Integer)
    end

    Func = T.type_alias { T.proc.params(vm: VM, args: T::Array[Object]).returns(Object) }

    @functions = T.let({}, T::Hash[Symbol, NativeFunction])
    class << self
      extend T::Sig

      sig { params(name: Symbol, param_count: Integer, func: NativeFunction::Func).void }
      def define(name, param_count = 0, &func)
        @functions[name] = NativeFunction.new(name:, param_count:, &func)
      end

      sig { returns T::Hash[Symbol, NativeFunction] }
      attr_reader :functions
    end

    define :print, 1 do |vm, args|
      vm.stdout.print(args[1])
    end
    define :puts, 1 do |vm, args|
      vm.stdout.puts(args[1])
    end
    define :gets do |vm, _args|
      vm.stdin.gets
    end
    define :len, 1 do |_vm, args|
      T.unsafe(args[1]).length
    end

    sig { void }
    def run
      while true
        opcode = read_byte
        case opcode
        when Opcode::TRUE
          push(true)
        when Opcode::FALSE
          push(false)
        when Opcode::NIL
          push(nil)
        when Opcode::POP
          pop()
        when Opcode::DUP
          push(peek)
        when Opcode::INSPECT_STACK
          inspect_stack()
        when Opcode::ADD
          right = pop()
          left = T.unsafe(pop())
          push(left + right)
        when Opcode::SUBTRACT
          right = pop
          left = T.unsafe(pop)
          push(left - right)
        when Opcode::MULTIPLY
          right = pop
          left = T.unsafe(pop)
          push(left * right)
        when Opcode::DIVIDE
          right = pop
          left = T.unsafe(pop)
          push(left / right)
        when Opcode::EQUAL
          right = pop
          left = T.unsafe(pop)
          push(left == right)
        when Opcode::GREATER
          right = pop
          left = T.unsafe(pop)
          push(left > right)
        when Opcode::GREATER_EQUAL
          right = pop
          left = T.unsafe(pop)
          push(left >= right)
        when Opcode::LESS
          right = pop
          left = T.unsafe(pop)
          push(left < right)
        when Opcode::LESS_EQUAL
          right = pop
          left = T.unsafe(pop)
          push(left <= right)
        when Opcode::NOT
          value = pop
          push(!value)
        when Opcode::NEGATE
          value = T.unsafe(pop)
          push(-value)
        when Opcode::LOAD_VALUE
          index = read_byte
          push(get_value(index))
        when Opcode::SELF
          push_local(0)
        when Opcode::PREP_LOCALS
          @sp += read_byte
        when Opcode::GET_LOCAL
          push_local(read_byte)
        when Opcode::SET_LOCAL
          value = peek
          local_index = read_byte
          set_local(local_index, value)
        when Opcode::JUMP
          offset = read_byte
          @ip += offset
        when Opcode::LOOP
          offset = read_byte
          @ip -= offset
        when Opcode::JUMP_UNLESS
          condition = pop
          offset = read_byte
          next if condition

          @ip += offset
        when Opcode::CALL
          index = read_byte
          call_info = T.cast(get_value(index), CallInfo)
          to_pop = call_info.arg_count + 1
          args = T.must @stack[@sp - to_pop...@sp]
          result = self.class.functions.fetch(call_info.name).call(self, args)
          args.each { pop }
          push(result)
        when Opcode::RETURN
          return
        else
          raise ArgumentError, "invalid opcode: #{opcode}"
        end
      end
    end

    sig { void }
    def inspect_stack
      @stdout.print("#{@stack[...@sp].inspect}\n")
    end

    sig { returns Object }
    def stack_top
      @stack[@sp - 1]
    end

    private

    sig { params(index: Integer).returns(Object) }
    def get_value(index)
      @bytecode.value_pool.fetch(index)
    end

    sig { params(index: Integer).void }
    def push_local(index)
      push(get_local(index))
    end

    sig { params(index: Integer).returns(Object) }
    def get_local(index)
      @stack[index]
    end

    sig { params(index: Integer, value: Object).void }
    def set_local(index, value)
      @stack[index] = value
    end

    sig { returns Integer }
    def read_byte
      byte = T.must @bytecode.instructions.getbyte(@ip)
      @ip += 1

      byte
    end

    sig { params(value: Object).void }
    def push(value)
      @stack[@sp] = value
      @sp += 1
    end

    sig { returns(Object) }
    def pop
      @sp -= 1
      val = @stack[@sp]
      @stack[@sp] = nil

      val
    end

    sig { returns(Object) }
    def peek
      @stack[@sp - 1]
    end

  end
end
