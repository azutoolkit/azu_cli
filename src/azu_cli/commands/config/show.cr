require "../base"
require "yaml"
require "json"

module AzuCLI
  module Commands
    module Config
      # Show command for displaying current configuration
      class Show < Base
        property format : String = "yaml"
        property environment : String = AzuCLI::Config.instance.environment
        property section : String? = nil

        def initialize
          super("config:show", "Display current configuration")
        end

        def execute : Result
          parse_options

          Logger.info("Configuration (#{@environment} environment)")
          puts ""

          config = AzuCLI::Config.instance

          # Build configuration hash
          config_data = build_config_data(config)

          # Filter by section if specified
          if sect = @section
            if config_data.has_key?(sect)
              config_data = {sect => config_data[sect]}
            else
              return error("Unknown configuration section: #{sect}. Available sections: #{config_data.keys.join(", ")}")
            end
          end

          # Output in requested format
          case @format.downcase
          when "yaml", "yml"
            puts config_data.to_yaml
          when "json"
            puts config_data.to_pretty_json
          when "table"
            print_table(config_data)
          else
            return error("Unknown format: #{@format}. Use yaml, json, or table.")
          end

          success("Configuration displayed successfully")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--format", "-f"
              @format = args[index + 1]? || @format if index + 1 < args.size
            when "--env", "-e"
              @environment = args[index + 1]? || @environment if index + 1 < args.size
            when "--section", "-s"
              @section = args[index + 1]? if index + 1 < args.size
            when "--help", "-h"
              show_help
              exit(0)
            end
          end
        end

        private def build_config_data(config : AzuCLI::Config) : Hash(String, Hash(String, String))
          {
            "global" => {
              "debug_mode"  => config.debug_mode.to_s,
              "verbose"     => config.verbose.to_s,
              "quiet"       => config.quiet.to_s,
              "environment" => config.environment,
              "config_file" => config.config_file_path || "(none)",
            },
            "project" => {
              "project_name"     => config.project_name.empty? ? "(not set)" : config.project_name,
              "project_path"     => config.project_path,
              "database_adapter" => config.database_adapter,
              "template_engine"  => config.template_engine,
            },
            "server" => {
              "host"    => config.dev_server_host,
              "port"    => config.dev_server_port.to_s,
              "watch"   => config.dev_server_watch?.to_s,
              "rebuild" => config.dev_server_rebuild?.to_s,
            },
            "database" => {
              "host"     => config.database_host,
              "port"     => config.database_port.to_s,
              "user"     => config.database_user,
              "password" => config.database_password.empty? ? "(not set)" : "********",
              "name"     => config.database_name || "(not set)",
              "url"      => config.database_url ? "********" : "(not set)",
            },
            "paths" => {
              "templates_path" => config.templates_path,
              "output_path"    => config.output_path,
            },
            "logging" => {
              "log_level"  => config.log_level.to_s,
              "log_format" => config.log_format,
            },
          }
        end

        private def print_table(data : Hash(String, Hash(String, String)))
          data.each do |section, values|
            puts "#{section.upcase}"
            puts "-" * 40
            values.each do |key, value|
              puts "  #{key.ljust(20)} #{value}"
            end
            puts ""
          end
        end

        def show_help
          puts "Usage: azu config:show [options]"
          puts ""
          puts "Display current Azu CLI configuration."
          puts ""
          puts "Options:"
          puts "  --format, -f FORMAT   Output format (yaml, json, table) [default: yaml]"
          puts "  --env, -e ENV         Environment to show [default: current]"
          puts "  --section, -s SECTION Show specific section only"
          puts "  --help, -h            Show this help message"
          puts ""
          puts "Sections:"
          puts "  global    - Global CLI settings"
          puts "  project   - Project configuration"
          puts "  server    - Development server settings"
          puts "  database  - Database configuration"
          puts "  paths     - File paths"
          puts "  logging   - Logging configuration"
          puts ""
          puts "Examples:"
          puts "  azu config:show"
          puts "  azu config:show --format json"
          puts "  azu config:show --section database"
          puts "  azu config:show --env production"
        end
      end
    end
  end
end
