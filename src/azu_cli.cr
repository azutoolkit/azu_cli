require "topia"
require "log"
require "cadmium_inflector"
require "teeplate"

require "./azu_cli/config"
require "./azu_cli/logger"
require "./azu_cli/command"
require "./azu_cli/commands/topia_adapter"
require "./azu_cli/commands/**"
require "./azu_cli/templates/**"
require "./azu_cli/generators/**"
require "./azu_cli/utils"

module AzuCLI
  VERSION = "0.0.1"

  # Register all commands with Topia
  Topia.task("help").pipe(TopiaAdapter.new(Commands::Help.new))
  Topia.task("version").pipe(TopiaAdapter.new(Commands::Version.new))
  Topia.task("new").pipe(TopiaAdapter.new(Commands::New.new))
  Topia.task("init").pipe(TopiaAdapter.new(Commands::Init.new))

  def self.run
    # Initialize configuration
    Config.load!

    # Set up logging
    Logger.setup

    # Run Topia CLI with arguments
    if ARGV.empty?
      # Show help when no arguments provided
      Topia.run("help")
    else
      command_name = ARGV[0]
      command_args = ARGV[1..]

      begin
        Topia.run(command_name, command_args)
      rescue
        Logger.error("Unknown command: #{command_name}")
        Logger.info("Run 'azu help' to see available commands")
        exit(Config::EXIT_INVALID_USAGE)
      end
    end
  rescue ex : Exception
    Logger.error("Unexpected error: #{ex.message}")
    Logger.debug(ex.backtrace?.try(&.join("\n")) || "No backtrace available")
    exit(1)
  end
end

# Start the CLI
AzuCLI.run
