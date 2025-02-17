# typed: strict
# frozen_string_literal: true

require_relative 'io'

module MiniRuby
  # A native function that is available in MiniRuby
  class NativeFunction
    extend T::Sig

    sig { returns(Symbol) }
    attr_reader :name

    sig { returns(Integer) }
    attr_reader :param_count

    Func = T.type_alias { T.proc.params(vm: VM, args: T::Array[Object]).returns(Object) }

    sig { returns(Func) }
    attr_reader :func

    sig do
      params(
        name:        Symbol,
        param_count: Integer,
        func:        Func,
      ).void
    end
    def initialize(name:, param_count: 0, &func)
      @name = name
      @func = func
      @param_count = param_count
    end

    sig { params(vm: VM, args: T::Array[Object]).returns(Object) }
    def call(vm, args)
      arg_count = args.length - 1
      if arg_count != @param_count
        raise ArgumentError, "#{@name}: got #{arg_count} arguments, expected #{@param_count}"
      end

      @func.call(vm, args)
    end

  end
end
