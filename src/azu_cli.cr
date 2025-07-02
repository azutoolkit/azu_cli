require "log"
require "cadmium_inflector"
require "teeplate"
require "option_parser"

require "./azu_cli/config"
require "./azu_cli/logger"
require "./azu_cli/command"
require "./azu_cli/commands/**"
require "./azu_cli/templates/**"
require "./azu_cli/generators/**"

module AzuCLI
  VERSION = "0.0.1"

  # Enhanced CLI implementation with Crystal's OptionParser
  def self.run
    begin
      # Initialize configuration and logging first
      Config.load!
      Logger.setup

      # Parse global options and commands using OptionParser
      command_name, command_args = parse_global_options

      # Handle empty command (show help)
      if command_name.empty?
        Commands::Help.new.run("", [] of String)
        exit(Config::EXIT_SUCCESS)
      end

      # Create command instance and execute
      command_instance = create_command(command_name)
      command_instance.run("", command_args)
    rescue ex : OptionParser::InvalidOption
      Logger.error("Invalid option: #{ex.message}")
      Logger.info("Run 'azu --help' to see available options")
      exit(Config::EXIT_INVALID_USAGE)
    rescue ex : Exception
      Logger.error("Critical error: #{ex.message}")
      Logger.debug("Stack trace: #{ex.backtrace?.try(&.join("\n")) || "No backtrace"}")
      exit(Config::EXIT_FAILURE)
    end
  end

  # Parse global CLI options and return command name and remaining args
  private def self.parse_global_options : {String, Array(String)}
    command_name = ""
    remaining_args = [] of String
    show_help = false
    show_version = false

    parser = OptionParser.new do |parser|
      parser.banner = "Azu CLI - A powerful development tool for the Azu framework\n\nUsage: azu [global_options] <command> [command_options]"

      parser.on("-h", "--help", "Show this help message") do
        show_help = true
      end

      parser.on("-v", "--version", "Show version information") do
        show_version = true
      end

      parser.on("--verbose", "Enable verbose output") do
        Config.instance.verbose = true
      end

      parser.on("--quiet", "Suppress output") do
        Config.instance.quiet = true
      end

      parser.separator ""
      parser.separator "Available commands:"
      parser.separator "  new        Create a new Azu project"
      parser.separator "  init       Initialize an existing project"
      parser.separator "  generate   Generate project components"
      parser.separator "  db         Database operations"
      parser.separator "  serve      Start development server"
      parser.separator "  dev        Development tools"
      parser.separator "  help       Show help for commands"
      parser.separator "  version    Show version information"
      parser.separator ""
      parser.separator "Examples:"
      parser.separator "  azu new my_app"
      parser.separator "  azu generate model User"
      parser.separator "  azu db migrate"
      parser.separator "  azu serve --port 3000"
      parser.separator ""
      parser.separator "Run 'azu <command> --help' for more information on a command."

      # Handle unknown arguments (these will be the command and its args)
      parser.unknown_args do |unknown_args, _|
        if unknown_args.any?
          command_name = unknown_args.first
          remaining_args = unknown_args[1..]
        end
      end

      # Handle invalid options
      parser.invalid_option do |option|
        raise OptionParser::InvalidOption.new("Unknown global option: #{option}")
      end
    end

    # Parse ARGV
    parser.parse(ARGV)

    # Handle global help and version
    if show_help
      puts parser
      exit(Config::EXIT_SUCCESS)
    end

    if show_version
      puts "Azu CLI v#{VERSION}"
      puts "Crystal #{Crystal::VERSION}"
      puts ""
      puts "A powerful development tool for the Azu framework"
      puts "https://github.com/azutoolkit/azu_cli"
      exit(Config::EXIT_SUCCESS)
    end

    {command_name, remaining_args}
  end

  # Create command instance based on command name
  private def self.create_command(command_name : String) : Command
    case command_name.downcase
    when "help", "h"
      Commands::Help.new
    when "version", "v"
      Commands::Version.new
    when "new"
      Commands::New.new
    when "init"
      Commands::Init.new
    when "generate", "g"
      Commands::GenerateOptimized.new
    when "db"
      Commands::Db.new
    else
      Logger.error("Unknown command: #{command_name}")
      Logger.info("Run 'azu help' to see available commands")
      exit(Config::EXIT_INVALID_USAGE)
    end
  end
end

AzuCLI.run
