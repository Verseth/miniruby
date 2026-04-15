# typed: strong
# frozen_string_literal: true

module MiniRuby
  # A collection of two positions: start and end
  class Span
    extend T::Sig

    #: Position
    attr_reader :start

    #: Position
    attr_reader :end

    #: (Position start, Position end_pos) -> void
    def initialize(start, end_pos)
      @start = start
      @end = end_pos
    end

    ZERO = Span.new(Position::ZERO, Position::ZERO)

    # Create a new span that includes the area of two spans.
    #: (Span other) -> Span
    def join(other)
      Span.new(@start, other.end)
    end

    #: (Object other) -> bool
    def ==(other)
      return false unless other.is_a?(Span)

      @start == other.start && @end == other.end
    end

    #: -> String
    def inspect
      "S(#{@start.inspect}, #{@end.inspect})"
    end
  end
end
