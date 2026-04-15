# typed: strong
# frozen_string_literal: true

module MiniRuby
  # The result of parsing a MiniRuby string/file.
  # Combines an AST (Abstract Syntax Tree) and a list of errors.
  class Parser::Result
    extend T::Sig

    #: AST::ProgramNode
    attr_reader :ast

    #: Array[String]
    attr_reader :errors

    #: (AST::ProgramNode ast, Array[String] errors) -> void
    def initialize(ast, errors)
      @ast = ast
      @errors = errors
    end

    #: -> bool
    def err?
      @errors.any?
    end

    #: -> String
    def inspect
      buff = String.new
      buff << "<#{self.class}>\n"
      if @errors.any?
        buff << "  !Errors!\n"
        @errors.each do |err|
          buff << "    - #{err}\n"
        end
        buff << "\n"
      end

      buff << "  AST:\n"
      buff << @ast.inspect(2)
    end
  end
end
