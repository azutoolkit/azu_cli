require "yaml"
require "option_parser"

module AzuCLI
  # Base command class for all Azu CLI commands
  # Provides common functionality, error handling, validation, and OptionParser integration
  abstract class Command
    # Command will be integrated with Topia via plugin pattern

    # Exit code constants for consistent CLI behavior
    EXIT_SUCCESS = 0
    EXIT_FAILURE = 1

    # Command metadata
    macro command_name(name)
      def self.command_name : String
        {{ name.stringify }}
      end

      def command_name : String
        {{ name.stringify }}
      end
    end

    macro description(desc)
      def self.description : String
        {{ desc.stringify }}
      end

      def description : String
        {{ desc.stringify }}
      end
    end

    macro usage(usage_text)
      def self.usage : String
        {{ usage_text.stringify }}
      end

      def usage : String
        {{ usage_text.stringify }}
      end
    end

    # Access to global configuration
    def config : Config
      Config.instance
    end

    # Access to logger
    def log
      Logger
    end

    # Storage for parsed options and remaining arguments
    getter parsed_options : Hash(String, String | Bool | Array(String)) = {} of String => String | Bool | Array(String)
    getter remaining_args : Array(String) = [] of String
    getter help_requested : Bool = false
    getter version_requested : Bool = false

    # Execute the command with proper error handling using OptionParser
    def run(input, args : Array(String)) : String
      begin
        # Parse arguments using OptionParser
        parse_with_option_parser(args)

        # Handle help and version requests early
        if help_requested
          show_help
          return ""
        end

        if version_requested
          show_version
          return ""
        end

        # Validate arguments after parsing
        validate_parsed_args

        # Execute the command with parsed options and remaining args
        result = execute_with_options(parsed_options, remaining_args)

        log.debug("Command '#{command_name}' completed successfully")
        result.to_s
      rescue ex : OptionParser::InvalidOption
        handle_invalid_option_error(ex)
        ""
      rescue ex : OptionParser::MissingOption
        handle_missing_option_error(ex)
        ""
      rescue ex : ArgumentError
        handle_argument_error(ex)
        ""
      rescue ex : ValidationError
        handle_validation_error(ex)
        ""
      rescue ex : FileSystemError
        handle_filesystem_error(ex)
        ""
      rescue ex : Exception
        handle_unexpected_error(ex)
        ""
      end
    end

    # Parse arguments using Crystal's OptionParser
    private def parse_with_option_parser(args : Array(String))
      parser = OptionParser.new

      # Set up common options that all commands support
      setup_common_options(parser)

      # Set up command-specific options
      setup_command_options(parser)

      # Parse the arguments
      parser.parse(args)

      # Store remaining arguments
      @remaining_args = args
    end

    # Setup common options available to all commands
    private def setup_common_options(parser : OptionParser)
      parser.banner = "Usage: azu #{usage}"

      parser.on("-h", "--help", "Show help for this command") do
        @help_requested = true
      end

      parser.on("-v", "--version", "Show version information") do
        @version_requested = true
      end

      parser.on("--verbose", "Enable verbose output") do
        @parsed_options["verbose"] = true
      end

      parser.on("--quiet", "Suppress output") do
        @parsed_options["quiet"] = true
      end

      parser.on("--force", "Force operation without prompts") do
        @parsed_options["force"] = true
      end

      # Handle unknown arguments
      parser.unknown_args do |unknown_args, _|
        @remaining_args = unknown_args
      end

      # Handle invalid options
      parser.invalid_option do |option|
        raise OptionParser::InvalidOption.new("Unknown option: #{option}")
      end

      # Handle missing options
      parser.missing_option do |option|
        raise OptionParser::MissingOption.new("Missing required argument for option: #{option}")
      end
    end

    # Abstract method for command-specific option setup
    # Override in subclasses to add command-specific options
    def setup_command_options(parser : OptionParser)
      # Default implementation - override in subclasses
    end

    # Abstract method for command execution with parsed options
    # This replaces the old execute method
    abstract def execute_with_options(
      options : Hash(String, String | Bool | Array(String)),
      args : Array(String)
    ) : String | Nil

    # Backward compatibility method - converts old execute signature to new one
    def execute(args : Hash(String, String | Array(String))) : String | Nil
      # Convert old-style args to new format
      options = {} of String => String | Bool | Array(String)
      remaining = [] of String

      args.each do |key, value|
        if key == "_positional"
          case value
          when Array(String)
            remaining = value
          when String
            remaining = [value]
          end
        else
          case value
          when "true"
            options[key] = true
          when "false"
            options[key] = false
          else
            options[key] = value
          end
        end
      end

      execute_with_options(options, remaining)
    end

    # Legacy argument parsing for backward compatibility
    def parse_args(args : Array(String)) : Hash(String, String | Array(String))
      parsed = Hash(String, String | Array(String)).new

      i = 0
      while i < args.size
        arg = args[i]

        if arg.starts_with?("--")
          # Long option
          key = arg[2..]
          if key.includes?("=")
            parts = key.split("=", 2)
            parsed[parts[0]] = parts[1]
          elsif i + 1 < args.size && !args[i + 1].starts_with?("-")
            parsed[key] = args[i + 1]
            i += 1
          else
            parsed[key] = "true"
          end
        elsif arg.starts_with?("-") && arg.size > 1
          # Short option
          key = arg[1..]
          if i + 1 < args.size && !args[i + 1].starts_with?("-")
            parsed[key] = args[i + 1]
            i += 1
          else
            parsed[key] = "true"
          end
        else
          # Positional argument
          if parsed.has_key?("_positional")
            if current = parsed["_positional"]
              if current.is_a?(Array(String))
                current << arg
              else
                parsed["_positional"] = [current.as(String), arg]
              end
            end
          else
            parsed["_positional"] = [arg] of String
          end
        end

        i += 1
      end

      parsed
    end

    # Helper methods for accessing parsed options
    def get_option(key : String, default : String = "") : String
      value = parsed_options[key]?
      case value
      when String
        value
      when Bool
        value.to_s
      when Array(String)
        value.first? || default
      else
        default
      end
    end

    def get_option_bool(key : String, default : Bool = false) : Bool
      value = parsed_options[key]?
      case value
      when Bool
        value
      when String
        value == "true"
      else
        default
      end
    end

    def get_option_array(key : String) : Array(String)
      value = parsed_options[key]?
      case value
      when Array(String)
        value
      when String
        [value]
      else
        [] of String
      end
    end

    def has_option?(key : String) : Bool
      parsed_options.has_key?(key)
    end

    # Get positional arguments from parsed args - backward compatibility
    def get_positional_args(args : Hash(String, String | Array(String))) : Array(String)
      if positional = args["_positional"]?
        case positional
        when Array(String)
          positional
        when String
          [positional]
        else
          [] of String
        end
      else
        [] of String
      end
    end

    # Get flag value from parsed args - backward compatibility
    def get_flag(args : Hash(String, String | Array(String)), flag : String, default : String = "") : String
      if value = args[flag]?
        case value
        when String
          value
        when Array(String)
          value.first? || default
        else
          default
        end
      else
        default
      end
    end

    # Check if flag is present - backward compatibility
    def has_flag?(args : Hash(String, String | Array(String)), flag : String) : Bool
      args.has_key?(flag)
    end

    # Validate parsed arguments
    def validate_parsed_args
      # Override in subclasses for custom validation
    end

    # Legacy validate method for backward compatibility
    def validate_args(args : Array(String))
      # This is now handled by OptionParser, but kept for compatibility
    end

    # File system utilities
    def ensure_directory(path : String)
      unless Dir.exists?(path)
        log.debug("Creating directory: #{path}")
        Dir.mkdir_p(path)
        log.file_created(path)
      end
    end

    def write_file(path : String, content : String, force : Bool = false)
      if File.exists?(path) && !force
        if ask_overwrite(path)
          File.write(path, content)
          log.file_modified(path)
        else
          log.file_skipped(path, "user chose not to overwrite")
        end
      else
        ensure_directory(File.dirname(path))
        File.write(path, content)
        log.file_created(path)
      end
    end

    def copy_file(source : String, destination : String, force : Bool = false)
      if File.exists?(destination) && !force
        if ask_overwrite(destination)
          File.copy(source, destination)
          log.file_modified(destination)
        else
          log.file_skipped(destination, "user chose not to overwrite")
        end
      else
        ensure_directory(File.dirname(destination))
        File.copy(source, destination)
        log.file_created(destination)
      end
    end

    def ask_overwrite(path : String) : Bool
      unless config.quiet
        log.prompt("File #{path} already exists. Overwrite? [y/N]")
        response = gets
        response.try(&.strip.downcase.starts_with?("y")) || false
      else
        false
      end
    end

    # Template rendering utilities
    def render_template(template_path : String, variables : Hash(String, String) = {} of String => String) : String
      full_path = File.join(config.templates_path, template_path)

      unless File.exists?(full_path)
        raise FileSystemError.new("Template not found: #{full_path}")
      end

      content = File.read(full_path)

      # Simple variable substitution
      variables.each do |key, value|
        content = content.gsub("{{#{key}}}", value)
      end

      content
    end

    # Project utilities
    def in_project_root? : Bool
      File.exists?("shard.yml") || File.exists?("config/azu.yml") || File.exists?("azu.yml")
    end

    def require_project_root!
      unless in_project_root?
        raise ValidationError.new("This command must be run from the project root directory")
      end
    end

    def get_project_name : String
      if File.exists?("shard.yml")
        yaml_content = File.read("shard.yml")
        yaml_data = YAML.parse(yaml_content)
        yaml_data["name"]?.try(&.as_s) || File.basename(Dir.current)
      else
        File.basename(Dir.current)
      end
    end

    # Display help information
    def show_help
      puts
      puts "#{command_name} - #{description}"
      puts
      puts "Usage:"
      puts "  azu #{usage}"
      puts
      show_command_specific_help
    end

    # Override in subclasses to show command-specific help
    def show_command_specific_help
      # Default implementation - can be overridden
    end

    # Display version information
    def show_version
      puts "Azu CLI v#{AzuCLI::VERSION}"
    end

    # Error handling methods for OptionParser and other errors
    private def handle_invalid_option_error(ex : OptionParser::InvalidOption)
      log.error("Invalid option: #{ex.message}")
      log.info("Run 'azu #{command_name} --help' to see available options")
    end

    private def handle_missing_option_error(ex : OptionParser::MissingOption)
      log.error("Missing required argument: #{ex.message}")
      log.info("Run 'azu #{command_name} --help' for usage information")
    end

    private def handle_argument_error(ex : ArgumentError)
      log.error("Invalid arguments: #{ex.message}")
      log.info("Run 'azu #{command_name} --help' for usage information")
    end

    private def handle_validation_error(ex : ValidationError)
      log.error("Validation error: #{ex.message}")
      ex.suggestions.each { |suggestion| log.info("  • #{suggestion}") }
    end

    private def handle_filesystem_error(ex : FileSystemError)
      log.error("File system error: #{ex.message}")
      log.info("Please check file permissions and paths")
    end

    private def handle_unexpected_error(ex : Exception)
      log.exception(ex, "Command '#{command_name}' execution")
    end

    # Custom exception classes
    class ValidationError < Exception
      property suggestions : Array(String)

      def initialize(message : String, @suggestions = [] of String)
        super(message)
      end
    end

    class FileSystemError < Exception
    end

    class ArgumentError < Exception
    end
  end

  # Namespace for organizing commands
  module Commands
  end
end
