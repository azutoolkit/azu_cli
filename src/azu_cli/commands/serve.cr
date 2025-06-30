require "../command"
require "file_utils"
require "process"
require "json"
require "log"

module AzuCLI::Commands
  # Serve command - starts development server with hot reloading
  class Serve < Command
    command_name "serve"
    description "Start development server with hot reloading"
    usage "serve [options]"

    @server_process : Process?
    @watchers = [] of FileWatcher
    @running = false
    @rebuild_in_progress = false

    def execute(args : Hash(String, String | Array(String))) : String | Nil
      require_project_root!

      # Parse command line arguments
      host = get_flag(args, "host", config.dev_server_host)
      port = get_flag(args, "port", config.dev_server_port.to_s).to_i
      no_watch = has_flag?(args, "no-watch")
      verbose = has_flag?(args, "verbose") || config.verbose

      log.info("🚀 Starting Azu development server...")
      log.info("   Project: #{get_project_name}")
      log.info("   Environment: #{config.environment}")
      log.info("   Server: http://#{host}:#{port}")
      log.info("   File Watching: #{no_watch ? "disabled" : "enabled"}")

      # Initialize and start the development server
      start_development_server(host, port, !no_watch, verbose)

      nil
    end

    private def start_development_server(host : String, port : Int32, watch : Bool, verbose : Bool)
      # Set up signal handling for graceful shutdown
      setup_signal_handlers

      @running = true

      begin
        # Start file watchers if watching is enabled
        if watch
          start_file_watchers(verbose)
        end

        # Initial build
        if build_project(initial: true)
          log.success("✅ Initial build completed successfully")
        else
          log.error("❌ Initial build failed")
          cleanup_and_exit(1)
        end

        # Start the application server
        start_application_server(host, port, verbose)

        # Keep the process running and handle file changes
        if watch
          log.info("👀 Watching for file changes...")
          log.info("   Press Ctrl+C to stop the server")
          monitor_file_changes
        else
          wait_for_server_process
        end
      rescue ex : Exception
        log.error("Server startup failed: #{ex.message}")
        cleanup_and_exit(1)
      ensure
        cleanup
      end
    end

    private def setup_signal_handlers
      Signal::INT.trap do
        log.info("🛑 Shutting down development server...")
        cleanup_and_exit(0)
      end

      Signal::TERM.trap do
        log.info("🛑 Terminating development server...")
        cleanup_and_exit(0)
      end
    end

    private def start_file_watchers(verbose : Bool)
      watch_paths = [
        "src/**/*.cr",
        "config/**/*.cr",
        "public/templates/**/*.jinja",
        "public/templates/**/*.html",
        "public/assets/**/*.css",
        "public/assets/**/*.js",
      ]

      watch_paths.each do |pattern|
        watcher = FileWatcher.new(pattern, verbose)
        watcher.on_change do |file_path|
          handle_file_change(file_path, verbose)
        end
        @watchers << watcher
        watcher.start
      end

      log.info("📁 Watching #{watch_paths.size} file patterns for changes")
    end

    private def handle_file_change(file_path : String, verbose : Bool)
      return if @rebuild_in_progress

      log.info("📝 File changed: #{file_path}")

      file_type = determine_file_type(file_path)

      case file_type
      when :crystal
        handle_crystal_file_change(file_path, verbose)
      when :template
        handle_template_file_change(file_path, verbose)
      when :static
        handle_static_file_change(file_path, verbose)
      else
        log.debug("Ignoring change to #{file_path}") if verbose
      end
    end

    private def determine_file_type(file_path : String) : Symbol
      case File.extname(file_path)
      when ".cr"
        :crystal
      when ".jinja", ".html", ".ecr"
        :template
      when ".css", ".js", ".scss", ".sass", ".ts"
        :static
      else
        :unknown
      end
    end

    private def handle_crystal_file_change(file_path : String, verbose : Bool)
      @rebuild_in_progress = true

      spawn do
        begin
          log.info("🔄 Rebuilding application...")

          if build_project
            log.success("✅ Rebuild successful")
            restart_application_server(verbose)
          else
            log.error("❌ Rebuild failed")
            log.info("   Fix the errors and save again to retry")
          end
        ensure
          @rebuild_in_progress = false
        end
      end
    end

    private def handle_template_file_change(file_path : String, verbose : Bool)
      log.info("🎨 Template updated: #{file_path}")
      log.info("   Refresh your browser to see changes")
    end

    private def handle_static_file_change(file_path : String, verbose : Bool)
      log.info("💄 Static file updated: #{file_path}")
      log.info("   Refresh your browser to see changes")
    end

    private def build_project(initial : Bool = false) : Bool
      log.info("🔨 #{initial ? "Building" : "Rebuilding"} project...")

      output = IO::Memory.new
      error = IO::Memory.new

      build_result = Process.run(
        "crystal", ["build", "src/#{get_project_name}.cr", "-o", "bin/#{get_project_name}"],
        error: error,
        output: output
      )

      if build_result.success?
        log.debug("Build output: #{output.to_s}") if config.debug_mode
        true
      else
        log.error("Build failed:")
        error.to_s.each_line do |line|
          log.error("  #{line}")
        end
        false
      end
    end

    private def start_application_server(host : String, port : Int32, verbose : Bool)
      project_name = get_project_name
      binary_path = "bin/#{project_name}"

      unless File.exists?(binary_path)
        log.error("Application binary not found: #{binary_path}")
        return
      end

      env = {
        "HOST"    => host,
        "PORT"    => port.to_s,
        "AZU_ENV" => config.environment,
      }

      @server_process = Process.new(
        binary_path,
        env: env,
        error: Process::Redirect::Pipe,
        output: Process::Redirect::Pipe
      )

      # Monitor server output
      spawn do
        if process = @server_process
          process.output.each_line do |line|
            puts line
          end
        end
      end

      spawn do
        if process = @server_process
          process.error.each_line do |line|
            log.error(line)
          end
        end
      end

      # Wait a moment for server to start
      sleep 1.second

      if @server_process.try(&.exists?)
        log.success("🌐 Application server started at http://#{host}:#{port}")
        show_development_info(host, port)
      else
        log.error("Failed to start application server")
      end
    end

    private def restart_application_server(verbose : Bool)
      if process = @server_process
        log.info("🔄 Restarting application server...")

        # Stop the current process
        process.signal(Signal::TERM)
        process.wait rescue nil

        # Start a new one with the same configuration
        # For now, we'll just notify the user to restart manually
        log.info("♻️  Please restart the server manually with 'azu serve'")
        log.info("   Or implement automatic restart in a future version")
      end
    end

    private def monitor_file_changes
      while @running
        sleep 0.1.seconds
        # The file watchers run in separate fibers
        # This just keeps the main fiber alive
      end
    end

    private def wait_for_server_process
      if process = @server_process
        process.wait
      end
    end

    private def show_development_info(host : String, port : Int32)
      puts
      puts "🚀 Development server is running!".colorize(:green).bold
      puts
      puts "📍 Local:    http://#{host}:#{port}".colorize(:cyan)
      if host == "0.0.0.0"
        puts "📍 Network:  http://localhost:#{port}".colorize(:cyan)
      end
      puts "📁 File watching: enabled".colorize(:yellow)
      puts
      puts "💡 Tips:".colorize(:blue).bold
      puts "  • Edit Crystal files and see automatic rebuilds"
      puts "  • Refresh browser after template/static file changes"
      puts "  • Press Ctrl+C to stop the server"
      puts
    end

    private def cleanup_and_exit(code : Int32)
      cleanup
      exit(code)
    end

    private def cleanup
      @running = false

      # Stop file watchers
      @watchers.each(&.stop)
      @watchers.clear

      # Stop application server
      if process = @server_process
        begin
          process.signal(Signal::TERM)
          sleep 1.second
          process.signal(Signal::KILL) if process.exists?
        rescue
          # Process might already be dead
        end
      end
    end

    def show_command_specific_help
      puts "Options:".colorize(:yellow).bold
      puts "  --host HOST               Host to bind to (default: localhost)"
      puts "  --port PORT               Port to run on (default: 3000)"
      puts "  --no-watch                Disable file watching"
      puts "  --verbose                 Enable verbose output"
      puts
      puts "Examples:".colorize(:green).bold
      puts "  azu serve                          # Start with defaults"
      puts "  azu serve --port 4000              # Use custom port"
      puts "  azu serve --host 0.0.0.0           # Bind to all interfaces"
      puts "  azu serve --no-watch               # Disable file watching"
      puts "  azu serve --verbose                # Show detailed output"
      puts
      puts "File Watching Features:".colorize(:cyan).bold
      puts "  • Automatic rebuilds on Crystal file changes"
      puts "  • Notifications for template and static file changes"
      puts "  • Real-time error reporting"
      puts "  • Manual browser refresh for template/static changes"
      puts
      puts "Environment Variables:".colorize(:magenta).bold
      puts "  AZU_HOST                  Default host"
      puts "  AZU_PORT                  Default port"
      puts "  AZU_ENV                   Environment (development, test, production)"
      puts
      puts "Future Enhancements:".colorize(:blue).bold
      puts "  • WebSocket-based hot reloading"
      puts "  • Automatic browser refresh"
      puts "  • Template hot swapping"
      puts "  • CSS-only updates without page reload"
    end
  end

  # File watcher implementation using Crystal's built-in file watching
  private class FileWatcher
    @pattern : String
    @verbose : Bool
    @running = false
    @last_modified = {} of String => Time

    def initialize(@pattern : String, @verbose : Bool = false)
    end

    def on_change(&@on_change_callback : String ->)
    end

    def start
      @running = true

      spawn do
        while @running
          check_files
          sleep 0.5.seconds
        end
      end
    end

    def stop
      @running = false
    end

    private def check_files
      Dir.glob(@pattern).each do |file_path|
        next unless File.file?(file_path)

        current_mtime = File.info(file_path).modification_time

        if last_mtime = @last_modified[file_path]?
          if current_mtime > last_mtime
            @last_modified[file_path] = current_mtime
            @on_change_callback.try(&.call(file_path))
          end
        else
          @last_modified[file_path] = current_mtime
        end
      end
    rescue ex
      # Silently ignore file access errors during watching
    end
  end
end
