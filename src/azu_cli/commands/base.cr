require "option_parser"

module AzuCLI
  module Commands
    # Result class for command execution
    class Result
      property success : Bool
      property message : String
      property error : String

      def initialize(@success : Bool, @message : String = "", @error : String = "")
      end

      def self.success(message : String = "") : Result
        new(true, message)
      end

      def self.error(error : String) : Result
        new(false, "", error)
      end

      def success? : Bool
        @success
      end
    end

    # Base command class for all Azu CLI commands
    abstract class Base
      property name : String
      property description : String
      property options : Hash(String, String)
      property args : Array(String)
      property all_args : Array(String)

      def initialize(@name : String, @description : String = "")
        @options = {} of String => String
        @args = [] of String
        @all_args = [] of String
      end

      # Abstract method that all commands must implement
      abstract def execute : Result

      # Parse command line arguments using Crystal's OptionParser
      def parse_args(args : Array(String))
        # Reset state
        @options.clear
        @args.clear
        @all_args = args.dup # Store all arguments as-is for get_args

        # Parse arguments and extract options
        skip_next = false
        args.each_with_index do |arg, index|
          if skip_next
            skip_next = false
            next
          end

          if arg.starts_with?("--")
            if arg.includes?("=")
              # Handle --option=value format
              parts = arg.split("=", 2)
              key = parts[0][2..-1] # Remove the "--"
              value = parts[1]
              @options[key] = value
            else
              # Handle --option format
              key = arg[2..-1] # Remove the "--"
              if is_boolean_flag?(key)
                @options[key] = "true"
              else
                # Try to consume next argument as value
                if index + 1 < args.size && !args[index + 1].starts_with?("-")
                  @options[key] = args[index + 1]
                  skip_next = true
                else
                  @options[key] = "true"
                end
              end
            end
          elsif arg.starts_with?("-") && !arg.starts_with?("--")
            # Handle -o format
            key = arg[1..-1] # Remove the "-"
            if is_boolean_flag?(key)
              @options[key] = "true"
            else
              # Try to consume next argument as value
              if index + 1 < args.size && !args[index + 1].starts_with?("-")
                @options[key] = args[index + 1]
                skip_next = true
              else
                @options[key] = "true"
              end
            end
          else
            # This is a regular argument
            @args << arg
          end
        end
      end

      # Check if a flag is a boolean flag (doesn't take a value)
      private def is_boolean_flag?(key : String) : Bool
        boolean_flags = ["debug", "d", "help", "h", "version", "v", "verbose", "quiet", "q", "force", "f"]
        boolean_flags.includes?(key)
      end

      # Get option value with default
      def get_option(key : String, default : String = "") : String
        @options[key]? || default
      end

      # Check if option is set
      def has_option?(key : String) : Bool
        @options.has_key?(key)
      end

      # Get argument at index
      def get_arg(index : Int32) : String?
        @all_args[index]?
      end

      # Get all arguments (including flags)
      def get_args : Array(String)
        @all_args
      end

      # Success result
      def success(message : String = "") : Result
        Result.success(message)
      end

      # Error result
      def error(message : String) : Result
        Logger.error(message)
        Result.error(message)
      end

      # Error result with category
      def error(message : String, category : String) : Result
        Logger.error("[#{category}] #{message}")
        Result.error(message)
      end

      # Handle error with proper logging and optional exit
      def handle_error(
        message : String,
        category : String = Config::ErrorCategory::UNKNOWN,
        severity : Int32 = Config::ErrorSeverity::ERROR,
        exit_code : Int32 = Config::EXIT_FAILURE,
        should_exit : Bool = false,
      ) : Result
        # Format error message with category if provided
        formatted_message = category == Config::ErrorCategory::UNKNOWN ? message : "[#{category}] #{message}"

        # Log based on severity
        case severity
        when Config::ErrorSeverity::DEBUG
          Logger.debug(formatted_message) if AzuCLI::Config.instance.debug_mode
        when Config::ErrorSeverity::INFO
          Logger.info(formatted_message)
        when Config::ErrorSeverity::WARN
          Logger.warn(formatted_message)
        when Config::ErrorSeverity::ERROR
          Logger.error(formatted_message)
        when Config::ErrorSeverity::FATAL
          Logger.fatal(formatted_message)
        end

        # Exit if requested or if fatal
        if should_exit || severity == Config::ErrorSeverity::FATAL
          # In debug mode, raise exception for better stack traces
          if AzuCLI::Config.instance.debug_mode
            raise Exception.new(formatted_message)
          else
            exit(exit_code)
          end
        end

        Result.error(message)
      end

      # Handle fatal error (always exits)
      def fatal_error(message : String, category : String = Config::ErrorCategory::UNKNOWN) : NoReturn
        handle_error(
          message,
          category: category,
          severity: Config::ErrorSeverity::FATAL,
          exit_code: Config::EXIT_FAILURE,
          should_exit: true
        )
        exit(Config::EXIT_FAILURE) # Explicit exit for NoReturn
      end

      # Handle warning (logs but doesn't fail)
      def warning(message : String, category : String = Config::ErrorCategory::UNKNOWN)
        formatted_message = category == Config::ErrorCategory::UNKNOWN ? message : "[#{category}] #{message}"
        Logger.warn(formatted_message)
      end

      # Handle validation error with proper context
      def validation_error(message : String) : Result
        handle_error(
          message,
          category: Config::ErrorCategory::INVALID_INPUT,
          severity: Config::ErrorSeverity::ERROR
        )
      end

      # Handle file system error
      def filesystem_error(message : String, category : String = Config::ErrorCategory::IO_ERROR) : Result
        handle_error(
          message,
          category: category,
          severity: Config::ErrorSeverity::ERROR
        )
      end

      # Wrap exception handling with consistent error reporting
      def with_error_handling(category : String = Config::ErrorCategory::RUNTIME_ERROR, &block)
        begin
          yield
        rescue ex : Exception
          error_message = AzuCLI::Config.instance.debug_mode ? "#{ex.message}\n#{ex.backtrace?.try(&.join("\n"))}" : ex.message.to_s
          handle_error(
            error_message,
            category: category,
            severity: Config::ErrorSeverity::ERROR
          )
        end
      end

      # Validate required arguments
      def validate_required_args(required_count : Int32) : Bool
        if @args.size < required_count
          Logger.error("Missing required arguments. Expected #{required_count}, got #{@args.size}")
          return false
        end
        true
      end

      # Validate required options
      def validate_required_options(required_options : Array(String)) : Bool
        missing = required_options.reject { |opt| has_option?(opt) }
        unless missing.empty?
          Logger.error("Missing required options: #{missing.join(", ")}")
          return false
        end
        true
      end

      # Show help for this command
      def show_help
        puts "Usage: azu #{@name} [options] [arguments]"
        puts
        puts "Description: #{@description}"
        puts
        puts "Options:"
        puts "  --help     Show this help message"
        puts "  --version  Show version information"
        puts
        puts "Examples:"
        show_examples
      end

      # Show command examples - can be overridden by subclasses
      def show_examples
        puts "  azu #{@name} --help"
      end
    end
  end
end
