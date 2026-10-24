module AzuCLI
  # Reads `.env` files into the process environment so every command (and the programs it starts) sees the
  # project's variables. The same grammar and precedence as `Azu::Env` in the azu shard, which the CLI does not
  # depend on; `spec/azu_cli/dot_env_spec.cr` holds the shared cases.
  #
  # Precedence, highest first: the process environment (never overridden), `.env.local`, `.env.<CRYSTAL_ENV>`, `.env`.
  # Files are data: no interpolation, nothing is executed, and errors never print a value.
  #
  # Trust (best effort, NOT a sandbox): the CLI runs in whatever project you are in and then starts `crystal`,
  # `shards` and others with this environment, so a file may only set application settings:
  #
  # 1. A name on the denylist (`UNSAFE_NAME`: `LD_*`, `DYLD_*`, `PATH`, `SHELL`, `HOME`, the compiler and linker
  #    variables `CC`, `CXX`, `*FLAGS`, ..., `SHARDS_*`, `GIT_*`, `CRYSTAL_*` except `CRYSTAL_ENV`/`CRYSTAL_LOG_*`,
  #    `DOCKER_*`, `COMPOSE_*`, `SSH_*`, proxies, certificates, interpreter and editor variables, ...) is always skipped,
  #    even when `.env.example` lists it.
  # 2. Any other name is applied only if it looks like an application setting (`DATABASE_URL`, `PORT`, `*_SECRET`,
  #    `*_URL`, `AZU_*`, ...; see `APP_NAME`) or the project's `.env.example` lists it.
  #
  # A skipped name is reported on STDERR with the name only (never the value). Running the CLI in a checkout you do not
  # trust is still unsafe: `serve`, `test`, `db:*` and `generate` compile and run the project's own Crystal code.
  module DotEnv
    class ParseError < Exception
      getter origin : String
      getter line : Int32

      def initialize(@origin : String, @line : Int32, problem : String)
        super("#{@origin}:#{@line}: #{problem}")
      end
    end

    MAX_FILE_SIZE = 1_048_576
    UNSAFE_NAME   = /\A(?:
      LD_.*|DYLD_.*|SHARDS_.*|GIT_.*|CRYSTAL_(?!ENV\z|LOG_).*|DOCKER_.*|COMPOSE_.*|SSH_.*|PKG_CONFIG(?:_.*)?|PYTHON.*|PERL5.*|RUBY.*|XDG_.*
      |PATH|SHELL|IFS|BASH_ENV|ENV|HOME|TMPDIR|SHELLOPTS|PS4|PROMPT_COMMAND|CDPATH|GLOBIGNORE
      |CC|CXX|CPP|CFLAGS|CXXFLAGS|LDFLAGS|CPATH|C_INCLUDE_PATH|CPLUS_INCLUDE_PATH|LIBRARY_PATH
      |GLIBC_TUNABLES|GCONV_PATH|LOCPATH|NLSPATH|SSL_CERT_FILE|SSL_CERT_DIR
      |HTTP_PROXY|HTTPS_PROXY|ALL_PROXY|NO_PROXY|EDITOR|VISUAL|PAGER|BROWSER|NODE_OPTIONS
    )\z/ix
    # What an application setting looks like. Anything else must be listed in the project's `.env.example`.
    APP_NAME = /\A(?:DATABASE_URL|REDIS_URL|PORT|HOST|CRYSTAL_ENV|AZU_.*|APP_.*|SESSION_.*|CSRF_.*|JOOBQ_.*|SMTP_.*|MAIL_.*|.*_SECRET|.*_KEY|.*_TOKEN|.*_URL|.*_HOST|.*_PORT|.*_PASSWORD)\z/i

    # Where warnings about skipped names go; specs swap it.
    class_property warning_io : IO = STDERR

    def self.unsafe_name?(name : String) : Bool
      name.matches?(UNSAFE_NAME)
    end

    def self.app_name?(name : String) : Bool
      name.matches?(APP_NAME)
    end

    def self.parse(source : String, origin : String = "(string)") : Hash(String, String)
      Parser.new(source, origin).parse
    end

    # Loads one file; returns the names it set. A missing file is not an error.
    def self.load(path : String = ".env") : Array(String)
      return [] of String unless File.file?(path)

      apply(read(path), example_names(File.dirname(path)))
    end

    # Loads `.env`, `.env.<CRYSTAL_ENV>` and `.env.local` from `dir`.
    def self.load_all(dir : String = ".") : Array(String)
      base = read(File.join(dir, ".env"))
      local = read(File.join(dir, ".env.local"))
      env = (ENV["CRYSTAL_ENV"]?.presence || local["CRYSTAL_ENV"]? || base["CRYSTAL_ENV"]? || "development").strip.downcase
      merged = base
      merged = merged.merge(read(File.join(dir, ".env.#{env}"))) if env.matches?(/\A[a-z0-9_\-]+\z/)
      apply(merged.merge(local), example_names(dir))
    end

    # The names `.env.example` mentions (commented-out entries count: they document the setting).
    private def self.example_names(dir : String) : Set(String)
      path = File.join(dir, ".env.example")
      names = Set(String).new
      return names unless File.file?(path) && File.size(path) <= MAX_FILE_SIZE

      File.read(path).scan(/^\s*#?\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=/m) { |match| names << match[1] }
      names
    end

    private def self.read(path : String) : Hash(String, String)
      return {} of String => String unless File.file?(path)
      raise ParseError.new(path, 1, "file is larger than 1 MB") if File.size(path) > MAX_FILE_SIZE

      parse(File.read(path), path)
    end

    # A blank CRYSTAL_ENV counts as unset (as in Azu::Env), so the file that picked `.env.<env>` can set it.
    private def self.in_process?(name : String) : Bool
      name == "CRYSTAL_ENV" ? !ENV[name]?.presence.nil? : ENV.has_key?(name)
    end

    # Why a name may not be set from a file, or nil when it may.
    private def self.refusal(name : String, listed : Set(String)) : String?
      return "it changes how processes start (set it in your shell)" if unsafe_name?(name)
      return nil if app_name?(name) || listed.includes?(name)

      "it is not a known application setting (add it to .env.example to allow it)"
    end

    private def self.apply(vars : Hash(String, String), listed : Set(String)) : Array(String)
      applied = [] of String
      vars.each do |name, value|
        if reason = refusal(name, listed)
          warning_io.puts "warning: ignoring #{name} from a .env file: #{reason}"
          next
        end
        next if in_process?(name)

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
