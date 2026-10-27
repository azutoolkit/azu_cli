require "./base"
require "../diagnostics/checks"
require "../diagnostics/report"

module AzuCLI
  module Commands
    # Diagnoses the environment the project runs in. Exit code 1 when a check fails (warnings do not fail).
    class Doctor < Base
      OPTIONS = ["json", "ui"]

      # The machine and the environment the checks look at; replaced in specs.
      class_property system : AzuCLI::Diagnostics::System = AzuCLI::Diagnostics::LocalSystem.new
      class_property environment : String -> String? = ->(name : String) { ENV[name]? }

      def initialize
        super("doctor", "Check the Crystal toolchain, dependencies, database, environment and port")
      end

      def machine_output? : Bool
        true
      end

      def execute : Result
        return show_help_result if has_option?("help")
        if option = unknown_option(OPTIONS)
          return usage_error("Unknown option #{option}. Run 'azu doctor --help'")
        end

        report = AzuCLI::Diagnostics::Report.new(AzuCLI::Diagnostics::Checks.new(Dir.current, self.class.environment, self.class.system).run)
        if has_option?("json")
          stdout.puts report.to_json
        elsif rich?
          show_card(report)
        else
          stdout.puts report.to_text.chomp
        end
        report.failed? ? Result.error("#{report.count(AzuCLI::Diagnostics::Status::Fail)} check(s) failed") : success
      end

      private def show_card(report : AzuCLI::Diagnostics::Report) : Nil
        rich = ui.as(UI::Rich)
        g = rich.terminal.glyphs
        width = report.checks.max_of?(&.id.size) || 0
        lines = [] of Array(UI::Seg)
        report.checks.each do |check|
          mark, tone = case check.status
                       in .ok?   then {g.ok, UI::Token::Green}
                       in .warn? then {g.warn, UI::Token::Amber}
                       in .fail? then {g.fail, UI::Token::Red}
                       end
          lines << [UI::Seg[mark, tone], UI::Seg[" #{check.id.ljust(width)}  ", UI::Token::Muted], UI::Seg[check.message, check.status.ok? ? UI::Token::Text : tone]]
          check.hint.try { |hint| lines << [UI::Seg[" " * (width + 4)], UI::Seg["#{g.pointer} #{hint}", UI::Token::Muted]] }
        end
        fails, warns = report.count(AzuCLI::Diagnostics::Status::Fail), report.count(AzuCLI::Diagnostics::Status::Warn)
        badge = "#{report.count(AzuCLI::Diagnostics::Status::Ok)} ok #{g.dot} #{warns} warn #{g.dot} #{fails} fail"
        tone = fails > 0 ? UI::Token::Red : (warns > 0 ? UI::Token::Amber : UI::Token::Purple)
        ui.panel("Doctor #{g.dot} #{Utils.project_name}", lines, badge, tone)
      end

      private def show_help_result : Result
        show_help
        success
      end

      def show_help
        stdout.puts <<-HELP
          Usage: azu doctor [options]

          Checks, without changing anything:
            crystal        Crystal is installed and not older than the `crystal:` of shard.yml
            shards         shards is installed
            dependencies   installed shards match shard.yml and shard.lock (shards check)
            database       DATABASE_URL: a SQLite file is writable, a PostgreSQL/MySQL server accepts
                           connections (3s timeout; credentials are not tried and never printed)
            env            the variables .env.example leaves blank are set (names only, never values)
            secrets        CSRF_SECRET / SESSION_SECRET are not placeholders or short; no secret in src/
            port           PORT (default 4000) is free
            docker         docker is installed (a warning only when the project has a Dockerfile)
            gitignore      .env is git-ignored and not tracked

          In production (CRYSTAL_ENV=production) the env and secrets problems are failures, not warnings.

          Options:
            --json     Print {"checks": [{id, status, message, hint}], "summary": {...}} instead of text
            --ui MODE  rich (a card, the default on a terminal) or plain (the text above)
            --help     Show this help

          Exit codes: 0 no check failed (warnings allowed), 1 a check failed, 2 invalid usage.
        HELP
        stdout.puts
        stdout.puts "Examples:"
        show_examples
      end

      def show_examples
        stdout.puts "  azu doctor"
        stdout.puts "  azu doctor --json"
      end
    end
  end
end
