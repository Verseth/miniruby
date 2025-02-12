# typed: strong
# frozen_string_literal: true

module MiniRuby
  # A position of a single character in a piece of text
  class Position
    extend T::Sig

    sig { returns(Integer) }
    attr_reader :char_index

    sig { params(char_index: Integer).void }
    def initialize(char_index)
      @char_index = char_index
    end

    sig { params(other: Object).returns(T::Boolean) }
    def ==(other)
      return false unless other.is_a?(Position)

      @char_index == other.char_index
    end

    sig { returns(String) }
    def inspect
      "P(#{char_index.inspect})"
    end
  end
end
