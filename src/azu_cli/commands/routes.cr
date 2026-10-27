require "./base"
require "../route_listing/table"
require "../route_listing/runner"

module AzuCLI
  module Commands
    # Lists the routes of the application in the current directory.
    class Routes < Base
      FORMATS      = ["table", "json"]
      OPTIONS      = ["format", "method", "path", "ui"]
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
        if format == "json"
          stdout.puts table.to_json
        elsif rich? && !table.entries.empty?
          show_card(table)
        else
          stdout.puts table.to_text.chomp
        end
        success
      rescue ex : AzuCLI::RouteListing::Runner::Error
        Result.error(ex.message.to_s)
      end

      VERB_TOKENS = {"GET" => UI::Token::Green, "POST" => UI::Token::Cyan, "PUT" => UI::Token::Amber, "PATCH" => UI::Token::Amber,
                     "DELETE" => UI::Token::Red, "WEBSOCKET" => UI::Token::Purple}

      # The routes as a card: the verb colored, the path, the endpoint and its request → response.
      private def show_card(table : AzuCLI::RouteListing::Table) : Nil
        rich = ui.as(UI::Rich)
        g = rich.terminal.glyphs
        prefix = Routes.shared_namespace(table.entries.map(&.endpoint))
        short = ->(name : String) { name.lchop(prefix) }
        rows = table.entries.map do |entry|
          types = entry.request.empty? ? "" : "#{short.call(entry.request)} #{g.pointer} #{short.call(entry.response)}"
          [UI::Seg[entry.method, VERB_TOKENS[entry.method]? || UI::Token::Muted, UI::Attr::Bold], UI::Seg[entry.path, UI::Token::Blue],
           UI::Seg[short.call(entry.endpoint)], UI::Seg[types, UI::Token::Muted]]
        end
        lines = UI::Table.new(["METHOD", "PATH", "ENDPOINT", "REQUEST #{g.pointer} RESPONSE"], rows).lines(rich.inner_width)
        count = table.entries.size
        lines << [] of UI::Seg << [UI::Seg["names under #{prefix.rchop("::")}", UI::Token::Muted]] unless prefix.empty?
        ui.panel("Routes #{g.dot} #{Utils.project_name}", lines, "#{count} #{count == 1 ? "route" : "routes"}")
      end

      # The first namespace every endpoint is under ("DemoApp::"), "" when they do not share one.
      def self.shared_namespace(names : Array(String)) : String
        first = names.first?.try { |name| name.split("::").first } || return ""
        names.all? { |name| name.starts_with?("#{first}::") } ? "#{first}::" : ""
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
            --ui MODE         rich (a card, the default on a terminal) or plain (the table)
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
