# typed: strong
# frozen_string_literal: true

module MiniRuby
  # Contains details about a function call
  # like the name of the called function and the number of arguments.
  class CallInfo
    extend T::Sig

    sig { returns Symbol }
    attr_reader :name

    sig { returns Integer }
    attr_reader :arg_count

    sig { params(name: Symbol, arg_count: Integer).void }
    def initialize(name:, arg_count:)
      @name = name
      @arg_count = arg_count
    end

    sig { params(other: Object).returns(T::Boolean) }
    def ==(other)
      return false unless other.is_a?(CallInfo)

      @name == other.name && @arg_count == other.arg_count
    end
  end
end
