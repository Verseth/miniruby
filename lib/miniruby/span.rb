# typed: strong
# frozen_string_literal: true

module MiniRuby
  # A collection of two positions: start and end
  class Span
    extend T::Sig

    sig { returns(Position) }
    attr_reader :start

    sig { returns(Position) }
    attr_reader :end

    sig { params(start: Position, end_pos: Position).void }
    def initialize(start, end_pos)
      @start = start
      @end = end_pos
    end

    sig { params(other: Object).returns(T::Boolean) }
    def ==(other)
      return false unless other.is_a?(Span)

      @start == other.start && @end == other.end
    end

    sig { returns(String) }
    def inspect
      "S(#{@start.inspect}, #{@end.inspect})"
    end
  end
end
