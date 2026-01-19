require "../base"

module AzuCLI
  module Commands
    module Config
      # Env command for environment variable management
      class Env < Base
        property list : Bool = false
        property show_values : Bool = false
        property set_var : String? = nil
        property unset_var : String? = nil

        # Known Azu environment variables
        AZU_ENV_VARS = [
          {"AZU_ENV", "Environment name (development, test, production)"},
          {"AZU_DEBUG", "Enable debug mode"},
          {"AZU_VERBOSE", "Enable verbose output"},
          {"AZU_QUIET", "Suppress non-error output"},
          {"AZU_HOST", "Development server host"},
          {"AZU_PORT", "Development server port"},
          {"AZU_DB_HOST", "Database host"},
          {"AZU_DB_PORT", "Database port"},
          {"AZU_DB_USER", "Database user"},
          {"AZU_DB_PASSWORD", "Database password"},
          {"AZU_DB_NAME", "Database name"},
          {"DATABASE_URL", "Full database connection URL"},
          {"AZU_TEMPLATES_PATH", "Path to template files"},
          {"AZU_OUTPUT_PATH", "Default output directory"},
        ]

        def initialize
          super("config:env", "Environment variable management")
        end

        def execute : Result
          parse_options

          # Handle set operation
          if var = @set_var
            return set_environment_variable(var)
          end

          # Handle unset operation
          if var = @unset_var
            return unset_environment_variable(var)
          end

          # Default: list variables
          if @show_values
            show_current_values
          else
            list_variables
          end

          success("Environment variables displayed")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--list", "-l"
              @list = true
            when "--show", "-s"
              @show_values = true
            when "--set"
              @set_var = args[index + 1]? if index + 1 < args.size
            when "--unset"
              @unset_var = args[index + 1]? if index + 1 < args.size
            when "--help", "-h"
              show_help
              exit(0)
            end
          end

          # If no flags provided, default to list
          @list = true if !@show_values && @set_var.nil? && @unset_var.nil?
        end

        private def list_variables
          Logger.info("Azu CLI Environment Variables")
          puts ""
          puts "Variable                 Description"
          puts "-" * 60

          AZU_ENV_VARS.each do |name, description|
            puts "#{name.ljust(24)} #{description}"
          end

          puts ""
          puts "Use --show to see current values"
          puts "Use --set VAR=VALUE to set a variable"
          puts "Use --unset VAR to unset a variable"
        end

        private def show_current_values
          Logger.info("Current Environment Variable Values")
          puts ""
          puts "Variable                 Value"
          puts "-" * 60

          AZU_ENV_VARS.each do |name, _|
            value = ENV[name]?
            display_value = if value.nil?
                              "(not set)"
                            elsif name.includes?("PASSWORD") || name.includes?("SECRET")
                              "********"
                            else
                              value
                            end
            puts "#{name.ljust(24)} #{display_value}"
          end

          puts ""
        end

        private def set_environment_variable(var_assignment : String) : Result
          unless var_assignment.includes?("=")
            return error("Invalid format. Use: --set VAR=VALUE")
          end

          parts = var_assignment.split("=", 2)
          var_name = parts[0].upcase
          var_value = parts[1]

          # Validate variable name
          unless AZU_ENV_VARS.any? { |v| v[0] == var_name }
            Logger.warn("'#{var_name}' is not a known Azu environment variable")
          end

          # Write to .env file
          env_file = ".env"
          env_content = File.exists?(env_file) ? File.read(env_file) : ""

          # Update or add the variable
          lines = env_content.lines
          found = false

          lines = lines.map do |line|
            if line.starts_with?("#{var_name}=")
              found = true
              "#{var_name}=#{var_value}"
            else
              line
            end
          end

          unless found
            lines << "#{var_name}=#{var_value}"
          end

          File.write(env_file, lines.join("\n") + "\n")

          Logger.success("Set #{var_name} in #{env_file}")
          Logger.info("Note: You may need to restart your shell or source the .env file")

          success("Environment variable set")
        end

        private def unset_environment_variable(var_name : String) : Result
          var_name = var_name.upcase

          env_file = ".env"
          unless File.exists?(env_file)
            return error("No .env file found")
          end

          env_content = File.read(env_file)
          lines = env_content.lines.reject { |line| line.starts_with?("#{var_name}=") }

          if lines.size == env_content.lines.size
            Logger.warn("Variable #{var_name} not found in #{env_file}")
          else
            File.write(env_file, lines.join("\n") + "\n")
            Logger.success("Removed #{var_name} from #{env_file}")
          end

          success("Environment variable unset")
        end

        def show_help
          puts "Usage: azu config:env [options]"
          puts ""
          puts "Manage Azu CLI environment variables."
          puts ""
          puts "Options:"
          puts "  --list, -l          List all known environment variables"
          puts "  --show, -s          Show current values of environment variables"
          puts "  --set VAR=VALUE     Set an environment variable in .env"
          puts "  --unset VAR         Remove an environment variable from .env"
          puts "  --help, -h          Show this help message"
          puts ""
          puts "Examples:"
          puts "  azu config:env --list"
          puts "  azu config:env --show"
          puts "  azu config:env --set AZU_PORT=4000"
          puts "  azu config:env --set DATABASE_URL=postgres://localhost/mydb"
          puts "  azu config:env --unset AZU_DEBUG"
        end
      end
    end
  end
end
