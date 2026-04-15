# frozen_string_literal: true

require 'test_helper'
require 'byebug'

class TestMiniRuby < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::MiniRuby::VERSION
  end
end
