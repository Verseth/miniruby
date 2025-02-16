# typed: strong
# frozen_string_literal: true

module MiniRuby
  # The result of parsing a MiniRuby string/file.
  # Combines an AST (Abstract Syntax Tree) and a list of errors.
  class Parser::Result
    extend T::Sig

    sig { returns(AST::ProgramNode) }
    attr_reader :ast

    sig { returns(T::Array[String]) }
    attr_reader :errors

    sig { params(ast: AST::ProgramNode, errors: T::Array[String]).void }
    def initialize(ast, errors)
      @ast = ast
      @errors = errors
    end

    sig { returns(T::Boolean) }
    def err?
      @errors.any?
    end

    sig { returns(String) }
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
