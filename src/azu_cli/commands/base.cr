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

      def initialize(@name : String, @description : String = "")
        @options = {} of String => String
        @args = [] of String
      end

      # Abstract method that all commands must implement
      abstract def execute : Result

      # Parse command line arguments
      def parse_args(args : Array(String))
        @args = args
        parse_options
      end

      # Parse command options
      private def parse_options
        # Default option parsing - can be overridden by subclasses
        @args.each_with_index do |arg, index|
          if arg.starts_with?("--")
            if index + 1 < @args.size && !@args[index + 1].starts_with?("-")
              @options[arg[2..-1]] = @args[index + 1]
            else
              @options[arg[2..-1]] = "true"
            end
          elsif arg.starts_with?("-")
            if index + 1 < @args.size && !@args[index + 1].starts_with?("-")
              @options[arg[1..-1]] = @args[index + 1]
            else
              @options[arg[1..-1]] = "true"
            end
          end
        end
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
        @args[index]?
      end

      # Get all arguments
      def get_args : Array(String)
        @args
      end

      # Success result
      def success(message : String = "") : Result
        Result.success(message)
      end

      # Error result
      def error(message : String) : Result
        Result.error(message)
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
