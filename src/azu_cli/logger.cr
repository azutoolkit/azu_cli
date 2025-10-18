require "log"
require "colorize"
require "json"

module AzuCLI
  # Centralized logging system for Azu CLI
  # Provides structured logging with colored output and multiple formats
  module Logger
    extend self

    # Color scheme for different message types
    private COLORS = {
      debug:   :dark_gray,
      info:    :white,
      warn:    :yellow,
      error:   :red,
      fatal:   :magenta,
      success: :green,
      title:   :cyan,
      prompt:  :blue,
    }

    # Icons for different message types
    private ICONS = {
      debug:   "🔍",
      info:    "ℹ️ ",
      warn:    "⚠️ ",
      error:   "❌",
      fatal:   "💀",
      success: "✅",
      title:   "📋",
      prompt:  "❓",
    }

    @@log : Log?
    @@setup_done = false

    # Setup logging system based on configuration
    def setup
      return if @@setup_done

      config = Config.instance

      # Create log backend with appropriate formatter
      backend = create_backend(config)

      # Configure Crystal's logging system
      ::Log.setup do |c|
        c.bind "*", config.log_level, backend
      end

      @@log = ::Log.for("azu_cli")
      @@setup_done = true
    end

    # Create appropriate log backend based on configuration
    private def create_backend(config : Config) : Log::Backend
      if config.colored_output? && STDOUT.tty?
        ColoredBackend.new(
          io: STDOUT, # Changed to STDOUT for regular output
          format: config.log_format,
          show_icons: true
        )
      else
        ::Log::IOBackend.new(
          io: STDOUT, # Changed to STDOUT for regular output
          formatter: create_formatter(config.log_format)
        )
      end
    end

    # Create log formatter based on format string
    private def create_formatter(format : String) : Log::Formatter
      case format
      when "json"
        Log::Formatter.new do |entry, io|
          {
            timestamp: entry.timestamp.to_rfc3339,
            level:     entry.severity.to_s.downcase,
            message:   entry.message,
            source:    entry.source,
          }.to_json(io)
        end
      when "compact"
        Log::Formatter.new do |entry, io|
          io << "[" << entry.severity.to_s[0] << "] "
          io << entry.message
        end
      else # default
        Log::Formatter.new do |entry, io|
          io << "[" << entry.timestamp.to_s("%H:%M:%S") << "] "
          io << "[" << entry.severity.to_s.upcase.ljust(5) << "] "
          io << entry.message
        end
      end
    end

    # Ensure logger is initialized
    private def log
      setup unless @@setup_done
      @@log.not_nil!
    end

    # Standard log levels
    def debug(message : String)
      log.debug { message }
    end

    def info(message : String)
      log.info { message }
    end

    def warn(message : String)
      # Warnings should go to STDERR
      if Config.instance.colored_output? && STDERR.tty?
        print_colored(:warn, message, io: STDERR)
      else
        STDERR.puts("WARNING: #{message}")
      end
    end

    def error(message : String)
      # Errors should go to STDERR
      if Config.instance.colored_output? && STDERR.tty?
        print_colored(:error, message, io: STDERR)
      else
        STDERR.puts("ERROR: #{message}")
      end
    end

    def fatal(message : String)
      # Fatal errors should go to STDERR
      if Config.instance.colored_output? && STDERR.tty?
        print_colored(:fatal, message, io: STDERR)
      else
        STDERR.puts("FATAL: #{message}")
      end
    end

    # CLI-specific log methods with enhanced formatting
    def success(message : String)
      if Config.instance.colored_output? && STDOUT.tty?
        print_colored(:success, message, io: STDOUT)
      else
        puts("SUCCESS: #{message}")
      end
    end

    def title(message : String)
      if Config.instance.colored_output? && STDOUT.tty?
        print_colored(:title, message, io: STDOUT)
      else
        puts("TITLE: #{message}")
      end
    end

    def prompt(message : String)
      if Config.instance.colored_output? && STDOUT.tty?
        print_colored(:prompt, message, io: STDOUT)
      else
        print("#{message} ")
      end
    end

    def announce(message : String)
      output_io = STDOUT
      if Config.instance.colored_output? && output_io.tty?
        output_io.puts
        output_io.puts "=" * 60
        output_io.print "  #{ICONS[:title]} "
        output_io.puts message.colorize(COLORS[:title]).bold
        output_io.puts "=" * 60
        output_io.puts
      else
        output_io.puts
        output_io.puts "=" * 60
        output_io.puts "  #{message}"
        output_io.puts "=" * 60
        output_io.puts
      end
    end

    def step(step_number : Int32, total_steps : Int32, message : String)
      prefix = "[#{step_number}/#{total_steps}]"
      output_io = STDOUT

      if Config.instance.colored_output? && output_io.tty?
        output_io.print prefix.colorize(:dark_gray)
        output_io.print " "
        output_io.puts message.colorize(COLORS[:info])
      else
        output_io.puts "#{prefix} #{message}"
      end
    end

    def progress_start(message : String)
      output_io = STDOUT
      if Config.instance.colored_output? && output_io.tty?
        output_io.print "#{ICONS[:info]} #{message}... ".colorize(COLORS[:info])
        output_io.flush
      else
        output_io.print "#{message}... "
        output_io.flush
      end
    end

    def progress_done(success : Bool = true)
      output_io = STDOUT
      if Config.instance.colored_output? && output_io.tty?
        if success
          output_io.puts "✅ Done".colorize(COLORS[:success])
        else
          output_io.puts "❌ Failed".colorize(COLORS[:error])
        end
      else
        output_io.puts success ? "Done" : "Failed"
      end
    end

    def command_start(command : String)
      output_io = STDOUT
      if Config.instance.colored_output? && output_io.tty?
        output_io.print "    → ".colorize(:dark_gray)
        output_io.puts command.colorize(:white)
      else
        output_io.puts "    → #{command}"
      end
    end

    def file_created(path : String)
      output_io = STDOUT
      if Config.instance.colored_output? && output_io.tty?
        output_io.print "      ✨ Created: ".colorize(COLORS[:success])
        output_io.puts path.colorize(:white)
      else
        output_io.puts "      Created: #{path}"
      end
    end

    def file_modified(path : String)
      output_io = STDOUT
      if Config.instance.colored_output? && output_io.tty?
        output_io.print "      📝 Modified: ".colorize(COLORS[:warn])
        output_io.puts path.colorize(:white)
      else
        output_io.puts "      Modified: #{path}"
      end
    end

    def file_skipped(path : String, reason : String = "already exists")
      output_io = STDOUT
      if Config.instance.colored_output? && output_io.tty?
        output_io.print "      ⏭️  Skipped: ".colorize(:dark_gray)
        output_io.print path.colorize(:white)
        output_io.puts " (#{reason})".colorize(:dark_gray)
      else
        output_io.puts "      Skipped: #{path} (#{reason})"
      end
    end

    # Print colored message with icon
    private def print_colored(type : Symbol, message : String, io : IO = STDOUT)
      icon = ICONS[type]? || ""
      color = COLORS[type]? || :white

      io.print "#{icon} " unless icon.empty?
      io.puts message.colorize(color)
    end

    # Custom colored backend for enhanced CLI output
    private class ColoredBackend < Log::Backend
      def initialize(@io : IO, @format : String, @show_icons : Bool = true)
        super()
      end

      def write(entry : Log::Entry)
        # Route different log levels to appropriate outputs
        target_io = case entry.severity
                    when .warn?, .error?, .fatal?
                      STDERR
                    else
                      @io # Use configured IO (STDOUT for info/debug)
                    end

        color = case entry.severity
                when .debug? then COLORS[:debug]
                when .info?  then COLORS[:info]
                when .warn?  then COLORS[:warn]
                when .error? then COLORS[:error]
                when .fatal? then COLORS[:fatal]
                else              :white
                end

        icon = if @show_icons
                 case entry.severity
                 when .debug? then ICONS[:debug]
                 when .info?  then ICONS[:info]
                 when .warn?  then ICONS[:warn]
                 when .error? then ICONS[:error]
                 when .fatal? then ICONS[:fatal]
                 else              ""
                 end
               else
                 ""
               end

        target_io.print icon unless icon.empty?
        target_io.print " " unless icon.empty?
        target_io.puts entry.message.colorize(color)
        target_io.flush
      end
    end

    # Exception handling with detailed formatting
    def exception(ex : Exception, context : String? = nil)
      error_io = STDERR

      if Config.instance.colored_output? && error_io.tty?
        error_io.puts
        error_io.puts "💥 Exception Occurred".colorize(COLORS[:error]).bold
        error_io.puts "=" * 50

        if context
          error_io.print "Context: ".colorize(:dark_gray)
          error_io.puts context.colorize(:white)
        end

        error_io.print "Error: ".colorize(COLORS[:error])
        error_io.puts ex.message.colorize(:white)

        if Config.instance.debug_mode && (backtrace = ex.backtrace?)
          error_io.puts
          error_io.puts "Backtrace:".colorize(:dark_gray)
          backtrace.each_with_index do |frame, index|
            if index < 10 # Limit backtrace in non-debug mode
              error_io.puts "  #{frame}".colorize(:dark_gray)
            end
          end
        end

        error_io.puts "=" * 50
        error_io.puts
      else
        error_io.puts
        error_io.puts "Exception: #{ex.message}"
        if context
          error_io.puts "Context: #{context}"
        end
        if Config.instance.debug_mode && (backtrace = ex.backtrace?)
          error_io.puts "Backtrace:"
          backtrace.each { |frame| error_io.puts "  #{frame}" }
        end
        error_io.puts
      end

      log.error(exception: ex) { context || "Exception occurred" }
    end
  end
end
