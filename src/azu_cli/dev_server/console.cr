require "json"
require "../ui"
require "../scratch_file"
require "../process_tree"
require "./telemetry"

module AzuCLI
  module DevServer
    # The Console panel of `azu dev`: Crystal code run with the application loaded, like `rails console`. Each run
    # compiles the snippets with the app (`crystal run`): an expression answers `=> value`; a declaration (`def`,
    # `class`, ...) and a local assignment are kept for later snippets. Snippets typed while one compiles wait, and go
    # together into the next compile. `crystal i` (Ctrl-O) cannot load azu or CQL with Crystal 1.22.1.
    module Console
      MARKER = "AZU_CONSOLE_VALUE:"
      # A value is printed pretty (`pretty_inspect`) between these, so it can take several lines.
      VALUE     = "AZU_CONSOLE_PRETTY:"
      VALUE_END = "AZU_CONSOLE_PRETTY_END:"
      # Most lines of a value shown; the rest is counted.
      VALUE_LINES = 200
      # Printed after the kept assignments ran again: what the snippet prints comes after it.
      START = "AZU_CONSOLE_START"

      DECLARATION = /\A\s*(def|class|module|struct|enum|lib|macro|annotation|alias|require|include|extend|record|abstract\s+(class|struct|def)|private\s+def)\b/

      # Whether the snippet declares something (kept for later snippets) instead of computing a value.
      def self.declaration?(code : String) : Bool
        first = code.lines.find { |line| !line.blank? && !line.strip.starts_with?('#') } || ""
        first.matches?(DECLARATION)
      end

      ASSIGNMENT = /\A\s*[a-z_]\w*(\s*,\s*[a-z_]\w*)*\s*=(?![=~>])/
      WRITES     = /\.(create|save|update|update_all|delete|delete_all|destroy|destroy_all|insert|exec|clear|drop|truncate|migrate|upsert)\b|\w!(\(|\s|\z)|\.(send|deliver|enqueue|perform)\b/

      # A local assignment (`post = Post.first`): kept, and run again before each later snippet, so its locals carry
      # over the way they do in rails console.
      def self.assignment?(code : String) : Bool
        code.matches?(ASSIGNMENT)
      end

      # Whether running the snippet again would change something (a write, a `!` method): such an assignment is not kept.
      def self.writes?(code : String) : Bool
        code.matches?(WRITES)
      end

      # A snippet to run: its transcript id, its code, and whether it declares something.
      record Snippet, id : Int32, code : String, declaration : Bool

      # Where each snippet's code sits in the script (script lines, 1-based), to put compile errors on the snippet.
      alias Ranges = Array({Int32, Range(Int32, Int32)})

      # One script for a batch of snippets: the app, the declarations kept so far and the batch's own, the kept
      # assignments, then each expression in turn, each printing its own value. Locals of an earlier snippet in the
      # batch are visible to a later one, as they are at a prompt.
      def self.script(app_file : String, prelude : Array(String), kept : Array(String), snippets : Array(Snippet), width : Int32 = 80) : {String, Ranges}
        ranges = Ranges.new
        lines = ["require #{app_file.inspect}"]
        add = ->(code : String) { lines.concat(code.split('\n')) }
        prelude.each { |declared| add.call(declared) }
        snippets.select(&.declaration).each do |snippet|
          first = lines.size + 1
          add.call(snippet.code)
          ranges << {snippet.id, first..lines.size}
        end
        kept.each { |assignment| add.call(assignment) }
        lines << "puts #{START.inspect}"
        snippets.each do |snippet|
          if snippet.declaration
            lines << "puts #{"#{MARKER}#{snippet.id}:declared".inspect}"
            next
          end
          lines << "puts #{"#{BEGIN}#{snippet.id}".inspect}"
          lines << "__azu_console_value_#{snippet.id} = begin"
          first = lines.size + 1
          add.call(snippet.code)
          ranges << {snippet.id, first..lines.size}
          lines << "end"
          lines << "puts #{"\n#{VALUE}#{snippet.id}".inspect}"
          lines << "puts __azu_console_value_#{snippet.id}.pretty_inspect(#{Math.max(20, width)})"
          lines << "puts #{"#{VALUE_END}#{snippet.id}".inspect}"
        end
        {lines.join('\n') + "\n", ranges}
      end

      # How a snippet went: what it printed, its value (or "declared"), or why it failed.
      record Outcome, ok : Bool, printed : Array(String), value : String?, error : String?

      # Each snippet's outcome; nil for a snippet that did not get to run (another snippet of the batch failed to
      # compile, or crashed before it): it is run again with the next batch.
      def self.outcomes(exit_code : Int32, output : String, script_name : String, ranges : Ranges, ids : Array(Int32)) : Hash(Int32, Outcome?)
        lines = output.lines.map(&.rstrip)
        result = {} of Int32 => Outcome?
        unless start = lines.index(START)
          return compile_failure(lines, script_name, ranges, ids, exit_code)
        end

        current = nil
        printed = [] of String
        pretty_lines = nil
        lines[start + 1..].each do |line|
          if pretty = pretty_lines
            if line == "#{VALUE_END}#{current}"
              printed = printed[0, (printed.rindex { |text| !text.empty? } || -1) + 1]
              current.try { |done| result[done] = Outcome.new(true, printed, Console.clip(pretty), nil) }
              current = nil
              pretty_lines = nil
              printed = [] of String
            else
              pretty << line
            end
          elsif line.starts_with?(VALUE)
            pretty_lines = [] of String
          elsif line.starts_with?(BEGIN)
            current = line.lchop(BEGIN).to_i?
            printed = [] of String
          elsif line.starts_with?(MARKER)
            id, _, value = line.lchop(MARKER).partition(':')
            printed = printed[0, (printed.rindex { |text| !text.empty? } || -1) + 1]
            id.to_i?.try { |done| result[done] = Outcome.new(true, printed, value, nil) }
            current = nil
            printed = [] of String
          elsif line.starts_with?("Unhandled exception")
            current.try { |failed| result[failed] = Outcome.new(false, printed.reject(&.empty?), nil, line.sub(/\AUnhandled exception: /, "")) }
            break
          else
            printed << line
          end
        end
        ids.each do |id|
          next if result.has_key?(id)
          # Killed or exited mid-snippet: that one failed; the ones after it did not run
          result[id] = id == current ? Outcome.new(false, printed.reject(&.empty?), nil, exit_code == 0 ? "the program exited" : "stopped (exit #{exit_code})") : nil
        end
        result
      end

      # The value's lines, at most VALUE_LINES of them.
      def self.clip(lines : Array(String)) : String
        return lines.join('\n') if lines.size <= VALUE_LINES
        (lines.first(VALUE_LINES) + ["… #{lines.size - VALUE_LINES} more lines"]).join('\n')
      end

      # The tokens of an `inspect` line, for color: strings, numbers, nil/true/false, symbols, constants, @ivars.
      HIGHLIGHT = /(?<string>"(?:\\.|[^"\\])*")|(?<ivar>@[a-z_]\w*)|(?<symbol>:[a-z_]\w*[?!]?)|(?<constant>#?<?\b[A-Z]\w*(?:::[A-Z]\w*)*)|(?<number>\b\d{4}-\d\d-\d\d(?: \d\d:\d\d:\d\d(?:\.\d+)?(?: ?(?:Z|[+-]\d\d:?\d\d))?)?|-?\b\d[\d_]*(?:\.\d+)?(?:e[+-]?\d+)?(?:_?[iuf]\d+)?\b)|(?<keyword>\b(?:nil|true|false)\b)/

      enum Token
        Plain
        String
        Ivar
        Symbol
        Constant
        Number
        Keyword
      end

      # {text, kind} pieces of a line of a value.
      def self.tokens(line : String) : Array({String, Token})
        pieces = [] of {String, Token}
        position = 0
        line.scan(HIGHLIGHT) do |match|
          start = match.begin(0)
          pieces << {line[position...start], Token::Plain} if start > position
          kind = {"string" => Token::String, "ivar" => Token::Ivar, "symbol" => Token::Symbol, "constant" => Token::Constant,
                  "number" => Token::Number, "keyword" => Token::Keyword}.find { |(name, _)| match[name]? }.try(&.[1]) || Token::Plain
          pieces << {match[0], kind}
          position = match.end(0)
        end
        pieces << {line[position..], Token::Plain} if position < line.size
        pieces
      end

      private def self.compile_failure(lines : Array(String), script_name : String, ranges : Ranges, ids : Array(Int32), exit_code : Int32) : Hash(Int32, Outcome?)
        message = lines.find(&.starts_with?("Error: ")).try(&.lchop("Error: ")) || lines.reject(&.blank?).last? || "failed (exit #{exit_code})"
        location = lines.reverse.find(&.starts_with?("In ")).try(&.match(/\AIn (\S+?):(\d+):\d+/))
        culprit = nil
        error = message
        if location && File.basename(location[1]) == script_name
          line = location[2].to_i
          if found = ranges.find { |(_, range)| range.includes?(line) }
            culprit = found[0]
            error = "line #{line - found[1].begin + 1}: #{message}"
          else
            error = "in the kept code (forget drops it): #{message}"
          end
        elsif location
          error = "#{location[1].lchop("./")}:#{location[2]}: #{message}"
        end
        result = {} of Int32 => Outcome?
        # The snippet the error is in fails, the others run again; an error outside the snippets fails them all
        ids.each { |id| result[id] = culprit.nil? || culprit == id ? Outcome.new(false, [] of String, nil, error) : nil }
        result
      end

      # The file every snippet is written to. One name: the compiler keys its object cache on the main file's path, so
      # a run after the first reuses the app's object files (about half the time of a fresh build).
      SCRIPT = ".azu_console.cr"
      BEGIN  = "AZU_CONSOLE_BEGIN:"

      # Compiles and runs one batch at a time, in a fiber, and reports the compiler's progress; `cancel` stops it.
      class Evaluator
        @process : Process?

        # `on_busy` hears when a compile starts and ends (azu dev pauses its other compiles meanwhile).
        def initialize(@report : Proc(UI::Message, Nil), @app_file : String, @directory : String = Dir.current, @compiler : String = "crystal",
                       @on_busy : Proc(Bool, Nil) = ->(_busy : Bool) { })
        end

        def running? : Bool
          !@process.nil?
        end

        def evaluate(snippets : Array(Snippet), prelude : Array(String), kept : Array(String), width : Int32 = 80) : Nil
          script, ranges = Console.script(@app_file, prelude, kept, snippets, width)
          spawn do
            exit_code, output, seconds = compile_and_run(script)
            @report.call(Events::ConsoleFinished.new(snippets.map(&.id), exit_code, output, seconds, ranges))
          end
        end

        # Compiles the app once with an empty snippet, so the compiler's cache holds the app's objects before the
        # first snippet: that one then takes as long as any later one.
        def prewarm : Nil
          script, _ = Console.script(@app_file, [] of String, [] of String, [] of Snippet)
          spawn do
            exit_code, output, seconds = compile_and_run(script)
            @report.call(Events::ConsoleWarm.new(exit_code == 0, seconds, exit_code == 0 ? nil : Console.compile_error_line(output)))
          end
        end

        def cancel : Nil
          @process.try { |process| ProcessTree.terminate(process) rescue nil }
        end

        private def compile_and_run(script : String) : {Int32, String, Float64}
          @on_busy.call(true)
          started = Time.instant
          output = IO::Memory.new
          path = File.join(@directory, SCRIPT)
          sink = LineSink.new do |line|
            if progress = CompilerProgress.parse(line)
              @report.call(Events::ConsoleProgress.new(progress, (Time.instant - started).total_seconds))
            else
              output.puts(line)
            end
          end
          exit_code = begin
            File.write(path, script, perm: 0o600)
            process = Process.new(@compiler, ["run", "--no-debug", "--progress", path], chdir: @directory, input: Process::Redirect::Close, output: sink, error: sink)
            @process = process
            process.wait.exit_code? || -1
          rescue ex : IO::Error | File::Error
            output.puts "Error: #{ex.message}"
            127
          ensure
            File.delete?(path)
            @process = nil
            @on_busy.call(false)
          end
          sink.flush_line
          {exit_code, output.to_s, (Time.instant - started).total_seconds}
        end
      end

      # The error line of a failed warm-up ("src/models/post.cr:12: undefined method"), for the console's title.
      def self.compile_error_line(output : String) : String
        compile_failure(output.lines.map(&.rstrip), SCRIPT, Ranges.new, [0], 1)[0].try(&.error) || "failed"
      end

      # What was typed, kept between sessions in $XDG_STATE_HOME/azu/<project>/console_history (JSON lines).
      class History
        LIMIT = 500

        getter entries = [] of String

        def initialize(@path : String?)
          path = @path
          return unless path && File.exists?(path)
          File.each_line(path) { |line| (String.from_json(line) rescue nil).try { |code| entries << code } }
          @entries = entries.last(LIMIT)
        rescue IO::Error
        end

        def self.for_project(project : String = Dir.current) : History
          new(File.join(File.dirname(Undo.project_directory(project)), "console_history"))
        rescue File::Error
          new(nil)
        end

        def add(code : String) : Nil
          return if entries.last? == code
          entries << code
          @entries = entries.last(LIMIT)
          save
        end

        private def save : Nil
          path = @path || return
          Dir.mkdir_p(File.dirname(path), 0o700)
          File.write(path, entries.map(&.to_json).join('\n') + "\n", perm: 0o600)
        rescue IO::Error | File::Error
        end
      end

      # One snippet in the transcript.
      class Entry
        enum Status
          Queued
          Running
          Ok
          Fail
          Note
        end

        getter id : Int32
        getter code : String
        getter? declaration : Bool
        property status : Status
        property printed = [] of String
        property value : String?
        property error : String?
        property seconds : Float64?
        # Whether its locals carry over, for an assignment
        property kept : String?

        def initialize(@id : Int32, @code : String, @declaration : Bool, @status : Status = Status::Queued)
        end
      end
    end

    module Events
      # A batch of snippets ran (or failed to compile): their ids, and what the compiler and the program printed.
      struct ConsoleFinished < UI::Message
        getter ids : Array(Int32)
        getter exit_code : Int32
        getter output : String
        getter seconds : Float64
        getter ranges : Console::Ranges

        def initialize(@ids : Array(Int32), @exit_code : Int32, @output : String, @seconds : Float64, @ranges : Console::Ranges)
        end
      end

      # Where the compiler is with the running batch.
      struct ConsoleProgress < UI::Message
        getter progress : CompilerProgress
        getter seconds : Float64

        def initialize(@progress : CompilerProgress, @seconds : Float64)
        end
      end

      # The warm-up compile ended.
      struct ConsoleWarm < UI::Message
        getter ok : Bool
        getter seconds : Float64
        getter error : String?

        def initialize(@ok : Bool, @seconds : Float64, @error : String?)
        end
      end

      # Whether the compiler has `crystal i`, found out once in the background.
      struct InterpreterProbe < UI::Message
        getter available : Bool

        def initialize(@available : Bool)
        end
      end
    end
  end
end
