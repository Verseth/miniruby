# typed: strong
# frozen_string_literal: true

module MiniRuby
  # Contains details about a function call
  # like the name of the called function and the number of arguments.
  class CallInfo
    extend T::Sig

    #: Symbol
    attr_reader :name

    #: Integer
    attr_reader :arg_count

    #: (name: Symbol, arg_count: Integer) -> void
    def initialize(name:, arg_count:)
      @name = name
      @arg_count = arg_count
    end

    #: (Object other) -> bool
    def ==(other)
      return false unless other.is_a?(CallInfo)

      @name == other.name && @arg_count == other.arg_count
    end
  end
end
