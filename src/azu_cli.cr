require "log"
require "cadmium_inflector"
require "teeplate"
require "topia"

require "./azu_cli/config"
require "./azu_cli/config/**"
require "./azu_cli/logger"
require "./azu_cli/utils"
require "./azu_cli/openapi"
require "./azu_cli/generators/**"
require "./azu_cli/commands/base"
require "./azu_cli/commands/database"
require "./azu_cli/commands/db/**"
require "./azu_cli/commands/jobs"
require "./azu_cli/commands/jobs/**"
require "./azu_cli/commands/session/**"
require "./azu_cli/commands/openapi/**"
require "./azu_cli/commands/**"
require "./azu_cli/cli"
require "./azu_cli/plugins/**"
require "./azu_cli/middleware/**"
require "./azu_cli/validators/**"

module AzuCLI
  VERSION = "0.0.1"

  # Main CLI entry point using Topia
  def self.run
    # Initialize configuration and logging first
    Config.load!
    Logger.setup

    # Create and run the CLI
    cli = CLI.new
    cli.run(ARGV)
  rescue ex : Topia::Error
    Logger.error("Topia error: #{ex.message}")
    Logger.info("Run 'azu --help' to see available options")
    exit(Config::EXIT_INVALID_USAGE)
  rescue ex : Exception
    Logger.error("Critical error: #{ex.message}")
    Logger.debug("Stack trace: #{ex.backtrace?.try(&.join("\n")) || "No backtrace"}")
    exit(Config::EXIT_FAILURE)
  end
end

AzuCLI.run
