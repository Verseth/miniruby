# frozen_string_literal: true

require 'sorbet-runtime'

require_relative 'miniruby/version'
require_relative 'miniruby/position'
require_relative 'miniruby/span'
require_relative 'miniruby/token'
require_relative 'miniruby/lexer'
require_relative 'miniruby/ast'
require_relative 'miniruby/parser'

module MiniRuby
  class Error < StandardError; end
  # Your code goes here...
end
