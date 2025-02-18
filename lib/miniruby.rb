# frozen_string_literal: true

require 'sorbet-runtime'

module MiniRuby
  class Error < StandardError; end
end

require_relative 'miniruby/version'
require_relative 'miniruby/position'
require_relative 'miniruby/span'
require_relative 'miniruby/token'
require_relative 'miniruby/lexer'
require_relative 'miniruby/ast'
require_relative 'miniruby/parser'
# require_relative 'miniruby/opcode'
# require_relative 'miniruby/bytecode_function'
# require_relative 'miniruby/compiler'
# require_relative 'miniruby/vm'
