require "./base"

module AzuCLI
  module Plugins
    # Development plugin for development server operations
    class DevelopmentPlugin < Base
      def initialize
        super("development", "Development server plugin for Azu CLI", "1.0.0")
      end

      def before_command(command : Commands::Base, args : Array(String))
        case command.name
        when "serve", "dev"
          validate_development_config
        end
      end

      def after_command(command : Commands::Base, result : Commands::Result)
        case command.name
        when "serve", "dev"
          if result.success?
            Logger.info("Development server started successfully")
          else
            Logger.error("Development server failed to start: #{result.error}")
          end
        end
      end

      def on_error(command : Commands::Base, error : Exception)
        case command.name
        when "serve", "dev"
          Logger.error("Development plugin error: #{error.message}")

          if error.message.try(&.includes?("bind")) || error.message.try(&.includes?("port"))
            Logger.info("Port may be in use. Try a different port with --port option.")
          elsif error.is_a?(File::NotFoundError)
            Logger.info("Source files not found. Check your project structure.")
          end
        end
      end

      private def validate_development_config
        config = Config.instance

        # Validate port configuration
        if config.dev_server_port < 1024 || config.dev_server_port > 65535
          Logger.warn("Invalid port number: #{config.dev_server_port}. Using default port 3000.")
        end

        # Validate host configuration
        if config.dev_server_host.empty?
          Logger.warn("Empty host configuration. Using default host 'localhost'.")
        end
      end
    end
  end
end
