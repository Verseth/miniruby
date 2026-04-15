# typed: strict
# frozen_string_literal: true

require_relative 'io'

module MiniRuby
  # A native function that is available in MiniRuby
  class NativeFunction
    extend T::Sig

    #: Symbol
    attr_reader :name

    #: Integer
    attr_reader :param_count

    Func = T.type_alias { T.proc.params(vm: VM, args: T::Array[Object]).returns(Object) }

    #: Func
    attr_reader :func

    #: (name: Symbol, ?param_count: Integer) { (?) -> untyped } -> void
    def initialize(name:, param_count: 0, &func)
      @name = name
      @func = func
      @param_count = param_count
    end

    #: (VM vm, Array[Object] args) -> Object
    def call(vm, args)
      arg_count = args.length - 1
      if arg_count != @param_count
        raise ArgumentError, "#{@name}: got #{arg_count} arguments, expected #{@param_count}"
      end

      @func.call(vm, args)
    end

  end
end
