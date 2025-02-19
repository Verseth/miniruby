# MiniRuby

This library implements an interpreter for MiniRuby, a small subset of the Ruby language 💎.
It is implemented as a Ruby gem with sorbet.

It has been built for educational purposes, to serve as a simple example of how modern interpreters work.

## Installation

Install the gem and add to the application's Gemfile by executing:

```sh
bundle add miniruby
```

If bundler is not being used to manage dependencies, install the gem by executing:

```sh
gem install miniruby
```

## Usage

### Lexer

This library implements a streaming MiniRuby lexer.
You can use it by creating an instance of `MiniRuby::Lexer` passing in a string
with source code.

You can call the `next` method to receive the next token.
Once the lexing is complete a token of type `:end_of_file` gets returned.

```rb
require 'ruby_json_parser'

lexer = MiniRuby::Lexer.new(<<~RUBY)
  foo = 5
  foo * 3.2
RUBY
lexer.next #=> Token(:identifier, "foo")
lexer.next #=> Token(:equal)
lexer.next #=> Token(:integer, "5")
lexer.next #=> Token(:newline)
lexer.next #=> Token(:identifier, "foo")
lexer.next #=> Token(:star)
lexer.next #=> Token(:float, "3.2")
lexer.next #=> Token(:newline)
lexer.next #=> Token(:end_of_file)
```

There is a simplified API that lets you generate an array of all tokens.

```rb
require 'ruby_json_parser'

MiniRuby.lex(<<~RUBY)
  foo = 5
  foo * 3.2
RUBY
#=> [Token(:lbrace), Token(:string, "some"), Token(:colon), Token(:lbracket), Token(:string, "json"), Token(:comma), Token(:number, "2e-29"), Token(:comma), Token(:string, "text"), Token(:rbracket), Token(:rbrace)]
```

### Parser

This library implements a MiniRuby parser.
You can use it by calling `MiniRuby.parse` passing in a string
with source code.

It returns `MiniRuby::Parser::Result` which contains the produced AST (Abstract Syntax Tree) and the list of encountered errors.

```rb
require 'ruby_json_parser'

MiniRuby.parse(<<~RUBY)
  a = 0
  while a < 5
    a = a + 2
    puts(a)
  end

  a
RUBY
#=> <MiniRuby::Parser::Result>
#  AST:
#    (program
#      (expr_stmt
#        (assignment
#          a
#          0))
#      (expr_stmt
#        (while
#          (bin_expr
#            <
#            a
#            5)
#          (then
#            (expr_stmt
#              (assignment
#                a
#                (bin_expr
#                  +
#                  a
#                  2)))
#            (expr_stmt
#              (call
#                puts
#                a)))))
#      (expr_stmt
#        a))

result = MiniRuby.parse('if foo; puts("lol")')
#=> <MiniRuby::Parser::Result>
#  !Errors!
#    - unexpected END_OF_FILE, expected end
#
#  AST:
#    (program
#      (expr_stmt
#        (invalid Token(:end_of_file, S(P(0), P(0))))))

result.ast # get the AST
result.err? # check if there are any errors
result.errors # get the list of errors
```

