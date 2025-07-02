require "./base"

module AzuCLI
  module Middleware
    # Logging middleware for command execution
    class Logging < Base
      def before(command : Commands::Base, args : Array(String))
        Logger.info("Executing command: #{command.name} with args: #{args.join(" ")}")
      end

      def after(command : Commands::Base, result : Commands::Result)
        if result.success?
          Logger.info("Command #{command.name} completed successfully")
        else
          Logger.error("Command #{command.name} failed: #{result.error}")
        end
      end

      def error(command : Commands::Base, error : Exception)
        Logger.error("Command #{command.name} encountered an error: #{error.message}")
        Logger.debug("Error backtrace: #{error.backtrace?.try(&.join("\n")) || "No backtrace"}")
      end
    end
  end
end
