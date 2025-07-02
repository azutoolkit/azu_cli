require "./base"

module AzuCLI
  module Middleware
    # Configuration middleware
    class Configuration < Base
      def before(command : Commands::Base, args : Array(String))
        # Ensure configuration is loaded
        Config.load!

        # Validate configuration for specific commands
        validate_configuration_for_command(command)
      end

      private def validate_configuration_for_command(command : Commands::Base)
        case command.name
        when "generate"
          validate_generator_configuration
        when "db"
          validate_database_configuration
        when "serve"
          validate_server_configuration
        end
      end

      private def validate_generator_configuration
        # ... existing code ...
      end

      private def validate_database_configuration
        config = Config.instance
        unless config.database_url || config.database_name
          Logger.warn("Database configuration not found. Some database commands may fail.")
          Logger.info("Set DATABASE_URL environment variable or configure database_name in config file.")
        end
      end

      private def validate_server_configuration
        config = Config.instance
        if config.dev_server_port < 1 || config.dev_server_port > 65535
          Logger.warn("Invalid server port: #{config.dev_server_port}. Using default port 3000.")
        end
      end
    end
  end
end
