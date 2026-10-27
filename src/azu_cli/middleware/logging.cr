require "./base"

module AzuCLI
  module Middleware
    # Logging middleware for command execution
    class Logging < Base
      def before(command : Commands::Base, args : Array(String))
        return if command.machine_output?
        # Debug only: the command's own output says what it does (`--debug` shows these)
        Logger.debug("Executing command: #{command.name} with args: #{args.join(" ")}")
      end

      def after(command : Commands::Base, result : Commands::Result)
        if result.success?
          Logger.debug("Command #{command.name} completed successfully") unless command.machine_output?
        else
          Logger.debug("Command #{command.name} failed: #{result.error}") # the CLI prints the error itself
        end
      end

      def error(command : Commands::Base, error : Exception)
        Logger.error("Command #{command.name} encountered an error: #{error.message}")
        Logger.debug("Error backtrace: #{error.backtrace?.try(&.join("\n")) || "No backtrace"}")
      end
    end
  end
end
