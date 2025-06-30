require "yaml"

module AzuCLI
  # Base command class for all Azu CLI commands
  # Provides common functionality, error handling, and validation
  abstract class Command
    # Command will be integrated with Topia via plugin pattern

    # Exit code constants for consistent CLI behavior
    EXIT_SUCCESS = 0
    EXIT_FAILURE = 1

    PROGRAM = self.name.split("::").last
    VERSION = Shard.git_description.split(/\s+/, 2).last
    USAGE   = <<-EOF

    {description}

    #{bold :Usage}

      #{light_blue :azu} {{program}} {{args}}

    #{bold :Options}

    {options}

    {version}
    EOF

    getter project_name : String { shard.as_h["name"].as_s }

    macro included
      macro finished
        option help : Bool, "--help", "Show this help", false
        option version : Bool, "--version", "Print the version and exit", false
      end

      def run(input, args)
        die "Invalid number of arguments" if args.empty? && !ARGS.empty?
        run(args)
        run
        true
      rescue e
        error "#{PROGRAM} command failed! - #{e.message}"
        exit EXIT_FAILURE
      end

      def show_usage
        USAGE.gsub(/{version}/, show_version)
          .gsub(/{program}/, PROGRAM.downcase)
          .gsub(/{description}/, DESCRIPTION)
          .gsub(/{args}/, ARGS)
          .gsub(/{options}/, new_option_parser.to_s)
      end

      def on(event : String)
      end

      def not_exists?(path)
        if File.exists? path
          error "File `#{path.underscore}` already exists"
          exit EXIT_FAILURE
        else
          yield
        end
      end

      def shard(path = "./shard.yml")
        contents = File.read(path)
        YAML.parse contents
      end
    end

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

    # Execute the command with proper error handling
    def run(input, args : Array(String)) : String
      begin
        # Validate arguments before execution
        validate_args(args)

        # Parse command-line arguments
        parsed_args = parse_args(args)

        # Execute the command
        result = execute(parsed_args)

        log.debug("Command '#{command_name}' completed successfully")
        result.to_s

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

    # Abstract method that subclasses must implement
    abstract def execute(args : Hash(String, String | Array(String))) : String | Nil

    # Parse command line arguments into a hash
    # Override in subclasses for custom argument parsing
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

    # Get positional arguments from parsed args
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

    # Get flag value from parsed args
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

    # Check if flag is present
    def has_flag?(args : Hash(String, String | Array(String)), flag : String) : Bool
      args.has_key?(flag)
    end

    # Validate command arguments
    # Override in subclasses for custom validation
    def validate_args(args : Array(String))
      # Check for help flag
      if args.includes?("--help") || args.includes?("-h")
        show_help
        exit(Config::EXIT_SUCCESS)
      end

      # Check for version flag
      if args.includes?("--version") || args.includes?("-v")
        show_version
        exit(Config::EXIT_SUCCESS)
      end
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

    # Error handling methods
    private def handle_argument_error(ex : ArgumentError)
      log.error("Invalid arguments: #{ex.message}")
      log.info("Run 'azu #{command_name} --help' for usage information")
      exit(Config::EXIT_INVALID_USAGE)
    end

    private def handle_validation_error(ex : ValidationError)
      log.error("Validation error: #{ex.message}")
      ex.suggestions.each { |suggestion| log.info("  • #{suggestion}") }
      exit(Config::EXIT_INVALID_USAGE)
    end

    private def handle_filesystem_error(ex : FileSystemError)
      log.error("File system error: #{ex.message}")
      log.info("Please check file permissions and paths")
      exit(Config::EXIT_FAILURE)
    end

    private def handle_unexpected_error(ex : Exception)
      log.exception(ex, "Command '#{command_name}' execution")
      exit(Config::EXIT_FAILURE)
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
