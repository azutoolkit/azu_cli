require "../process_tree"

module AzuCLI
  module DevServer
    # Builds the app. The compiler's output is streamed to the terminal as it is produced and kept, so a
    # failure can be summarised after it.
    class Builder
      getter command : String
      getter args : Array(String)

      @process : Process?
      @cancelled = false
      @lock = Mutex.new

      def initialize(@command : String, @args : Array(String))
      end

      record Result, success : Bool, seconds : Float64, output : String, cancelled : Bool = false

      def build(chdir : String = ".", sink : IO = STDERR) : Result
        output = IO::Memory.new
        both = IO::MultiWriter.new(sink, output)
        started = Time.instant
        process = @lock.synchronize do
          return Result.new(false, 0.0, "", cancelled: true) if @cancelled

          @process = Process.new(command, args, chdir: chdir, output: both, error: both)
        end
        status = process.wait
        Result.new(status.success?, (Time.instant - started).total_seconds, output.to_s, cancelled: @cancelled)
      rescue ex : IO::Error
        Result.new(false, 0.0, "could not run #{command}: #{ex.message}")
      ensure
        @lock.synchronize { @process = nil }
      end

      # Stops a build in progress, and one that is only starting (the next `build` returns at once): SIGTERM to the
      # build and everything it started, since `shards build` runs the compiler as a child that would otherwise keep
      # compiling and holding the output.
      def cancel : Nil
        @lock.synchronize do
          @cancelled = true
          @process.try { |process| ProcessTree.terminate(process) }
        end
      end
    end

    # The running app. At most one process; `restart` waits for the old one to exit (it holds the port).
    class Child
      getter binary : String
      getter env : Hash(String, String)
      # When set, the app's stdout and stderr go through pipes to this (line, from stderr?) instead of the terminal.
      property on_output : Proc(String, Bool, Nil)?
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
        unless on_output = @on_output
          @process = Process.new(binary, @args, env: env, chdir: @chdir, input: Process::Redirect::Close, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
          return
        end

        process = Process.new(binary, @args, env: env, chdir: @chdir, input: Process::Redirect::Close, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
        @process = process
        {process.output, process.error}.each_with_index do |io, index|
          spawn do
            io.each_line { |line| on_output.call(line, index == 1) }
          rescue IO::Error
            # the app ended
          end
        end
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
