# typed: true
# frozen_string_literal: true

require 'sorbet-runtime'

# Contains the MiniRuby interpreter.
module MiniRuby
  class Error < StandardError; end

  class << self
    extend T::Sig

    # Tokenize the MiniRuby source string.
    # Carries out lexical analysis and returns
    # an array of tokens (words).
    sig do
      params(
        source: String,
      ).returns(T::Array[Token])
    end
    def lex(source)
      Lexer.lex(source)
    end

    # Parse the MiniRuby source.
    # Returns an AST (Abstract Syntax Tree) and a list of errors.
    sig do
      params(
        source: String,
      ).returns(Parser::Result)
    end
    def parse(source)
      Parser.parse(source)
    end

    # Compile the MiniRuby source.
    # Returns a chunk of compiled bytecode.
    sig do
      params(
        source: String,
      ).returns(BytecodeFunction)
    end
    def compile(source)
      Compiler.compile_source(source)
    end

    # Interpret the MiniRuby source with the Virtual Machine.
    # Returns the last computed value.
    sig do
      params(
        source: String,
        stdout: IO,
        stdin:  IO,
      ).returns(Object)
    end
    def interpret(source, stdout: $stdout, stdin: $stdin)
      VM.interpret(source, stdout:, stdin:)
    end
  end
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
