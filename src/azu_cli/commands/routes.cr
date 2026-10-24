require "./base"
require "../route_listing/table"
require "../route_listing/runner"

module AzuCLI
  module Commands
    # Lists the routes of the application in the current directory.
    class Routes < Base
      FORMATS      = ["table", "json"]
      OPTIONS      = ["format", "method", "path"]
      HTTP_METHODS = %w[CONNECT DELETE GET HEAD OPTIONS PATCH POST PUT TRACE WEBSOCKET]

      # Replaced in specs: the project's code has to be compiled to know its routes.
      class_property loader : Proc(String, Array(AzuCLI::RouteListing::Entry)) = ->(app_file : String) { AzuCLI::RouteListing::Runner.new(app_file).run }

      def initialize
        super("routes", "List the routes of the application")
      end

      def machine_output? : Bool
        true
      end

      def execute : Result
        return show_help_result if has_option?("help")
        if option = unknown_option(OPTIONS)
          return usage_error("Unknown option #{option}. Run 'azu routes --help'")
        end

        format = get_option("format", "table")
        return usage_error("Unknown format '#{format}': use #{FORMATS.join(" or ")}") unless FORMATS.includes?(format)

        method = has_option?("method") ? get_option("method") : nil
        if method && !HTTP_METHODS.includes?(method.upcase)
          return usage_error("Unknown HTTP method '#{method}': use one of #{HTTP_METHODS.join(", ")}")
        end

        app_file = app_file_path
        return Result.error("#{app_file} not found: run 'azu routes' in the root of an Azu project") unless File.exists?(app_file)

        table = AzuCLI::RouteListing::Table.new(self.class.loader.call(app_file)).filter(method: method, path: has_option?("path") ? get_option("path") : nil)
        stdout.puts(format == "json" ? table.to_json : table.to_text.chomp)
        success
      rescue ex : AzuCLI::RouteListing::Runner::Error
        Result.error(ex.message.to_s)
      end

      private def app_file_path : String
        "./src/#{Utils.project_name}.cr"
      end

      private def show_help_result : Result
        show_help
        success
      end

      def show_help
        stdout.puts <<-HELP
          Usage: azu routes [options]

          List the routes of the application: method, path, endpoint class, request and response types
          and the template helpers Azu registers for the endpoint. The application's code is compiled
          and loaded (the server is not started), so the first run takes as long as a build. That runs the
          top-level code of src/<project>.cr (initializers, .env loading, database connections); do not point
          it at a production environment.

          Options:
            --format FORMAT   table (default) or json
            --method METHOD   Only routes of this HTTP method (the HEAD and OPTIONS routes Azu adds are hidden unless asked for)
            --path TEXT       Only routes whose path contains TEXT
            --help            Show this help

          Exit codes: 0 success, 1 the application could not be loaded, 2 invalid usage.
        HELP
        stdout.puts
        stdout.puts "Examples:"
        show_examples
      end

      def show_examples
        stdout.puts "  azu routes"
        stdout.puts "  azu routes --method POST"
        stdout.puts "  azu routes --path /posts --format json"
      end
    end
  end
end
