require "./base"
require "file_utils"

module AzuCLI
  module Commands
    # Development server with hot reloading
    class Serve < Base
      property port : Int32 = 4000
      property host : String = "localhost"
      property environment : String = "development"
      property watch : Bool = true
      property verbose : Bool = false
      property reload_delay : Float64 = 0.5

      @server_process : Process?
      @last_reload : Time = Time.utc
      @watched_patterns : Array(String) = [
        "src/**/*.cr",
        "config/**/*.cr",
        "public/templates/**/*.jinja",
        "public/templates/**/*.html",
      ]

      def initialize
        super("serve", "Start development server with hot reloading")
      end

      def execute : Result
        parse_options

        Logger.info("🚀 Starting Azu development server...")
        Logger.info("Environment: #{@environment}")
        Logger.info("Server: http://#{@host}:#{@port}")
        Logger.info("Hot reloading: #{@watch ? "enabled" : "disabled"}")
        puts ""

        # Compile and start server initially
        unless compile_application
          return error("Initial compilation failed")
        end

        start_server

        if @watch
          Logger.info("👀 Watching for file changes...")
          Logger.info("Press Ctrl+C to stop the server")
          puts ""

          watch_files
        else
          wait_for_server
        end

        success("Server stopped")
      rescue ex
        Logger.info("\n🛑 Stopping development server...")
        stop_server
        error("Server error: #{ex.message}")
      end

      private def parse_options
        args = get_args
        args.each_with_index do |arg, index|
          case arg
          when "--port", "-p"
            @port = args[index + 1]?.try(&.to_i) || @port if index + 1 < args.size
          when "--host", "-h"
            @host = args[index + 1]? || @host if index + 1 < args.size
          when "--env", "-e"
            @environment = args[index + 1]? || @environment if index + 1 < args.size
          when "--no-watch"
            @watch = false
          when "--verbose", "-v"
            @verbose = true
          end
        end
      end

      private def compile_application : Bool
        Logger.info("📦 Compiling application...")

        output = IO::Memory.new
        error = IO::Memory.new

        start_time = Time.monotonic

        status = Process.run(
          "shards",
          ["build", "--production"],
          output: output,
          error: error
        )

        duration = (Time.monotonic - start_time).total_seconds

        if status.success?
          Logger.info("✅ Compilation successful! (#{duration.round(2)}s)")
          true
        else
          Logger.error("❌ Compilation failed!")
          puts ""
          puts "=" * 60
          puts "COMPILATION ERROR DETAILS:"
          puts "=" * 60
          puts error.to_s
          puts "=" * 60
          puts ""
          false
        end
      rescue ex
        Logger.error("❌ Compilation error: #{ex.message}")
        puts ""
        puts "=" * 60
        puts "COMPILATION EXCEPTION DETAILS:"
        puts "=" * 60
        puts ex.message
        if ex.backtrace?
          puts ""
          puts "Backtrace:"
          puts ex.backtrace.join("\n")
        end
        puts "=" * 60
        puts ""
        false
      end

      private def start_server
        stop_server if @server_process

        env = {
          "PORT"        => @port.to_s,
          "HOST"        => @host,
          "CRYSTAL_ENV" => @environment,
          "AZU_ENV"     => @environment,
        }

        binary_name = get_binary_name
        @server_process = Process.new(
          "./bin/#{binary_name}",
          env: env,
          output: @verbose ? Process::Redirect::Inherit : Process::Redirect::Pipe,
          error: @verbose ? Process::Redirect::Inherit : Process::Redirect::Pipe
        )

        # Give server a moment to start
        sleep 0.5.seconds

        if process = @server_process
          if process.exists?
            Logger.info("🌐 Server started (PID: #{process.pid})")
          else
            Logger.error("Server process failed to start")
          end
        end
      rescue ex
        Logger.error("Failed to start server: #{ex.message}")
      end

      private def stop_server
        if process = @server_process
          if process.exists?
            Logger.info("🛑 Stopping server (PID: #{process.pid})...")
            process.terminate
            sleep 0.5.seconds
            process.signal(Signal::KILL) if process.exists?
            process.wait rescue nil
          end
          @server_process = nil
        end
      end

      private def restart_server
        Logger.info("🔄 Restarting server...")
        stop_server
        start_server
      end

      private def watch_files
        # Simple file watching using polling
        # In production, you might want to use inotify or similar

        file_mtimes = {} of String => Time

        # Initial scan
        scan_files(file_mtimes)

        loop do
          begin
            sleep 0.5.seconds

            changed_files = detect_changes(file_mtimes)

            unless changed_files.empty?
              # Debounce: don't reload too frequently
              time_since_last = Time.utc - @last_reload
              if time_since_last.total_seconds < @reload_delay
                next
              end

              Logger.info("📝 File changed: #{changed_files.first}")
              changed_files[1..-1].each do |file|
                Logger.info("           and: #{file}") if @verbose
              end

              if compile_application
                restart_server
                @last_reload = Time.utc
              else
                Logger.warn("⚠️  Keeping previous version running due to compilation errors")
              end

              puts ""
            end
          rescue ex
            Logger.error("❌ File watcher error: #{ex.message}")
            if @verbose
              puts ""
              puts "=" * 60
              puts "FILE WATCHER ERROR DETAILS:"
              puts "=" * 60
              puts ex.message
              if ex.backtrace?
                puts ""
                puts "Backtrace:"
                puts ex.backtrace.join("\n")
              end
              puts "=" * 60
              puts ""
            end
            sleep 1.second
          end
        end
      end

      private def scan_files(mtimes : Hash(String, Time))
        @watched_patterns.each do |pattern|
          Dir.glob(pattern).each do |file|
            next unless File.file?(file)
            mtimes[file] = File.info(file).modification_time
          end
        end
      rescue ex
        Logger.warn("Error scanning files: #{ex.message}") if @verbose
      end

      private def detect_changes(mtimes : Hash(String, Time)) : Array(String)
        changed = [] of String

        @watched_patterns.each do |pattern|
          Dir.glob(pattern).each do |file|
            next unless File.file?(file)

            current_mtime = File.info(file).modification_time

            if !mtimes.has_key?(file) || mtimes[file] != current_mtime
              changed << file
              mtimes[file] = current_mtime
            end
          end
        end

        # Check for deleted files
        mtimes.keys.each do |file|
          unless File.exists?(file)
            changed << file
            mtimes.delete(file)
          end
        end

        changed
      rescue ex
        Logger.warn("Error detecting changes: #{ex.message}") if @verbose
        [] of String
      end

      private def wait_for_server
        if process = @server_process
          process.wait
        end
      end

      private def get_binary_name : String
        return "server" unless File.exists?("./shard.yml")

        begin
          shard_yml = YAML.parse(File.read("./shard.yml"))
          targets = shard_yml["targets"]?

          if targets && targets.is_a?(YAML::Any)
            # Get the first (and typically only) target name
            first_key = targets.as_h.keys.first?
            first_key ? first_key.as_s : "server"
          else
            "server"
          end
        rescue
          "server"
        end
      end
    end
  end
end
