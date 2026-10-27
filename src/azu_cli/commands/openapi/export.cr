require "../base"
require "../../openapi/exporter"
require "option_parser"
require "yaml"
require "json"

module AzuCLI
  module Commands
    module OpenAPI
      # Writes the OpenAPI 3.1 document of the application in the current directory. The document is the one
      # `Azu::OpenAPI` builds from the endpoint contracts, so the application's code is compiled to get it.
      class Export < Base
        FORMATS = ["yaml", "json"]

        property output_path : String = "openapi.yaml"
        property format : String = "yaml"
        property project_name : String = ""
        property version : String = "1.0.0"

        # Replaced in specs: (app file, title, version) -> the document as JSON.
        class_property loader : Proc(String, String, String, String) = ->(app_file : String, title : String, version : String) do
          AzuCLI::OpenAPI::Exporter.new(app_file).run(title, version)
        end

        @help = false
        @usage_problem : String? = nil

        def initialize
          super("openapi:export", "Export the OpenAPI document of the application")
        end

        def parse_args(args : Array(String))
          super(args)
          parse_arguments
        end

        def execute : Result
          return show_help_result if @help
          @usage_problem.try { |problem| return usage_error(problem) }
          return usage_error("Unknown format '#{@format}': use #{FORMATS.join(" or ")}") unless FORMATS.includes?(@format)

          app_file = "./src/#{Utils.project_name}.cr"
          return Result.error("#{app_file} not found: run 'azu openapi:export' in the root of an Azu project") unless File.exists?(app_file)

          title = @project_name.empty? ? Utils.project_name : @project_name
          document = JSON.parse(self.class.loader.call(app_file, title, @version))
          File.write(@output_path, @format == "json" ? document.to_pretty_json + "\n" : document.to_yaml)
          stdout.puts "OpenAPI document written to #{@output_path}"
          success
        rescue ex : AzuCLI::OpenAPI::Exporter::Error
          Result.error(ex.message.to_s)
        end

        private def parse_arguments
          format_given = false
          OptionParser.parse(get_args) do |parser|
            parser.on("--output PATH", "Output file path") { |path| @output_path = path }
            parser.on("--format FORMAT", "Output format (yaml, json)") do |format|
              @format = format.downcase
              format_given = true
            end
            parser.on("--project NAME", "API title") { |name| @project_name = name }
            parser.on("--version VERSION", "API version") { |version| @version = version }
            parser.on("--help", "Show help") { @help = true }
            parser.invalid_option { |option| @usage_problem = "Unknown option #{option}. Run 'azu openapi:export --help'" }
            parser.missing_option { |option| @usage_problem = "#{option} needs a value" }
          end
          return if format_given
          case File.extname(@output_path)
          when ".json"         then @format = "json"
          when ".yaml", ".yml" then @format = "yaml"
          end
        end

        private def show_help_result : Result
          show_help
          success
        end

        def show_help
          stdout.puts <<-HELP
            Usage: azu openapi:export [options]

            Write the OpenAPI 3.1 document of the application: every route of an Azu::Endpoint (scopes and mounted
            apps included), its parameters, request bodies with their validation rules, and response schemas. The
            document is built by Azu::OpenAPI from the endpoint contracts, so the application's code is compiled
            and loaded (the server is not started); the first run takes as long as a build. That runs the top-level
            code of src/<project>.cr; do not point it at a production environment.

            Options:
              --output PATH       Output file [default: openapi.yaml]
              --format FORMAT     yaml or json [default: from the file extension, else yaml]
              --project NAME      API title [default: the shard name]
              --version VERSION   API version [default: 1.0.0]
              --help              Show this help

            Exit codes: 0 success, 1 the application could not be loaded, 2 invalid usage.

            Examples:
              azu openapi:export
              azu openapi:export --output docs/openapi.json
              azu openapi:export --project "Blog API" --version 2.0.0
            HELP
        end
      end
    end
  end
end
