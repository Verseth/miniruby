# typed: strong
# frozen_string_literal: true

module MiniRuby
  # A position of a single character in a piece of text
  class Position
    extend T::Sig

    #: Integer
    attr_reader :char_index

    #: (Integer char_index) -> void
    def initialize(char_index)
      @char_index = char_index
    end

    ZERO = Position.new(0)

    #: (Object other) -> bool
    def ==(other)
      return false unless other.is_a?(Position)

      @char_index == other.char_index
    end

    #: -> String
    def inspect
      "P(#{char_index.inspect})"
    end
  end
end
