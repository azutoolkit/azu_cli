require "json"
require "../ui"
require "../scratch_file"
require "../process_tree"

module AzuCLI
  module DevServer
    # The Console panel of `azu dev`: Crystal code run with the application loaded, like `rails console`. Without an
    # interpreter each run compiles the snippet with the app (`crystal run`): an expression answers `=> value`, and a
    # declaration (`def`, `class`, ...) is kept and comes before every later snippet. Locals do not carry over between
    # runs; `crystal i` (Ctrl-O, when the compiler has it) is a live session.
    module Console
      MARKER = "AZU_CONSOLE_VALUE:"
      # Printed after the kept assignments ran again: what the snippet prints comes after it.
      START = "AZU_CONSOLE_START"
      # Longest `inspect` of a value shown.
      VALUE_LIMIT = 4000

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

      # The script, and the number of lines before the snippet (to give compile errors the snippet's line numbers).
      def self.script(app_file : String, prelude : Array(String), code : String, declaration : Bool, kept : Array(String) = [] of String) : {String, Int32}
        head = String.build do |io|
          io << "require " << app_file.inspect << '\n'
          prelude.each { |declared| io << declared << '\n' }
          kept.each { |assignment| io << assignment << '\n' }
          io << "puts " << START.inspect << '\n'

          io << "__azu_console_value = begin\n" unless declaration
        end
        tail = declaration ? "\nputs #{(MARKER + "declared").inspect}\n" : "\nend\nputs \"\\n#{MARKER}\#{__azu_console_value.inspect[0, #{VALUE_LIMIT}]}\"\n"
        {head + code + tail, head.count('\n')}
      end

      # How a run went: what it printed, its value (or "declared"), or why it failed.
      record Outcome, ok : Bool, printed : Array(String), value : String?, error : String?

      def self.outcome(exit_code : Int32, output : String, script_name : String, offset : Int32) : Outcome
        lines = output.lines.map(&.rstrip)
        lines = lines[(lines.index(START) || -1) + 1..]
        if exit_code == 0 && (index = lines.rindex(&.starts_with?(MARKER)))
          printed = lines[0, index]
          printed = printed[0, (printed.rindex { |line| !line.empty? } || -1) + 1]
          return Outcome.new(true, printed, lines[index].lchop(MARKER), nil)
        end
        if (crash = lines.index(&.starts_with?("Unhandled exception")))
          return Outcome.new(false, lines[0, crash].reject(&.empty?), nil, lines[crash].sub(/\AUnhandled exception: /, ""))
        end
        Outcome.new(false, [] of String, nil, compile_error(lines, script_name, offset))
      end

      # "line 2: undefined local variable or method 'foo'" for the snippet, "src/models/post.cr:12: ..." for the app.
      def self.compile_error(lines : Array(String), script_name : String, offset : Int32) : String
        message = lines.find(&.starts_with?("Error: ")).try(&.lchop("Error: ")) || lines.reject(&.blank?).last? || "failed"
        location = lines.reverse.find { |line| line.starts_with?("In ") }
        return message unless location && (match = location.match(/\AIn (\S+?):(\d+):\d+/))

        if File.basename(match[1]) == script_name
          line = match[2].to_i - offset
          line >= 1 ? "line #{line}: #{message}" : "in the kept code (forget drops it): #{message}"
        else
          "#{match[1].lchop("./")}:#{match[2]}: #{message}"
        end
      end

      # The file every snippet is written to. One name: the compiler keys its object cache on the main file's path, so
      # a run after the first reuses the app's object files (about half the time of a fresh build).
      SCRIPT = ".azu_console.cr"

      # Runs one snippet at a time with the app, in a fiber; `cancel` stops it.
      class Evaluator
        @process : Process?

        def initialize(@report : Proc(UI::Message, Nil), @app_file : String, @directory : String = Dir.current, @compiler : String = "crystal")
        end

        def running? : Bool
          !@process.nil?
        end

        def evaluate(id : Int32, code : String, prelude : Array(String), declaration : Bool, kept : Array(String) = [] of String) : Nil
          spawn do
            script, offset = Console.script(@app_file, prelude, code, declaration, kept)
            started = Time.instant
            output = IO::Memory.new
            path = File.join(@directory, SCRIPT)
            exit_code = begin
              File.write(path, script, perm: 0o600)
              process = Process.new(@compiler, ["run", "--no-debug", path], chdir: @directory, input: Process::Redirect::Close, output: output, error: output)
              @process = process
              process.wait.exit_code? || -1
            rescue ex : IO::Error | File::Error
              output << "Error: " << ex.message
              127
            ensure
              File.delete?(path)
            end
            @process = nil
            @report.call(Events::ConsoleFinished.new(id, exit_code, output.to_s, (Time.instant - started).total_seconds, SCRIPT, offset))
          end
        end

        def cancel : Nil
          @process.try { |process| ProcessTree.terminate(process) rescue nil }
        end
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

        def initialize(@id : Int32, @code : String, @declaration : Bool, @status : Status = Status::Running)
        end
      end
    end

    module Events
      struct ConsoleFinished < UI::Message
        getter id : Int32
        getter exit_code : Int32
        getter output : String
        getter seconds : Float64
        getter script_name : String
        getter offset : Int32

        def initialize(@id : Int32, @exit_code : Int32, @output : String, @seconds : Float64, @script_name : String, @offset : Int32)
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
