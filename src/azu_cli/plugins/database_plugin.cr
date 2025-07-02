require "./base"

module AzuCLI
  module Plugins
    # Database plugin for database operations
    class DatabasePlugin < Base
      def initialize
        super("database", "Database operations plugin for Azu CLI", "1.0.0")
      end

      def before_command(command : Commands::Base, args : Array(String))
        return unless command.name == "db"

        # Validate database configuration
        validate_database_config
      end

      def after_command(command : Commands::Base, result : Commands::Result)
        return unless command.name == "db"

        if result.success?
          Logger.info("Database operation completed successfully")
        else
          Logger.error("Database operation failed: #{result.error}")
        end
      end

      def on_error(command : Commands::Base, error : Exception)
        return unless command.name == "db"

        Logger.error("Database plugin error: #{error.message}")

        # Provide helpful error messages based on error message content
        message = error.message || ""
        if message.includes?("connection") || message.includes?("connect")
          Logger.info("Check your database connection settings")
        elsif message.includes?("query") || message.includes?("SQL")
          Logger.info("Check your SQL syntax and database schema")
        elsif message.includes?("permission") || message.includes?("access")
          Logger.info("Check your database permissions")
        end
      end

      private def validate_database_config
        config = Config.instance

        unless config.database_url || config.database_name
          Logger.warn("Database configuration not found. Some operations may fail.")
          Logger.info("Set DATABASE_URL environment variable or configure database connection.")
          return
        end

        unless config.database_url
          Logger.warn("Database URL not configured. Set DATABASE_URL environment variable.")
        end
      end
    end
  end
end
