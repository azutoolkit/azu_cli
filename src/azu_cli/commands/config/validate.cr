require "../base"

module AzuCLI
  module Commands
    module Config
      # Validate command for validating configuration files
      class Validate < Base
        property environment : String = AzuCLI::Config.instance.environment
        property strict : Bool = false
        property config_path : String? = nil

        def initialize
          super("config:validate", "Validate configuration files")
        end

        def execute : Result
          parse_options

          Logger.info("Validating configuration...")
          puts ""

          errors = [] of String
          warnings = [] of String

          # Check configuration file exists
          config = AzuCLI::Config.instance

          if path = @config_path || config.config_file_path
            if File.exists?(path)
              Logger.success("  Configuration file found: #{path}")
              validate_config_file(path, errors, warnings)
            else
              errors << "Configuration file not found: #{path}"
            end
          else
            warnings << "No configuration file specified or found"
          end

          # Validate paths
          validate_paths(config, errors, warnings)

          # Validate database configuration
          validate_database(config, errors, warnings)

          # Validate server configuration
          validate_server(config, errors, warnings)

          # In strict mode, treat warnings as errors
          if @strict
            errors.concat(warnings)
            warnings.clear
          end

          # Display results
          puts ""

          if errors.empty? && warnings.empty?
            Logger.success("Configuration is valid!")
            return success("Configuration validation passed")
          end

          unless warnings.empty?
            Logger.warn("Warnings (#{warnings.size}):")
            warnings.each { |w| puts "  - #{w}" }
            puts ""
          end

          unless errors.empty?
            Logger.error("Errors (#{errors.size}):")
            errors.each { |e| puts "  - #{e}" }
            puts ""
            return error("Configuration validation failed with #{errors.size} error(s)")
          end

          success("Configuration validation completed with #{warnings.size} warning(s)")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--env", "-e"
              @environment = args[index + 1]? || @environment if index + 1 < args.size
            when "--strict", "-s"
              @strict = true
            when "--config", "-c"
              @config_path = args[index + 1]? if index + 1 < args.size
            when "--help", "-h"
              show_help
              exit(0)
            end
          end
        end

        private def validate_config_file(path : String, errors : Array(String), warnings : Array(String))
          begin
            content = File.read(path)
            YAML.parse(content)
            Logger.success("  Configuration file syntax is valid")
          rescue ex : YAML::ParseException
            errors << "Invalid YAML syntax in #{path}: #{ex.message}"
          rescue ex : Exception
            errors << "Error reading configuration file: #{ex.message}"
          end
        end

        private def validate_paths(config : AzuCLI::Config, errors : Array(String), warnings : Array(String))
          # Check templates path
          if Dir.exists?(config.templates_path)
            Logger.success("  Templates path exists: #{config.templates_path}")
          else
            warnings << "Templates path does not exist: #{config.templates_path}"
          end

          # Check output path
          if Dir.exists?(config.output_path)
            Logger.success("  Output path exists: #{config.output_path}")
          else
            warnings << "Output path does not exist: #{config.output_path}"
          end

          # Check standard project directories if in a project
          if File.exists?("shard.yml")
            check_project_directory("src", warnings)
            check_project_directory("spec", warnings)
            check_project_directory("config", warnings)
          end
        end

        private def check_project_directory(dir : String, warnings : Array(String))
          unless Dir.exists?(dir)
            warnings << "Standard project directory missing: #{dir}"
          end
        end

        private def validate_database(config : AzuCLI::Config, errors : Array(String), warnings : Array(String))
          # Validate database adapter
          valid_adapters = ["postgresql", "mysql", "sqlite", "sqlite3"]
          unless valid_adapters.includes?(config.database_adapter)
            warnings << "Unknown database adapter: #{config.database_adapter}"
          end

          # Validate port range
          if config.database_port < 1 || config.database_port > 65535
            errors << "Invalid database port: #{config.database_port}"
          end

          # Check for database URL or individual settings
          if config.database_url.nil? && config.database_name.nil?
            warnings << "No database URL or name configured"
          end
        end

        private def validate_server(config : AzuCLI::Config, errors : Array(String), warnings : Array(String))
          # Validate port range
          if config.dev_server_port < 1 || config.dev_server_port > 65535
            errors << "Invalid server port: #{config.dev_server_port}"
          end

          # Check for reserved ports
          if config.dev_server_port < 1024
            warnings << "Server port #{config.dev_server_port} is a privileged port (requires root)"
          end

          # Validate host
          valid_hosts = ["localhost", "127.0.0.1", "::1", "0.0.0.0"]
          unless valid_hosts.includes?(config.dev_server_host) || config.dev_server_host.matches?(/^\d+\.\d+\.\d+\.\d+$/)
            warnings << "Non-standard server host: #{config.dev_server_host}"
          end
        end

        def show_help
          puts "Usage: azu config:validate [options]"
          puts ""
          puts "Validate Azu CLI configuration files."
          puts ""
          puts "Options:"
          puts "  --env, -e ENV       Environment to validate [default: current]"
          puts "  --strict, -s        Treat warnings as errors"
          puts "  --config, -c PATH   Path to configuration file"
          puts "  --help, -h          Show this help message"
          puts ""
          puts "Examples:"
          puts "  azu config:validate"
          puts "  azu config:validate --strict"
          puts "  azu config:validate --env production"
          puts "  azu config:validate --config ./custom-config.yml"
        end
      end
    end
  end
end
