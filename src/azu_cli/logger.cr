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
      prompt:  :blue
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
      prompt:  "❓"
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
      if config.colored_output && STDOUT.tty?
        ColoredBackend.new(
          io: STDERR,
          format: config.log_format,
          show_icons: true
        )
      else
        ::Log::IOBackend.new(
          io: STDERR,
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
            level: entry.severity.to_s.downcase,
            message: entry.message,
            source: entry.source
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
      log.warn { message }
    end

    def error(message : String)
      log.error { message }
    end

    def fatal(message : String)
      log.fatal { message }
    end

    # CLI-specific log methods with enhanced formatting
    def success(message : String)
      if Config.instance.colored_output && STDERR.tty?
        print_colored(:success, message)
      else
        info("SUCCESS: #{message}")
      end
    end

    def title(message : String)
      if Config.instance.colored_output && STDERR.tty?
        print_colored(:title, message)
      else
        info("TITLE: #{message}")
      end
    end

    def prompt(message : String)
      if Config.instance.colored_output && STDERR.tty?
        print_colored(:prompt, message, io: STDOUT)
      else
        print("#{message} ")
      end
    end

    def announce(message : String)
      if Config.instance.colored_output && STDERR.tty?
        STDERR.puts
        STDERR.puts "=" * 60
        STDERR.print "  #{ICONS[:title]} "
        STDERR.puts message.colorize(COLORS[:title]).bold
        STDERR.puts "=" * 60
        STDERR.puts
      else
        STDERR.puts
        STDERR.puts "=" * 60
        STDERR.puts "  #{message}"
        STDERR.puts "=" * 60
        STDERR.puts
      end
    end

    def step(step_number : Int32, total_steps : Int32, message : String)
      prefix = "[#{step_number}/#{total_steps}]"

      if Config.instance.colored_output && STDERR.tty?
        STDERR.print prefix.colorize(:dark_gray)
        STDERR.print " "
        STDERR.puts message.colorize(COLORS[:info])
      else
        STDERR.puts "#{prefix} #{message}"
      end
    end

    def progress_start(message : String)
      if Config.instance.colored_output && STDERR.tty?
        STDERR.print "#{ICONS[:info]} #{message}... ".colorize(COLORS[:info])
        STDERR.flush
      else
        STDERR.print "#{message}... "
        STDERR.flush
      end
    end

    def progress_done(success : Bool = true)
      if Config.instance.colored_output && STDERR.tty?
        if success
          STDERR.puts "✅ Done".colorize(COLORS[:success])
        else
          STDERR.puts "❌ Failed".colorize(COLORS[:error])
        end
      else
        STDERR.puts success ? "Done" : "Failed"
      end
    end

    def command_start(command : String)
      if Config.instance.colored_output && STDERR.tty?
        STDERR.print "    → ".colorize(:dark_gray)
        STDERR.puts command.colorize(:white)
      else
        STDERR.puts "    → #{command}"
      end
    end

    def file_created(path : String)
      if Config.instance.colored_output && STDERR.tty?
        STDERR.print "      ✨ Created: ".colorize(COLORS[:success])
        STDERR.puts path.colorize(:white)
      else
        STDERR.puts "      Created: #{path}"
      end
    end

    def file_modified(path : String)
      if Config.instance.colored_output && STDERR.tty?
        STDERR.print "      📝 Modified: ".colorize(COLORS[:warn])
        STDERR.puts path.colorize(:white)
      else
        STDERR.puts "      Modified: #{path}"
      end
    end

    def file_skipped(path : String, reason : String = "already exists")
      if Config.instance.colored_output && STDERR.tty?
        STDERR.print "      ⏭️  Skipped: ".colorize(:dark_gray)
        STDERR.print path.colorize(:white)
        STDERR.puts " (#{reason})".colorize(:dark_gray)
      else
        STDERR.puts "      Skipped: #{path} (#{reason})"
      end
    end

    # Print colored message with icon
    private def print_colored(type : Symbol, message : String, io : IO = STDERR)
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
        color = case entry.severity
               when .debug? then COLORS[:debug]
               when .info?  then COLORS[:info]
               when .warn?  then COLORS[:warn]
               when .error? then COLORS[:error]
               when .fatal? then COLORS[:fatal]
               else :white
               end

        icon = if @show_icons
                case entry.severity
                when .debug? then ICONS[:debug]
                when .info?  then ICONS[:info]
                when .warn?  then ICONS[:warn]
                when .error? then ICONS[:error]
                when .fatal? then ICONS[:fatal]
                else ""
                end
              else
                ""
              end

        @io.print icon unless icon.empty?
        @io.print " " unless icon.empty?
        @io.puts entry.message.colorize(color)
        @io.flush
      end
    end

    # Exception handling with detailed formatting
    def exception(ex : Exception, context : String? = nil)
      if Config.instance.colored_output && STDERR.tty?
        STDERR.puts
        STDERR.puts "💥 Exception Occurred".colorize(COLORS[:error]).bold
        STDERR.puts "=" * 50

        if context
          STDERR.print "Context: ".colorize(:dark_gray)
          STDERR.puts context.colorize(:white)
        end

        STDERR.print "Error: ".colorize(COLORS[:error])
        STDERR.puts ex.message.colorize(:white)

        if Config.instance.debug_mode && (backtrace = ex.backtrace?)
          STDERR.puts
          STDERR.puts "Backtrace:".colorize(:dark_gray)
          backtrace.each_with_index do |frame, index|
            if index < 10  # Limit backtrace in non-debug mode
              STDERR.puts "  #{frame}".colorize(:dark_gray)
            end
          end
        end

        STDERR.puts "=" * 50
        STDERR.puts
      else
        STDERR.puts
        STDERR.puts "Exception: #{ex.message}"
        if context
          STDERR.puts "Context: #{context}"
        end
        if Config.instance.debug_mode && (backtrace = ex.backtrace?)
          STDERR.puts "Backtrace:"
          backtrace.each { |frame| STDERR.puts "  #{frame}" }
        end
        STDERR.puts
      end

      log.error(exception: ex) { context || "Exception occurred" }
    end
  end
end
