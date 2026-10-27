require "../base"
require "../../generators/session"
require "yaml"

module AzuCLI
  module Commands
    module Session
      # Setup session support
      class Setup < Base
        OPTIONS = ["backend", "b", "force", "f"]
        USAGE   = "Usage: azu session:setup [--backend cookie|redis|memory] [--force]"

        property backend : String = "cookie"
        property force : Bool = false
        # The --backend value as given: "" when the option has no value, nil when it is absent.
        @backend_option : String? = nil

        def initialize
          super("session:setup", "Setup session management for the application")
        end

        def parse_args(args : Array(String))
          super(args)
          @force = has_option?("force") || has_option?("f")
          @backend_option = value_option("backend", "b")
          @backend_option.try { |value| @backend = value unless value.empty? }
        end

        def execute : Result
          return show_help_result if has_option?("help")
          if problem = usage_problem
            return usage_error("#{problem}. #{USAGE}")
          end

          generator = begin
            AzuCLI::Generate::Session.new(project: get_project_name, backend: @backend)
          rescue ex : ArgumentError
            return usage_error(ex.message.to_s)
          end
          if conflict = AzuCLI::Generate::Session.conflict(".", @force)
            return error(conflict)
          end

          Logger.info("Setting up #{@backend} sessions...")
          generator.render(".", force: @force, interactive: false, list: false, color: true)

          Logger.info("Next steps:")
          Logger.info("1. Run 'shards install'")
          Logger.info("2. SESSION_SECRET is in .env for development; set it in the environment in production")
          Logger.info("3. Set REDIS_URL (default redis://localhost:6379)") if @backend == "redis"
          success("Session setup completed")
        end

        private def usage_problem : String?
          if option = unknown_option(OPTIONS)
            "Unknown option #{option}"
          elsif @backend_option == ""
            "--backend needs a value: #{AzuCLI::Generate::Session::BACKENDS.join(", ")}"
          elsif !@args.empty?
            "session:setup takes no arguments (got #{@args.join(" ")})"
          end
        end

        private def show_help_result : Result
          show_help
          success
        end

        def show_help
          stdout.puts <<-HELP
            #{USAGE}

            Writes src/initializers/session.cr (a typed UserSession and its store), mounts the session handler
            after Azu::Handler::RequestId in src/<project>.cr and puts a random SESSION_SECRET in .env.

            Options:
              -b, --backend <type>  cookie (default), redis or memory
              -f, --force           Replace an existing src/initializers/session.cr (never the one of azu generate auth)
              --help                Show this help

            Exit codes: 0 done, 1 refused (the initializer exists, no place for the handler), 2 invalid usage.
            HELP
        end

        private def get_project_name : String
          if File.exists?("./shard.yml")
            shard_yml = YAML.parse(File.read("./shard.yml"))
            return shard_yml["name"].as_s
          end
          Dir.current.split("/").last
        end
      end
    end
  end
end