All AST nodes are implemented as classes under the `MiniRuby::AST` module.
AST nodes have an `inspect` method that presents their structure in the [S-expression](https://en.wikipedia.org/wiki/S-expression) format.
You can also use `#to_s` to convert them to a Ruby-like human readable format.

```rb
result = MiniRuby.parse(<<~RUBY)
  a = 5
  if a > 2
    a = -1
  end

  puts(a)
RUBY
ast = result.ast

puts ast.inspect # S-expression format
# (program
#   (expr_stmt
#     (assignment
#       a
#       5))
#   (expr_stmt
#     (if
#       (bin_expr
#         >
#         a
#         2)
#       (then
#         (expr_stmt
#           (assignment
#             a
#             (unary_expr
#               -
#               1))))))
#   (expr_stmt
#     (call
#       puts
#       a)))

puts ast.to_s # Ruby-like format
# a = 5
# if a > 2
#   a = -1
# end
# puts(a)

ast.class #=> MiniRuby::AST::ProgramNode

ast.statements[0].expression.class #=> MiniRuby::AST::AssignmentExpressionNode
ast.statements[0].expression.value #=> MiniRuby::AST::IntegerLiteralNode("5")
```

### Bytecode Compiler

This library implements a MiniRuby bytecode compiler.
You can use it by calling `MiniRuby.compile` passing in a string
with source code.

It returns `MiniRuby::BytecodeFunction`, an executable chunk of bytecode.


```rb
require 'ruby_json_parser'

func = MiniRuby.compile(<<~RUBY)
  a = 0
  while a < 5
    a = a + 2
    puts(a)
  end

  a
RUBY
# == BytecodeFunction <main> at: <main> ==
# 0000  18 01    PREP_LOCALS       1
# 0002  0F 00    LOAD_VALUE        0 (0)
# 0004  1A 01    SET_LOCAL         1
# 0006  01       POP
# 0007  12       NIL
# 0008  19 01    GET_LOCAL         1
# 0010  0F 01    LOAD_VALUE        1 (5)
# 0012  0C       LESS
# 0013  16 10    JUMP_UNLESS       16
# 0015  01       POP
# 0016  19 01    GET_LOCAL         1
# 0018  0F 02    LOAD_VALUE        2 (2)
# 0020  04       ADD
# 0021  1A 01    SET_LOCAL         1
# 0023  01       POP
# 0024  1B       SELF
# 0025  19 01    GET_LOCAL         1
# 0027  17 03    CALL              3 (#<MiniRuby::CallInfo:0x0000000103651ef0 @name=:puts, @arg_count=1>)
# 0029  15 18    LOOP              24
# 0031  01       POP
# 0032  19 01    GET_LOCAL         1
# 0034  13       RETURN

func.class #=> MiniRuby::BytecodeFunction
```

You can also use the compiler directly to compile an already produced AST.

```rb
require 'ruby_json_parser'

parse_result = MiniRuby.parse(<<~RUBY)
  a = 0
  while a < 5
    a = a + 2
    puts(a)
  end

  a
RUBY

func = MiniRuby::Compiler.compile_ast(parse_result.ast)
# == BytecodeFunction <main> at: <main> ==
# 0000  18 01    PREP_LOCALS       1
# 0002  0F 00    LOAD_VALUE        0 (0)
# 0004  1A 01    SET_LOCAL         1
# 0006  01       POP
# 0007  12       NIL
# 0008  19 01    GET_LOCAL         1
# 0010  0F 01    LOAD_VALUE        1 (5)
# 0012  0C       LESS
# 0013  16 10    JUMP_UNLESS       16
# 0015  01       POP
# 0016  19 01    GET_LOCAL         1
# 0018  0F 02    LOAD_VALUE        2 (2)
# 0020  04       ADD
# 0021  1A 01    SET_LOCAL         1
# 0023  01       POP
# 0024  1B       SELF
# 0025  19 01    GET_LOCAL         1
# 0027  17 03    CALL              3 (#<MiniRuby::CallInfo:0x0000000103651ef0 @name=:puts, @arg_count=1>)
# 0029  15 18    LOOP              24
# 0031  01       POP
# 0032  19 01    GET_LOCAL         1
# 0034  13       RETURN

func.class #=> MiniRuby::BytecodeFunction
```

### VM

This library implements a MiniRuby Virtual Machine.
You can use it by calling `MiniRuby.interpret` passing in a string
with source code.

It returns the last computed value in the bytecode.


```rb
require 'ruby_json_parser'

result = MiniRuby.interpret(<<~RUBY)
  a = 0
  while a < 5
    a = a + 2
    puts(a)
  end

  a
RUBY
# 2
# 4
# 6

result == 6 #=> true
```

You can also use the VM directly to interpret an already produced piece of bytecode.

```rb
require 'ruby_json_parser'

func = MiniRuby::Compiler.compile_source(<<~RUBY)
  a = 0
  while a < 5
    a = a + 2
    puts(a)
  end

  a
RUBY

result = MiniRuby::VM.run(func)
# 2
# 4
# 6

result == 6 #=> true
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Verseth/miniruby.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
