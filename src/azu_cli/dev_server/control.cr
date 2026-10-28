require "../ui"

module AzuCLI
  module DevServer
    # The `azu dev` control plane: the CLI's own commands, run by the dashboard as subprocesses of this binary with
    # plain output, when what they look at changes (a build, a migration, the configuration) or on a key.
    module Control
      # When a command runs by itself.
      @[Flags]
      enum Trigger
        Start      # when the dashboard opens
        Build      # after each successful build
        Migrations # when src/db/migrations changes
        Config     # when .env*, shard.yml or the CLI configuration changes
      end

      enum Status
        Idle
        Queued
        Running
        Ok
        Warn
        Fail

        def busy? : Bool
          queued? || running?
        end
      end

      # A command of the control plane. `confirm` commands change something (the database, the job queues, the session
      # store) and run only after `y`; `check` commands only read, and `a` runs them all.
      record Command, id : String, group : String, args : Array(String), triggers : Trigger = Trigger::None, confirm : Bool = false, check : Bool = false do
        def line : String
          "azu #{args.join(" ")}"
        end

        # What a `confirm` command changes, for its prompt.
        def effect : String
          case id
          when .starts_with?("db:")      then "the database"
          when .starts_with?("jobs:")    then "the job queues"
          when .starts_with?("session:") then "the session store"
          else                                "the project"
          end
        end
      end

      # The registered commands the panel leaves out (aliases aside): they need names, files or choices typed with
      # them, or they keep running or own the terminal.
      LEFT_OUT = {"new", "init", "help", "generate", "undo", "session:setup", "openapi:generate",
                  "serve", "dev", "console", "jobs:worker", "jobs:ui"}

      # Every other command: they run to an end without a terminal. Commands that would ask "are you sure?" get
      # --force: `y` here is that answer. The jobs commands are listed in JoobQ projects (config/jobs.yml).
      def self.catalog(shell : String = Control.shell, jobs : Bool = File.exists?("config/jobs.yml")) : Array(Command)
        commands = [
          Command.new("doctor", "Health", ["doctor"], Trigger::Start | Trigger::Config, check: true),
          Command.new("routes", "App", ["routes"], Trigger::Build, check: true),
          Command.new("config", "App", ["config"], Trigger::Build | Trigger::Config, check: true),
          Command.new("test", "App", ["test"]),
          Command.new("openapi:export", "App", ["openapi:export"]),
          Command.new("db:status", "Database", ["db:status"], Trigger::Start | Trigger::Migrations, check: true),
          Command.new("db:validate", "Database", ["db:validate"], check: true),
          Command.new("db:migrations:verify", "Database", ["db:migrations:verify", "--no-rollback"], check: true),
          Command.new("db:migrate", "Database", ["db:migrate"], confirm: true),
          Command.new("db:rollback", "Database", ["db:rollback", "--force"], confirm: true),
          Command.new("db:seed", "Database", ["db:seed"], confirm: true),
          Command.new("db:data:migrate", "Database", ["db:data:migrate"], confirm: true),
          Command.new("db:create", "Database", ["db:create"], confirm: true),
          Command.new("db:setup", "Database", ["db:setup"], confirm: true),
          Command.new("db:schema:load", "Database", ["db:schema:load"], confirm: true),
          Command.new("db:reset", "Database", ["db:reset", "--force"], confirm: true),
          Command.new("db:drop", "Database", ["db:drop", "--force"], confirm: true),
        ]
        if jobs
          commands << Command.new("jobs:status", "Jobs", ["jobs:status"], check: true)
          commands << Command.new("jobs:retry", "Jobs", ["jobs:retry", "--all"], confirm: true)
          commands << Command.new("jobs:clear", "Jobs", ["jobs:clear", "--failed", "--force"], confirm: true)
        end
        commands + [
          Command.new("session:clear", "Sessions", ["session:clear", "--force"], confirm: true),
          Command.new("version", "Other", ["version"], Trigger::Start, check: true),
          Command.new("completion", "Other", ["completion", shell]),
        ]
      end

      # The shell to print a completion script for: the login shell when it is one the CLI knows, else bash.
      def self.shell(env = ENV) : String
        name = File.basename(env["SHELL"]? || "bash")
        {"bash", "zsh", "fish"}.includes?(name) ? name : "bash"
      end

      # How a run went, from its exit code and output: a status and one line for the list.
      def self.outcome(id : String, exit_code : Int32, output : String) : {Status, String}
        lines = output.lines.map { |line| clean(line).strip }.reject(&.empty?)
        last = lines.last? || ""
        failed = exit_code != 0
        case id
        when "doctor"
          if match = output.match(/(\d+) ok, (\d+) warnings, (\d+) failures/)
            ok, warns, fails = match[1], match[2].to_i, match[3].to_i
            status = fails > 0 ? Status::Fail : (warns > 0 ? Status::Warn : Status::Ok)
            return {status, "#{ok} ok · #{warns} warn · #{fails} fail"}
          end
        when "routes"
          return {Status::Ok, last} if !failed && last.matches?(/\A\d+ routes?\z|\ANo routes match/)
        when "db:status"
          if match = output.match(/Total: (\d+) migrations \((\d+) applied, (\d+) pending\)/)
            pending = match[3].to_i
            return {pending > 0 ? Status::Warn : Status::Ok, "#{match[2]} applied · #{pending} pending"}
          end
          return {Status::Ok, "no migrations yet"} if !failed && output.includes?("No migrations")
        when "test"
          if match = output.match(/(\d+) examples?, (\d+) failures?, (\d+) errors?(?:, (\d+) pending)?/)
            bad = match[2].to_i + match[3].to_i
            return {bad > 0 || failed ? Status::Fail : Status::Ok, "#{match[1]} examples · #{bad} failed#{match[4]?.try { |pending| " · #{pending} pending" }}"}
          end
        when "version"
          return {Status::Ok, lines.first? || "?"} unless failed
        when "completion"
          return {Status::Ok, "#{lines.size}-line script"} unless failed
        when "config"
          # `azu config` prints a section heading, then "  key  value" lines
          unless failed
            settings = output.lines.count(&.matches?(/\A  \S+\s{2,}\S/))
            unset = output.lines.count(&.matches?(/\A  \S+\s{2,}not set\s*\z/))
            return {Status::Ok, "#{settings} settings#{unset > 0 ? " · #{unset} not set" : ""}"}
          end
        end
        failed ? {Status::Fail, Control.reason(lines)} : {Status::Ok, last.empty? ? "done" : last}
      end

      # The line that says why a run failed: the first error line, else the last line.
      def self.reason(lines : Array(String)) : String
        lines.find { |line| line.matches?(/\A(ERROR|FATAL|Error)\b|error:/i) }.try(&.sub(/\A(ERROR|FATAL): /, "")) || lines.last? || "failed"
      end

      ANSI = /\e\[[0-9;?]*[A-Za-z]/
      # The prefixes the CLI's plain log lines carry: `[19:08:51] [INFO ] `, `SUCCESS: `, `WARNING: `.
      LOG_PREFIX = /\A\[\d\d:\d\d:\d\d\] \[\w+\s*\] |\A(SUCCESS|TITLE): /

      def self.clean(line : String) : String
        line.gsub(ANSI, "").sub(LOG_PREFIX, "")
      end

      # A finished run.
      record Run, status : Status, summary : String, output : Array(String), seconds : Float64, at : Time::Instant

      # Runs the commands one at a time, in a fiber, and reports through `report` (on the dashboard's channel). A
      # command already queued or running is not queued twice; nothing starts while the app builds.
      class Runner
        getter queue = Deque(Command).new
        property? building = false
        # The console is compiling: it goes first, the next command waits
        property? paused = false
        @running : Command?
        @wake = ::Channel(Nil).new(1)
        @stopped = false

        def initialize(@report : Proc(UI::Message, Nil), @executable : String = Process.executable_path || "azu", @directory : String = Dir.current)
        end

        def enqueue(command : Command) : Bool
          return false if queue.any? { |queued| queued.id == command.id } || @running.try(&.id) == command.id

          queue << command
          @report.call(Events::ControlQueued.new(command.id))
          wake
          true
        end

        def start : Nil
          spawn do
            until @stopped
              @wake.receive if queue.empty?
              while (building? || paused?) && !@stopped
                sleep 200.milliseconds
              end
              command = queue.shift?
              run(command) if command && !@stopped
            end
          end
        end

        def stop : Nil
          @stopped = true
          wake
        end

        # Wakes the runner fiber without ever blocking the caller (the dashboard's own fiber): a wake already pending
        # is enough.
        private def wake : Nil
          select
          when @wake.send(nil)
          else
          end
        end

        private def run(command : Command) : Nil
          @running = command
          @report.call(Events::ControlStarted.new(command.id))
          started = Time.instant
          output = IO::Memory.new
          env = {"AZU_UI" => "plain", "NO_COLOR" => "1", "AZU_CONTROL" => "1"}
          code = begin
            Process.run(@executable, command.args, env: env, chdir: @directory, input: Process::Redirect::Close, output: output, error: output).exit_code? || -1
          rescue ex : IO::Error
            output << ex.message
            127
          end
          text = output.to_s.lines.map { |line| Control.clean(line) }.join('\n')
          @report.call(Events::ControlFinished.new(command.id, code, text, (Time.instant - started).total_seconds))
        ensure
          @running = nil
        end
      end
    end

    module Events
      struct ControlQueued < UI::Message
        getter id : String

        def initialize(@id : String)
        end
      end

      struct ControlStarted < UI::Message
        getter id : String

        def initialize(@id : String)
        end
      end

      struct ControlFinished < UI::Message
        getter id : String
        getter exit_code : Int32
        getter output : String
        getter seconds : Float64

        def initialize(@id : String, @exit_code : Int32, @output : String, @seconds : Float64)
        end
      end
    end
  end
end
