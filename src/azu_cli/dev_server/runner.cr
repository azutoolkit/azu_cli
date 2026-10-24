module AzuCLI
  module DevServer
    # Builds the app. The compiler's output is streamed to the terminal as it is produced and kept, so a
    # failure can be summarised after it.
    class Builder
      getter command : String
      getter args : Array(String)

      def initialize(@command : String, @args : Array(String))
      end

      record Result, success : Bool, seconds : Float64, output : String

      def build(chdir : String = ".", sink : IO = STDERR) : Result
        output = IO::Memory.new
        both = IO::MultiWriter.new(sink, output)
        started = Time.instant
        status = Process.run(command, args, chdir: chdir, output: both, error: both)
        Result.new(status.success?, (Time.instant - started).total_seconds, output.to_s)
      rescue ex : IO::Error
        Result.new(false, 0.0, "could not run #{command}: #{ex.message}")
      end
    end

    # The running app. At most one process; `restart` waits for the old one to exit (it holds the port).
    class Child
      getter binary : String
      getter env : Hash(String, String)
      @process : Process?

      def initialize(@binary : String, @env : Hash(String, String), @args : Array(String) = [] of String, @chdir : String = ".", @grace : Time::Span = 5.seconds)
      end

      def pid : Int64?
        running? ? @process.try(&.pid) : nil
      end

      def running? : Bool
        !!@process.try(&.exists?)
      end

      # The exit code of an app that stopped by itself, once.
      def exited : Process::Status?
        process = @process
        return if process.nil? || process.exists?

        @process = nil
        process.wait
      end

      def start : Nil
        @process = Process.new(binary, @args, env: env, chdir: @chdir, input: Process::Redirect::Close, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
      end

      # SIGTERM, then SIGKILL when it has not exited within the grace time.
      def stop : Nil
        process = @process
        return unless process

        @process = nil
        return unless process.exists?

        process.terminate
        deadline = Time.instant + @grace
        while process.exists? && Time.instant < deadline
          sleep 50.milliseconds
        end
        process.signal(Signal::KILL) if process.exists?
        process.wait
      rescue RuntimeError | IO::Error
        # already gone
      end

      def restart : Nil
        stop
        start
      end
    end
  end
end
