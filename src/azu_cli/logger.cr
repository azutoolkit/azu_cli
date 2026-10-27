require "log"
require "colorize"
require "json"
require "./ui"

module AzuCLI
  # Centralized logging system for Azu CLI
  # Provides structured logging with colored output and multiple formats
  module Logger
    extend self

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
          formatter: create_formatter(config.log_format),
          dispatcher: ::Log::DispatchMode::Sync
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
      if styled?(STDERR)
        emit(STDERR, lines(STDERR).message(UI::Lines::Kind::Warn, message))
      else
        STDERR.puts("WARNING: #{message}")
      end
    end

    def error(message : String)
      if styled?(STDERR)
        emit(STDERR, lines(STDERR).message(UI::Lines::Kind::Error, message))
      else
        STDERR.puts("ERROR: #{message}")
      end
    end

    def fatal(message : String)
      if styled?(STDERR)
        emit(STDERR, lines(STDERR).message(UI::Lines::Kind::Fatal, message))
      else
        STDERR.puts("FATAL: #{message}")
      end
    end

    # CLI-specific log methods with enhanced formatting
    def success(message : String)
      styled?(STDOUT) ? emit(STDOUT, lines(STDOUT).message(UI::Lines::Kind::Success, message)) : puts("SUCCESS: #{message}")
    end

    def title(message : String)
      styled?(STDOUT) ? emit(STDOUT, lines(STDOUT).message(UI::Lines::Kind::Title, message)) : puts("TITLE: #{message}")
    end

    def prompt(message : String)
      if styled?(STDOUT)
        STDOUT.print "#{lines(STDOUT).message(UI::Lines::Kind::Prompt, message)} "
      else
        print("#{message} ")
      end
    end

    def announce(message : String)
      STDOUT.puts
      if styled?(STDOUT)
        STDOUT.puts lines(STDOUT).header(message)
      else
        STDOUT.puts "=" * 60
        STDOUT.puts "  #{message}"
        STDOUT.puts "=" * 60
      end
      STDOUT.puts
    end

    def step(step_number : Int32, total_steps : Int32, message : String)
      if styled?(STDOUT)
        emit(STDOUT, lines(STDOUT).step(step_number, total_steps, message))
      else
        STDOUT.puts "[#{step_number}/#{total_steps}] #{message}"
      end
    end

    def progress_start(message : String)
      if styled?(STDOUT)
        STDOUT.print "#{lines(STDOUT).message(UI::Lines::Kind::Info, message)}#{lines(STDOUT).glyphs.ellipsis} "
      else
        STDOUT.print "#{message}... "
      end
      STDOUT.flush
    end

    def progress_done(success : Bool = true)
      if styled?(STDOUT)
        lines = lines(STDOUT)
        STDOUT.puts success ? lines.paint("#{lines.glyphs.ok} done", UI::Token::Green) : lines.paint("#{lines.glyphs.fail} failed", UI::Token::Red)
      else
        STDOUT.puts success ? "Done" : "Failed"
      end
    end

    def command_start(command : String)
      styled?(STDOUT) ? emit(STDOUT, lines(STDOUT).message(UI::Lines::Kind::Command, command)) : STDOUT.puts("    → #{command}")
    end

    def file_created(path : String)
      styled?(STDOUT) ? emit(STDOUT, lines(STDOUT).message(UI::Lines::Kind::Created, path)) : STDOUT.puts("      Created: #{path}")
    end

    def file_modified(path : String)
      styled?(STDOUT) ? emit(STDOUT, lines(STDOUT).message(UI::Lines::Kind::Modified, path)) : STDOUT.puts("      Modified: #{path}")
    end

    def file_skipped(path : String, reason : String = "already exists")
      styled?(STDOUT) ? emit(STDOUT, lines(STDOUT).message(UI::Lines::Kind::Skipped, "#{path} (#{reason})")) : STDOUT.puts("      Skipped: #{path} (#{reason})")
    end

    # Whether `io` gets the themed lines: a terminal, and colored output not turned off in the configuration.
    private def styled?(io : IO::FileDescriptor) : Bool
      Config.instance.colored_output? && io.tty?
    end

    @@lines = {} of Int32 => UI::Lines

    # Prints a styled line; while a live card is drawn (a db:migrate task), above it.
    def emit(io : IO, line : String) : Nil
      if live = UI::Rich.live
        live.print_above(line, io)
      else
        io.puts line
        io.flush
      end
    end

    # The theme of the terminal on `io` (NO_COLOR keeps the glyphs and drops the color).
    def lines(io : IO::FileDescriptor) : UI::Lines
      @@lines[io.fd] ||= UI::Lines.new(UI::Terminal.detect(io))
    end

    # Custom colored backend for enhanced CLI output
    private class ColoredBackend < Log::Backend
      # Synchronous: a line is on the terminal before the next `puts` or live card, never written later by a fiber.
      def initialize(@io : IO::FileDescriptor, @format : String, @show_icons : Bool = true)
        super(::Log::DispatchMode::Sync)
      end

      def write(entry : Log::Entry)
        target_io = entry.severity.warn? || entry.severity.error? || entry.severity.fatal? ? STDERR : @io
        kind = case entry.severity
               when .debug? then UI::Lines::Kind::Debug
               when .warn?  then UI::Lines::Kind::Warn
               when .error? then UI::Lines::Kind::Error
               when .fatal? then UI::Lines::Kind::Fatal
               else              UI::Lines::Kind::Info
               end
        Logger.emit(target_io, Logger.lines(target_io).message(kind, entry.message))
      end
    end

    # Exception handling with detailed formatting
    def exception(ex : Exception, context : String? = nil)
      error_io = STDERR

      if styled?(error_io)
        lines = lines(error_io)
        error_io.puts
        error_io.puts lines.message(UI::Lines::Kind::Error, ex.message.to_s)
        context.try { |text| error_io.puts "  #{lines.paint(text, UI::Token::Muted)}" }
        if Config.instance.debug_mode && (backtrace = ex.backtrace?)
          backtrace.first(10).each { |frame| error_io.puts "  #{lines.paint(frame, UI::Token::Faint)}" }
        end
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
