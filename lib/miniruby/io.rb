# typed: strong
# frozen_string_literal: true

module MiniRuby
  # Interface that represents builtin IO objects.
  module IO
    extend T::Sig
    extend T::Helpers

    interface!

    sig { abstract.params(v: Object).void }
    def puts(*v); end

    sig { abstract.params(v: Object).void }
    def print(*v); end

    sig { abstract.params(fmt: String, v: Object).void }
    def printf(fmt, *v); end
  end
end

class StringIO
  include MiniRuby::IO
end

class IO
  include MiniRuby::IO
end
