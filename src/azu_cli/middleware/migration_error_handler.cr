require "../logger"

module AzuCLI
  module Middleware
    # Handles migration errors with detailed reporting and remediation suggestions
    class MigrationErrorHandler
      property error_log_path : String
      property recovery_scripts_dir : String

      def initialize(@error_log_path : String = "./log/migration_errors.log", @recovery_scripts_dir : String = "./tmp/migration_recovery")
        ensure_directories_exist
      end

      # Handle a migration error with detailed analysis
      def handle_error(error : Exception, migration_name : String, migration_version : Int64) : String
        error_type = classify_error(error)
        error_details = extract_error_details(error)

        # Log the error
        log_error(error, migration_name, migration_version, error_type, error_details)

        # Generate recovery suggestions
        recovery_suggestions = generate_recovery_suggestions(error_type, error_details)

        # Create recovery script if possible
        recovery_script = create_recovery_script(error_type, error_details, migration_name, migration_version)

        # Return formatted error report
        format_error_report(error_type, error_details, recovery_suggestions, recovery_script)
      end

      # Classify the type of error
      private def classify_error(error : Exception) : String
        message = error.message || ""

        case
        when message.includes?("connection") || message.includes?("connect")
          "connection"
        when message.includes?("permission") || message.includes?("access") || message.includes?("denied")
          "permission"
        when message.includes?("constraint") || message.includes?("violation") || message.includes?("duplicate")
          "constraint"
        when message.includes?("timeout") || message.includes?("timed out")
          "timeout"
        when message.includes?("syntax") || message.includes?("SQL") || message.includes?("invalid")
          "syntax"
        when message.includes?("table") && message.includes?("not exist")
          "missing_table"
        when message.includes?("column") && message.includes?("not exist")
          "missing_column"
        when message.includes?("foreign key") || message.includes?("reference")
          "foreign_key"
        when message.includes?("unique") || message.includes?("duplicate key")
          "unique_constraint"
        else
          "unknown"
        end
      end

      # Extract detailed error information
      private def extract_error_details(error : Exception) : Hash(String, String)
        details = {
          "message"   => error.message || "Unknown error",
          "class"     => error.class.name,
          "backtrace" => error.backtrace?.try(&.join("\n")) || "No backtrace available",
        }

        # Extract additional details based on error type
        message = error.message || ""

        if message.includes?("table")
          if match = message.match(/table "?([^"\s]+)"?/)
            details["table_name"] = match[1]
          end
        end

        if message.includes?("column")
          if match = message.match(/column "?([^"\s]+)"?/)
            details["column_name"] = match[1]
          end
        end

        if message.includes?("constraint")
          if match = message.match(/constraint "?([^"\s]+)"?/)
            details["constraint_name"] = match[1]
          end
        end

        details
      end

      # Generate recovery suggestions based on error type
      private def generate_recovery_suggestions(error_type : String, error_details : Hash(String, String)) : Array(String)
        suggestions = [] of String

        case error_type
        when "connection"
          suggestions << "Check database connection settings"
          suggestions << "Verify database server is running"
          suggestions << "Check network connectivity"
          suggestions << "Verify credentials in DATABASE_URL"
        when "permission"
          suggestions << "Check database user permissions"
          suggestions << "Ensure user has CREATE, DROP, ALTER privileges"
          suggestions << "Run: GRANT ALL PRIVILEGES ON DATABASE #{error_details["database_name"]? || "your_database"} TO #{error_details["username"]? || "your_user"}"
        when "constraint"
          suggestions << "Check for data that violates the constraint"
          suggestions << "Clean up conflicting data before running migration"
          suggestions << "Consider making the constraint less restrictive temporarily"
        when "timeout"
          suggestions << "Increase database timeout settings"
          suggestions << "Consider running migration in smaller batches"
          suggestions << "Check for long-running transactions"
        when "syntax"
          suggestions << "Review migration SQL syntax"
          suggestions << "Check for database-specific syntax issues"
          suggestions << "Verify migration file format"
        when "missing_table"
          table_name = error_details["table_name"]?
          if table_name
            suggestions << "Table '#{table_name}' does not exist"
            suggestions << "Create the table first or check migration order"
            suggestions << "Run: CREATE TABLE #{table_name} (...)"
          end
        when "missing_column"
          column_name = error_details["column_name"]?
          table_name = error_details["table_name"]?
          if column_name && table_name
            suggestions << "Column '#{column_name}' does not exist in table '#{table_name}'"
            suggestions << "Add the column first: ALTER TABLE #{table_name} ADD COLUMN #{column_name} ..."
          end
        when "foreign_key"
          suggestions << "Check foreign key references"
          suggestions << "Ensure referenced tables and columns exist"
          suggestions << "Verify data integrity before adding foreign key"
        when "unique_constraint"
          suggestions << "Check for duplicate values"
          suggestions << "Remove duplicates before adding unique constraint"
          suggestions << "Consider adding a partial unique index instead"
        else
          suggestions << "Review error message for specific details"
          suggestions << "Check migration file syntax and logic"
          suggestions << "Consider running migration manually to debug"
        end

        suggestions
      end

      # Create a recovery script for the error
      private def create_recovery_script(error_type : String, error_details : Hash(String, String), migration_name : String, migration_version : Int64) : String?
        script_content = String.build do |io|
          io << "# Recovery script for migration error\n"
          io << "# Migration: #{migration_name} (#{migration_version})\n"
          io << "# Error Type: #{error_type}\n"
          io << "# Generated: #{Time.utc}\n\n"

          case error_type
          when "permission"
            io << "# Grant necessary permissions\n"
            io << "# GRANT ALL PRIVILEGES ON DATABASE your_database TO your_user;\n"
            io << "# GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO your_user;\n"
          when "constraint"
            io << "# Check for constraint violations\n"
            io << "# SELECT * FROM your_table WHERE constraint_condition;\n"
            io << "# DELETE FROM your_table WHERE constraint_condition;\n"
          when "missing_table"
            table_name = error_details["table_name"]?
            if table_name
              io << "# Create missing table\n"
              io << "# CREATE TABLE #{table_name} (\n"
              io << "#   id SERIAL PRIMARY KEY,\n"
              io << "#   -- add other columns as needed\n"
              io << "# );\n"
            end
          when "missing_column"
            column_name = error_details["column_name"]?
            table_name = error_details["table_name"]?
            if column_name && table_name
              io << "# Add missing column\n"
              io << "# ALTER TABLE #{table_name} ADD COLUMN #{column_name} VARCHAR(255);\n"
            end
          else
            io << "# Manual recovery steps needed\n"
            io << "# Review the error and apply appropriate fixes\n"
          end
        end

        script_path = File.join(@recovery_scripts_dir, "recovery_#{migration_version}_#{Time.utc.to_unix}.sql")
        File.write(script_path, script_content)
        script_path
      end

      # Log error to file
      private def log_error(error : Exception, migration_name : String, migration_version : Int64, error_type : String, error_details : Hash(String, String))
        log_entry = String.build do |io|
          io << "[#{Time.utc}] Migration Error\n"
          io << "Migration: #{migration_name} (#{migration_version})\n"
          io << "Error Type: #{error_type}\n"
          io << "Error Class: #{error.class.name}\n"
          io << "Message: #{error.message}\n"
          io << "Backtrace:\n#{error.backtrace?.try(&.join("\n")) || "None"}\n"
          io << "Details: #{error_details}\n"
          io << "#{"=" * 80}\n\n"
        end

        File.open(@error_log_path, "a") do |file|
          file << log_entry
        end
      end

      # Format error report for display
      private def format_error_report(error_type : String, error_details : Hash(String, String), recovery_suggestions : Array(String), recovery_script : String?) : String
        String.build do |io|
          io << "Migration Error Report\n"
          io << "=" * 50 << "\n"
          io << "Error Type: #{error_type}\n"
          io << "Message: #{error_details["message"]}\n\n"

          io << "Recovery Suggestions:\n"
          recovery_suggestions.each_with_index do |suggestion, index|
            io << "  #{index + 1}. #{suggestion}\n"
          end

          if recovery_script
            io << "\nRecovery script created: #{recovery_script}\n"
            io << "Review and execute the script to fix the issue.\n"
          end

          io << "\nFor more details, check the error log: #{@error_log_path}\n"
        end
      end

      # Ensure required directories exist
      private def ensure_directories_exist
        FileUtils.mkdir_p(File.dirname(@error_log_path))
        FileUtils.mkdir_p(@recovery_scripts_dir)
      end
    end
  end
end
