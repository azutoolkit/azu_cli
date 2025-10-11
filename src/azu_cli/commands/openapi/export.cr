require "../base"
require "../../openapi/spec_builder"
require "option_parser"
require "yaml"
require "json"

module AzuCLI
  module Commands
    module OpenAPI
      # Export OpenAPI specification from code
      class Export < Base
        property output_path : String = "openapi.yaml"
        property format : String = "yaml"
        property project_name : String = ""
        property version : String = "1.0.0"

        def initialize
          super("openapi:export", "Export OpenAPI specification from code")
        end

        def execute : Result
          parse_arguments

          # Get project name from shard.yml if not provided
          if @project_name.empty?
            @project_name = get_project_name
          end

          Logger.info("Building OpenAPI specification from code...")

          begin
            # Create spec builder
            builder = AzuCLI::OpenAPI::SpecBuilder.new(@project_name, @version)

            # Build spec
            spec = builder.build

            # Write to file based on format
            write_spec(spec)

            Logger.success("✓ OpenAPI specification exported to: #{@output_path}")
            success("OpenAPI specification exported successfully")
          rescue ex : Exception
            Logger.error("Failed to export OpenAPI spec: #{ex.message}")
            error(ex.message || "Unknown error occurred")
          end
        end

        private def parse_arguments
          OptionParser.parse(get_args) do |parser|
            parser.banner = "Usage: azu openapi:export [options]"

            parser.on("--output PATH", "Output file path") { |path| @output_path = path }
            parser.on("--format FORMAT", "Output format (yaml, json)") { |fmt| @format = fmt.downcase }
            parser.on("--project NAME", "Project name") { |name| @project_name = name }
            parser.on("--version VERSION", "API version") { |ver| @version = ver }
            parser.on("--help", "Show help") {
              show_help
              exit(0)
            }
          end

          # Auto-detect format from file extension if not specified
          if @output_path.ends_with?(".json")
            @format = "json"
          elsif @output_path.ends_with?(".yaml") || @output_path.ends_with?(".yml")
            @format = "yaml"
          end
        end

        # Write spec to file
        private def write_spec(spec : AzuCLI::OpenAPI::Spec)
          case @format
          when "json"
            File.write(@output_path, spec.to_json)
          when "yaml", "yml"
            File.write(@output_path, spec.to_yaml)
          else
            raise "Unsupported format: #{@format}. Use 'yaml' or 'json'"
          end
        end

        # Get project name from shard.yml
        private def get_project_name : String
          if File.exists?("shard.yml")
            shard_yml = YAML.parse(File.read("shard.yml"))
            return shard_yml["name"].as_s
          end
          "api"
        rescue
          "api"
        end

        def show_help
          puts "Usage: azu openapi:export [options]"
          puts
          puts "Export OpenAPI 3.1 specification from your Crystal code."
          puts
          puts "Options:"
          puts "  --output PATH          Output file path [default: openapi.yaml]"
          puts "  --format FORMAT        Output format: yaml or json [default: yaml]"
          puts "  --project NAME         Project name (auto-detected from shard.yml)"
          puts "  --version VERSION      API version [default: 1.0.0]"
          puts "  --help                 Show this help message"
          puts
          puts "Examples:"
          puts "  azu openapi:export"
          puts "  azu openapi:export --output api-spec.json --format json"
          puts "  azu openapi:export --output docs/openapi.yaml --version 2.0.0"
          puts
          puts "The command will analyze:"
          puts "  - Endpoints in src/endpoints/"
          puts "  - Models in src/models/"
          puts "  - Request classes in src/requests/"
          puts "  - Response classes in src/pages/"
          puts
          puts "And generate a complete OpenAPI 3.1 specification."
        end
      end
    end
  end
end

