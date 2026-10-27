require "./base"
require "../app_config/table"
require "../app_config/runner"

module AzuCLI
  module Commands
    # Shows the effective configuration of the application in the current directory.
    class Config < Base
      FORMATS = ["table", "json"]
      OPTIONS = ["format", "section", "ui"]

      # Replaced in specs: the project's code has to be compiled to know what it is configured with.
      class_property loader : Proc(String, Array(AzuCLI::AppConfig::Setting)) = ->(app_file : String) { AzuCLI::AppConfig::Runner.new(app_file).run }

      def initialize
        super("config", "Show the configuration of the application")
      end

      def machine_output? : Bool
        true
      end

      def execute : Result
        return show_help_result if has_option?("help")
        if option = unknown_option(OPTIONS)
          return usage_error("Unknown option #{option}. Run 'azu config --help'")
        end

        format = get_option("format", "table")
        return usage_error("Unknown format '#{format}': use #{FORMATS.join(" or ")}") unless FORMATS.includes?(format)

        app_file = app_file_path
        return Result.error("#{app_file} not found: run 'azu config' in the root of an Azu project") unless File.exists?(app_file)

        all = AzuCLI::AppConfig::Table.new(self.class.loader.call(app_file))
        section = has_option?("section") ? get_option("section") : nil
        table = all.filter(section)
        if section && table.settings.empty?
          return usage_error("Unknown section '#{section}': use #{all.sections.join(", ")}")
        end

        if format == "json"
          stdout.puts table.to_json
        elsif rich?
          show_card(table)
        else
          stdout.puts table.to_text.chomp
        end
        success
      rescue ex : AzuCLI::AppConfig::Runner::Error
        Result.error(ex.message.to_s)
      end

      # The settings as a card: a heading per section, the keys muted, a missing secret in amber.
      private def show_card(table : AzuCLI::AppConfig::Table) : Nil
        width = table.settings.max_of(&.key.size)
        lines = [] of Array(UI::Seg)
        table.sections.each_with_index do |section, index|
          lines << [] of UI::Seg if index > 0
          lines << [UI::Seg[section, UI::Token::Purple, UI::Attr::Bold]]
          table.settings.each do |setting|
            next unless setting.section == section

            token = setting.value == "not set" ? UI::Token::Amber : UI::Token::Text
            lines << [UI::Seg["  #{setting.key.ljust(width)}  ", UI::Token::Muted], UI::Seg[setting.value, token]]
          end
        end
        ui.panel("Configuration #{ui.as(UI::Rich).terminal.glyphs.dot} #{Utils.project_name}", lines, "CRYSTAL_ENV=#{ENV["CRYSTAL_ENV"]? || "development"}")
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
          Usage: azu config [options]

          Show the effective configuration of the application: the server, TLS, templates, database,
          limits, uploads, WebSocket, i18n and asset settings Azu holds once your code and your .env files
          are loaded. The application's code is compiled and loaded (the server is not started), so the
          first run takes as long as a build. That runs the top-level code of src/<project>.cr
          (initializers, .env loading, database connections); do not point it at a production environment.

          Nothing secret is printed: the password of DATABASE_URL is masked, and CSRF_SECRET and
          SESSION_SECRET are shown only as set or not set.

          Options:
            --format FORMAT   table (default) or json
            --section NAME    Only one section, such as server, database or limits
            --ui MODE         rich (a card, the default on a terminal) or plain (the table)
            --help            Show this help

          Use CRYSTAL_ENV=production azu config to see another environment (its .env.production
          is loaded, as it is for the app).

          Exit codes: 0 success, 1 the application could not be loaded, 2 invalid usage.
        HELP
        stdout.puts
        stdout.puts "Examples:"
        show_examples
      end

      def show_examples
        stdout.puts "  azu config"
        stdout.puts "  azu config --section database"
        stdout.puts "  azu config --format json"
      end
    end
  end
end
