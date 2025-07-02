require "./base"

module AzuCLI
  module Middleware
    # Error handling middleware
    class ErrorHandler < Base
      def error(command : Commands::Base, error : Exception)
        case error
        when ArgumentError
          Logger.error("Invalid argument: #{error.message}")
          Logger.info("Run 'azu #{command.name} --help' for usage information")
        when File::NotFoundError
          Logger.error("File not found: #{error.message}")
        when File::AccessDeniedError
          Logger.error("Permission denied: #{error.message}")
        else
          Logger.error("Unexpected error: #{error.message}")
          Logger.debug("Error type: #{error.class}")
        end
      end
    end
  end
end
