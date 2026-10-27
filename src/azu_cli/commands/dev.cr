require "./base"
require "../dev_server/changes"
require "../dev_server/watcher"
require "../dev_server/runner"
require "../dev_server/telemetry"
require "../dev_server/hud"

module AzuCLI
  module Commands
    # Runs the app and keeps it current: rebuilds (non-release) when sources change and restarts the app.
    class Dev < Base
      OPTIONS             = ["port", "host", "env", "debounce", "interval", "ui"]
      DEFAULT_PORT        = AzuCLI::Config::Ports::DEV_SERVER
      DEFAULT_DEBOUNCE_MS = 300
      DEFAULT_INTERVAL_MS = 250

      alias Child = AzuCLI::DevServer::Child
      alias Events = AzuCLI::DevServer::Events

      # nil: leave it to the app's environment (the shell, the .env files, the app's default)
      getter port : Int32? = nil
      getter host : String? = nil
      getter environment : String? = nil
      getter debounce : Time::Span = DEFAULT_DEBOUNCE_MS.milliseconds
      getter interval : Time::Span = DEFAULT_INTERVAL_MS.milliseconds
      # rich (the dashboard) or plain (lines); nil: the dashboard on a terminal of at least 60x16, lines otherwise.
      getter ui_mode : String? = nil

      # How the app is built; replaced in specs.
      class_property builder : String -> AzuCLI::DevServer::Builder = ->(target : String) { AzuCLI::DevServer::Builder.new("shards", ["build", target]) }

      @child : Child?
      @builder : AzuCLI::DevServer::Builder?
      @stopping = false
      @lock = Mutex.new
      @hud : UI::Program?
      @rebuild_requested = false

      def initialize
        super("dev", "Run the app, rebuilding and restarting it when the code changes")
      end

      def execute : Result
        return show_help_result if has_option?("help")
        if failure = read_options
          return usage_error(failure)
        end
        return Result.error("shard.yml not found: run 'azu dev' in the root of an Azu project") unless File.exists?("shard.yml")

        target = Utils.binary_name
        attach_child(target)
        return run_dashboard(target) if dashboard?

        trap_termination
        announce(target)
        serve(target)
      end

      # The dashboard runs when a person is watching: a terminal on both ends, big enough, not CI, not --ui plain.
      def dashboard? : Bool
        mode = @ui_mode || ENV["AZU_UI"]?.presence
        return false if mode == "plain" || mode == "json"

        terminal = UI::Terminal.detect
        columns, rows = terminal.size
        wanted = mode == "rich" ? terminal.tty? : UI::Reporter.rich?(terminal)
        wanted && STDIN.tty? && terminal.interactive? && columns >= 60 && rows >= 16
      end

      private def run_dashboard(target : String) : Result
        terminal = UI::Terminal.detect
        telemetry = AzuCLI::DevServer::TelemetryServer.new
        screen = AzuCLI::DevServer::Hud.new(target, (@port || ENV["PORT"]? || DEFAULT_PORT).to_s, @environment || ENV["CRYSTAL_ENV"]? || "development",
          "watching src, config · poll #{@interval.total_milliseconds.to_i} ms", on_rebuild: -> { @rebuild_requested = true; nil }, branch: git_branch)
        program = UI::Program.new(screen, terminal, UI::FullScreenRenderer.new(terminal.output))
        @hud = program
        @child.try do |child|
          child.env["AZU_TELEMETRY_SOCKET"] = telemetry.path
          child.on_output = ->(line : String, error : Bool) { program.send(Events::LogLine.new(line, error)); nil }
        end
        telemetry.start { |data| program.send(Events::Telemetry.new(data)) }
        Process.on_terminate do |_reason|
          terminal.restore(full_screen: true)
          stop
          telemetry.stop
          exit 0
        end
        spawn serve(target)
        spawn sample_memory(program)
        sample_jobs(program)
        program.run
        stop
        telemetry.stop
        stdout.puts screen.summary
        success
      end

      private def sample_memory(program : UI::Program) : Nil
        until @stopping
          app = @child.try(&.pid).try { |pid| AzuCLI::DevServer::Memory.rss(pid) }
          program.send(Events::RssSample.new(app, AzuCLI::DevServer::Memory.rss(Process.pid.to_i64)))
          sleep 1.second
        end
      end

      private def sample_jobs(program : UI::Program) : Nil
        queues = AzuCLI::DevServer::JobsSampler.queues
        return if queues.empty?

        sampler = AzuCLI::DevServer::JobsSampler.new(queues)
        spawn do
          until @stopping
            program.send(sampler.sample)
            sleep 2.seconds
          end
        end
      end

      private def git_branch : String?
        output = IO::Memory.new
        status = Process.run("git", ["rev-parse", "--abbrev-ref", "HEAD"], output: output, error: Process::Redirect::Close)
        status.success? ? output.to_s.strip.presence : nil
      rescue IO::Error
        nil
      end

      private def emit(message : UI::Message) : Nil
        @hud.try(&.send(message))
      end

      private def dashboard_running? : Bool
        !@hud.nil?
      end

      # nil when the options are fine, else why not.
      def read_options : String?
        if option = unknown_option(OPTIONS)
          return "Unknown option #{option}. Run 'azu dev --help'"
        end

        if has_option?("port")
          port = positive("port", DEFAULT_PORT)
          return "--port must be a number between 1 and 65535" unless port && port <= 65535
          @port = port
        end

        debounce = positive("debounce", DEFAULT_DEBOUNCE_MS)
        interval = positive("interval", DEFAULT_INTERVAL_MS)
        return "--debounce must be a positive number of milliseconds" unless debounce
        return "--interval must be a positive number of milliseconds" unless interval
        @debounce = debounce.milliseconds
        @interval = interval.milliseconds
        if has_option?("ui")
          mode = get_option("ui")
          return "--ui must be rich or plain" unless {"rich", "plain"}.includes?(mode)
          @ui_mode = mode
        end
        @host = get_option("host") if has_option?("host")
        @environment = get_option("env") if has_option?("env")
        nil
      end

      private def positive(name : String, default : Int32) : Int32?
        return default unless has_option?(name)

        value = get_option(name).to_i?
        value && value > 0 ? value : nil
      end

      def attach_child(target : String) : Child
        @child = Child.new(File.join(Dir.current, "bin", target), child_env)
      end

      # The environment the flags add to the app's: they win over what the shell and the .env files
      # (loaded at startup) say; without a flag nothing is overridden.
      def child_env : Hash(String, String)
        env = {} of String => String
        @port.try { |port| env["PORT"] = port.to_s }
        @host.try { |host| env["HOST"] = host }
        @environment.try { |name| env["CRYSTAL_ENV"] = name }
        env
      end

      private def announce(target : String)
        Logger.info("azu dev: watching src/, config/, shard.yml and .env* (polling every #{@interval.total_milliseconds.to_i} ms)")
        Logger.info("Source and config changes: build #{target} (not a release build) and restart. Template changes (public/templates): no rebuild, the app reloads them itself when template hot reload is on (the default in development; TEMPLATE_HOT_RELOAD=false turns it off, then restart with Ctrl-C and 'azu dev'). Changes to .env files restart without a build.")
        Logger.info("App on port #{@port || ENV["PORT"]? || DEFAULT_PORT}. Ctrl-C stops.")
      end

      # Ends the child with the CLI: SIGINT and SIGTERM stop the app (it holds the port) and exit.
      private def trap_termination
        Process.on_terminate do |_reason|
          stop
          Logger.info("azu dev stopped")
          exit 0
        end
      end

      # Ends a build in progress and the app, and keeps a build that is finishing from starting a new app.
      def stop : Nil
        @stopping = true
        @builder.try(&.cancel)
        @lock.synchronize { @child.try(&.stop) }
      end

      private def serve(target : String) : Result
        watcher = AzuCLI::DevServer::Watcher.new(Dir.current)
        batcher = AzuCLI::DevServer::Batcher.new(@debounce)
        rebuild_and_restart(target, first: true)

        loop do
          sleep @interval
          break if @stopping
          if @rebuild_requested
            @rebuild_requested = false
            rebuild_and_restart(target)
          end
          report_exit
          batcher.add(watcher.poll, Time.instant)
          if plan = batcher.take(Time.instant)
            apply(plan, target)
          end
        end
        success
      end

      def apply(plan : AzuCLI::DevServer::Plan, target : String) : Nil
        if dashboard_running?
          emit(Events::Changed.new(plan.files, plan.action))
          case plan.action
          in .rebuild?             then rebuild_and_restart(target, plan.files)
          in .restart?             then restart
          in .templates?, .ignore? then nil
          end
          return
        end
        names = plan.files.first(3).join(", ") + (plan.files.size > 3 ? " and #{plan.files.size - 3} more" : "")
        case plan.action
        in .rebuild?   then Logger.info("Changed: #{names}"); rebuild_and_restart(target)
        in .restart?   then Logger.info("Changed: #{names}: restarting without a build"); restart
        in .templates? then Logger.info("Changed: #{names}: templates are not compiled, no rebuild; the running app reloads them when template hot reload is on")
        in .ignore?    then nil
        end
      end

      def rebuild_and_restart(target : String, files : Array(String) = [] of String, first : Bool = false) : Nil
        return if @stopping

        dashboard_running? ? emit(Events::BuildStarted.new(files)) : Logger.info("Building #{target}...")
        builder = self.class.builder.call(target)
        builder.args << "--progress" if dashboard_running? && builder.command == "shards"
        @builder = builder
        builder.cancel if @stopping # stop() ran between the check above and the line before
        sink = dashboard_running? ? AzuCLI::DevServer::LineSink.new { |line| emit(Events::BuildLine.new(line)) } : STDERR
        result = builder.build(sink: sink)
        @builder = nil
        if result.cancelled || @stopping
          nil # shutting down: neither a failure nor a restart
        elsif dashboard_running?
          emit(Events::BuildFinished.new(result.success, result.seconds, result.output))
          restart if result.success
        elsif result.success
          Logger.info("Built in #{result.seconds.round(1)}s")
          restart
        else
          Logger.error("Build failed after #{result.seconds.round(1)}s. #{keeping_message(first)}")
        end
      end

      private def keeping_message(first : Bool) : String
        pid = @child.try(&.pid)
        return "The app is not running; save a fix to build again." if first || pid.nil?

        "The previous build keeps running (pid #{pid}); save a fix to build again."
      end

      private def restart : Nil
        return if @stopping

        @lock.synchronize { @child.try(&.restart) unless @stopping }
        dashboard_running? ? emit(Events::AppStarted.new(@child.try(&.pid))) : Logger.info("App started (pid #{@child.try(&.pid)})")
      rescue ex : IO::Error
        dashboard_running? ? emit(Events::LogLine.new("Could not start the app: #{ex.message}", true)) : Logger.error("Could not start the app: #{ex.message}")
      end

      # "exited with code 1" or "was killed by SEGV" (a process that died from a signal has no exit code).
      def self.describe_exit(status : Process::Status) : String
        status.normal_exit? ? "exited with code #{status.exit_code}" : "was killed by #{status.exit_signal?}"
      end

      private def report_exit : Nil
        status = @child.try(&.exited)
        return unless status

        if dashboard_running?
          emit(Events::AppExited.new(self.class.describe_exit(status)))
        else
          Logger.error("The app #{self.class.describe_exit(status)}; save a change to build and start it again.")
        end
      end

      private def show_help_result : Result
        show_help
        success
      end

      def show_help
        stdout.puts <<-HELP
          Usage: azu dev [options]

          Builds the app (shards build, not a release build), runs it and watches for changes:

            src/**, config/**, shard.yml, shard.lock   build, then restart. A failed build keeps the previous app
                                                         running and prints the compiler's errors.
            public/templates/**                         no build, no restart: templates are read from disk and the
                                                         running app reloads them when template hot reload is on
                                                         (default in development).
            .env, .env.local, .env.<env>                restart without a build.

          Changes are collected until the files have been quiet for the debounce time. Files are polled
          (modification time and size); there is no file system event watcher. Ctrl-C or SIGTERM stops the
          app (and a build in progress) before the command exits. The app's output goes to the terminal as the app
          writes it. If the command itself is killed with SIGKILL nothing can stop the app: it keeps the port until you
          end it (its pid is printed when it starts).

          Options:
            --port PORT        PORT for the app (default: your environment or .env, else the app's 4000)
            --host HOST        HOST for the app (default: your environment or .env, else the app's)
            --env NAME         CRYSTAL_ENV for the app (default: your environment or .env, else development)
            --debounce MS      Quiet time before a change is acted on (default #{DEFAULT_DEBOUNCE_MS})
            --interval MS      Polling interval (default #{DEFAULT_INTERVAL_MS})
            --ui MODE          rich: the dashboard (the default on a terminal of at least 60x16), plain: lines
            --help             Show this help

          Exit codes: 0 stopped by Ctrl-C or SIGTERM, 1 not an Azu project, 2 invalid usage.
          'azu serve' is the older command that builds with --production and also watches templates.
        HELP
        stdout.puts
        stdout.puts "Examples:"
        show_examples
      end

      def show_examples
        stdout.puts "  azu dev"
        stdout.puts "  azu dev --port 3000"
        stdout.puts "  azu dev --debounce 800"
      end
    end
  end
end
