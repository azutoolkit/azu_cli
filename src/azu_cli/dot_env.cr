module AzuCLI
  # Reads `.env` files into the process environment so every command (and the programs it starts) sees the
  # project's variables. The same grammar and precedence as `Azu::Env` in the azu shard, which the CLI does not
  # depend on; `spec/azu_cli/dot_env_spec.cr` holds the shared cases.
  #
  # Precedence, highest first: the process environment (never overridden), `.env.local`, `.env.<CRYSTAL_ENV>`, `.env`.
  # Files are data: no interpolation, nothing is executed, and errors never print a value.
  module DotEnv
    class ParseError < Exception
      getter origin : String
      getter line : Int32

      def initialize(@origin : String, @line : Int32, problem : String)
        super("#{@origin}:#{@line}: #{problem}")
      end
    end

    def self.parse(source : String, origin : String = "(string)") : Hash(String, String)
      Parser.new(source, origin).parse
    end

    # Loads one file; returns the names it set. A missing file is not an error.
    def self.load(path : String = ".env") : Array(String)
      return [] of String unless File.file?(path)

      apply(parse(File.read(path), path))
    end

    # Loads `.env`, `.env.<CRYSTAL_ENV>` and `.env.local` from `dir`.
    def self.load_all(dir : String = ".") : Array(String)
      base = read(File.join(dir, ".env"))
      local = read(File.join(dir, ".env.local"))
      env = (ENV["CRYSTAL_ENV"]?.presence || local["CRYSTAL_ENV"]? || base["CRYSTAL_ENV"]? || "development").strip.downcase
      merged = base
      merged = merged.merge(read(File.join(dir, ".env.#{env}"))) if env.matches?(/\A[a-z0-9_\-]+\z/)
      apply(merged.merge(local))
    end

    private def self.read(path : String) : Hash(String, String)
      File.file?(path) ? parse(File.read(path), path) : {} of String => String
    end

    private def self.apply(vars : Hash(String, String)) : Array(String)
      applied = [] of String
      vars.each do |name, value|
        next if ENV.has_key?(name)

        ENV[name] = value
        applied << name
      end
      applied
    end

    # Scans a `.env` text. One pass over the characters, so multi-line quoted values cost nothing extra.
    private class Parser
      def initialize(source : String, @origin : String)
        @chars = source.lchop('﻿').gsub("\r\n", "\n").chars
        @pos = 0
        @line = 1
      end

      def parse : Hash(String, String)
        vars = {} of String => String
        until eof?
          parse_line(vars)
        end
        vars
      end

      private def parse_line(vars : Hash(String, String)) : Nil
        skip_blanks
        case peek
        when nil
        when '\n' then advance
        when '#'  then skip_comment
        else
          name = read_name
          expect_equals
          vars[name] = read_value
        end
      end

      private def read_name : String
        skip_export
        start = @pos
        while (char = peek) && (char.ascii_alphanumeric? || char == '_')
          advance
        end
        name = @chars[start...@pos].join
        fail "invalid variable name" if name.empty? || name[0].ascii_number?
        name
      end

      # `export FOO=1`, but not a variable that is itself called export.
      private def skip_export : Nil
        return unless @chars[@pos, 6]? == ['e', 'x', 'p', 'o', 'r', 't'] && {' ', '\t'}.includes?(@chars[@pos + 6]?)

        @pos += 6
        skip_blanks
      end

      private def expect_equals : Nil
        skip_blanks
        fail "expected KEY=VALUE" unless peek == '='
        advance
        skip_blanks
      end

      private def read_value : String
        value = case peek
                when '"'  then read_double_quoted
                when '\'' then read_single_quoted
                else           return read_bare
                end
        finish_line
        value
      end

      private def read_bare : String
        start = @pos
        previous = ' '
        while (char = peek) && char != '\n'
          break if char == '#' && previous.whitespace?
          previous = char
          advance
        end
        text = @chars[start...@pos].join.rstrip
        skip_comment if peek == '#'
        reject_nul(text)
      end

      private def read_single_quoted : String
        opened = @line
        advance
        start = @pos
        until peek == '\''
          unterminated(opened) if eof?
          advance
        end
        text = @chars[start...@pos].join
        advance
        reject_nul(text)
      end

      private def read_double_quoted : String
        opened = @line
        advance
        text = String.build do |io|
          loop do
            unterminated(opened) unless char = peek
            advance
            break if char == '"'
            char == '\\' ? io << unescape : io << char
          end
        end
        reject_nul(text)
      end

      private def unescape : String
        unterminated(@line) unless char = peek
        advance
        case char
        when 'n'  then "\n"
        when 't'  then "\t"
        when 'r'  then "\r"
        when '"'  then "\""
        when '\\' then "\\"
        else           "\\#{char}"
        end
      end

      # After a quoted value only blanks and a comment may follow on the line.
      private def finish_line : Nil
        skip_blanks
        case peek
        when nil
        when '\n' then advance
        when '#'  then skip_comment
        else           fail "unexpected text after a quoted value"
        end
      end

      private def skip_blanks : Nil
        while (char = peek) && (char == ' ' || char == '\t' || char == '\r')
          advance
        end
      end

      private def skip_comment : Nil
        while (char = peek) && char != '\n'
          advance
        end
        advance if peek == '\n'
      end

      private def reject_nul(text : String) : String
        fail "a value contains a NUL byte" if text.includes?('\0')
        text
      end

      private def unterminated(line : Int32) : NoReturn
        raise ParseError.new(@origin, line, "unterminated quote")
      end

      private def fail(problem : String) : NoReturn
        raise ParseError.new(@origin, @line, problem)
      end

      private def peek : Char?
        @chars[@pos]?
      end

      private def eof? : Bool
        @pos >= @chars.size
      end

      private def advance : Nil
        @line += 1 if @chars[@pos]? == '\n'
        @pos += 1
      end
    end
  end
end
