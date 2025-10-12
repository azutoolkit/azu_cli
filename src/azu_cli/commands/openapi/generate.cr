require "../base"
require "../../openapi/code_generator"
require "option_parser"

module AzuCLI
  module Commands
    module OpenAPI
      # Generate code from OpenAPI specification
      class Generate < Base
        property spec_path : String = ""
        property force : Bool = false
        property models_only : Bool = false
        property endpoints_only : Bool = false

        def initialize
          super("openapi:generate", "Generate code from OpenAPI specification")
        end

        # Override parse_args to also trigger custom parsing
        def parse_args(args : Array(String))
          super(args)
          parse_arguments
        end

        def execute : Result
          parse_arguments

          # Validate spec path
          if @spec_path.empty?
            spec_arg = get_arg(0)
            if spec_arg.nil?
              return error("OpenAPI spec path is required. Usage: azu openapi:generate <spec_path>")
            end
            @spec_path = spec_arg
          end

          # Check if file exists
          unless File.exists?(@spec_path)
            return error("OpenAPI spec file not found: #{@spec_path}")
          end

          Logger.info("Parsing OpenAPI specification: #{@spec_path}")

          begin
            # Create code generator
            generator = AzuCLI::OpenAPI::CodeGenerator.new(@spec_path, @force)

            # Generate code based on flags
            if @models_only
              generator.generate_models
            elsif @endpoints_only
              generator.generate_endpoints
            else
              generator.generate_all
            end

            success("Code generation completed successfully")
          rescue ex : Exception
            Logger.error("Failed to generate code: #{ex.message}")
            error(ex.message || "Unknown error occurred")
          end
        end

        private def parse_arguments
          OptionParser.parse(get_args) do |parser|
            parser.banner = "Usage: azu openapi:generate <spec_path> [options]"

            parser.on("--spec PATH", "Path to OpenAPI specification file") { |path| @spec_path = path }
            parser.on("--force", "Overwrite existing files") { @force = true }
            parser.on("--models-only", "Generate only models") { @models_only = true }
            parser.on("--endpoints-only", "Generate only endpoints") { @endpoints_only = true }
            parser.on("--help", "Show help") {
              show_help
              exit(0)
            }
          end
        end

        def show_help
          puts "Usage: azu openapi:generate <spec_path> [options]"
          puts
          puts "Generate Crystal code from an OpenAPI 3.1 specification file."
          puts
          puts "Arguments:"
          puts "  <spec_path>           Path to OpenAPI specification file (YAML or JSON)"
          puts
          puts "Options:"
          puts "  --spec PATH           Path to OpenAPI specification file"
          puts "  --force               Overwrite existing files without prompting"
          puts "  --models-only         Generate only models from schemas"
          puts "  --endpoints-only      Generate only endpoints from paths"
          puts "  --help                Show this help message"
          puts
          puts "Examples:"
          puts "  azu openapi:generate openapi.yaml"
          puts "  azu openapi:generate api-spec.json --force"
          puts "  azu openapi:generate openapi.yaml --models-only"
          puts
          puts "The command will generate:"
          puts "  - Models in src/models/ from component schemas"
          puts "  - Endpoints in src/endpoints/ from paths"
          puts "  - Request classes in src/requests/ from request bodies"
          puts "  - Response classes in src/pages/ from responses"
          puts
          puts "Supported OpenAPI versions:"
          puts "  - OpenAPI 3.1.x"
          puts "  - OpenAPI 3.0.x (with limitations)"
        end
      end
    end
  end
end
