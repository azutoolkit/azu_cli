require "./base"
require "../diagnostics/checks"
require "../diagnostics/report"

module AzuCLI
  module Commands
    # Diagnoses the environment the project runs in. Exit code 1 when a check fails (warnings do not fail).
    class Doctor < Base
      OPTIONS = ["json"]

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
        stdout.puts has_option?("json") ? report.to_json : report.to_text.chomp
        report.failed? ? Result.error("#{report.count(AzuCLI::Diagnostics::Status::Fail)} check(s) failed") : success
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
            --json   Print {"checks": [{id, status, message, hint}], "summary": {...}} instead of text
            --help   Show this help

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
