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

      #: (BytecodeFunction bytecode, ?stdout: IO, ?stdin: IO) -> Object
      def run(bytecode, stdout: $stdout, stdin: $stdin)
        vm = new(bytecode, stdout:, stdin:)
        vm.run
        vm.stack_top
      end

      #: (String source, ?name: String, ?filename: String, ?stdout: IO, ?stdin: IO) -> Object
      def interpret(source, name: '<main>', filename: '<main>', stdout: $stdout, stdin: $stdin)
        bytecode = Compiler.compile_source(source, name:, filename:)
        run(bytecode, stdout:, stdin:)
      end
    end

    #: BytecodeFunction
    attr_reader :bytecode

    #: IO
    attr_reader :stdout

    #: IO
    attr_reader :stdin

    #: (BytecodeFunction bytecode, ?stdout: IO, ?stdin: IO) -> void
    def initialize(bytecode, stdout: $stdout, stdin: $stdin)
      # the currently executed chunk of bytecode
      @bytecode = bytecode
      # standard output used by the VM
      @stdout = stdout
      # standard input used by the VM
      @stdin = stdin

      # The value stack
      @stack = [Object.new] #: Array[Object]
      # Instruction pointer -- points to the next bytecode instruction
      @ip = 0 #: Integer
      # Stack pointer -- points to the offset on the stack where the next value will be pushed to
      @sp = 1 #: Integer
    end

    Func = T.type_alias { T.proc.params(vm: VM, args: T::Array[Object]).returns(Object) }

    @functions = {} #: Hash[Symbol, NativeFunction]
    class << self
      extend T::Sig

      #: (Symbol name, ?Integer param_count) { (?) -> untyped } -> void
      def define(name, param_count = 0, &func)
        @functions[name] = NativeFunction.new(name:, param_count:, &func)
      end

      #: Hash[Symbol, NativeFunction]
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

    #: -> void
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
          left = pop() #: as untyped
          push(left + right)
        when Opcode::SUBTRACT
          right = pop
          left = pop #: as untyped
          push(left - right)
        when Opcode::MULTIPLY
          right = pop
          left = pop #: as untyped
          push(left * right)
        when Opcode::DIVIDE
          right = pop
          left = pop #: as untyped
          push(left / right)
        when Opcode::EQUAL
          right = pop
          left = pop #: as untyped
          push(left == right)
        when Opcode::GREATER
          right = pop
          left = pop #: as untyped
          push(left > right)
        when Opcode::GREATER_EQUAL
          right = pop
          left = pop #: as untyped
          push(left >= right)
        when Opcode::LESS
          right = pop
          left = pop #: as untyped
          push(left < right)
        when Opcode::LESS_EQUAL
          right = pop
          left = pop #: as untyped
          push(left <= right)
        when Opcode::NOT
          value = pop
          push(!value)
        when Opcode::NEGATE
          value = pop #: as untyped
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
          call_info = get_value(index) #: as CallInfo
          to_pop = call_info.arg_count + 1
          args = @stack[(@sp - to_pop)...@sp] #: as !nil
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

    #: -> void
    def inspect_stack
      @stdout.print("#{@stack[...@sp].inspect}\n")
    end

    #: -> Object
    def stack_top
      @stack[@sp - 1]
    end

    private

    #: (Integer index) -> Object
    def get_value(index)
      @bytecode.value_pool.fetch(index)
    end

    #: (Integer index) -> void
    def push_local(index)
      push(get_local(index))
    end

    #: (Integer index) -> Object
    def get_local(index)
      @stack[index]
    end

    #: (Integer index, Object value) -> void
    def set_local(index, value)
      @stack[index] = value
    end

    #: -> Integer
    def read_byte
      byte = @bytecode.instructions.getbyte(@ip) #: as !nil
      @ip += 1

      byte
    end

    #: (Object value) -> void
    def push(value)
      @stack[@sp] = value
      @sp += 1
    end

    #: -> Object
    def pop
      @sp -= 1
      val = @stack[@sp]
      @stack[@sp] = nil

      val
    end

    #: -> Object
    def peek
      @stack[@sp - 1]
    end

  end
end
