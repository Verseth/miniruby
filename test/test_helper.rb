# typed: true
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'miniruby'

require 'minitest/autorun'

class TestCase < Minitest::Test
  extend T::Sig

  sig { params(index: Integer).returns(MiniRuby::Position) }
  def P(index) # rubocop:disable Naming/MethodName
    MiniRuby::Position.new(index)
  end

  sig { params(start: MiniRuby::Position, end_pos: MiniRuby::Position).returns(MiniRuby::Span) }
  def S(start, end_pos) # rubocop:disable Naming/MethodName
    MiniRuby::Span.new(start, end_pos)
  end
end
