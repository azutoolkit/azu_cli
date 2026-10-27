require "../base"
require "../../generators/session"
require "yaml"

module AzuCLI
  module Commands
    module Session
      # Setup session support
      class Setup < Base
        property backend : String = "cookie"
        property force : Bool = false

        def initialize
          super("session:setup", "Setup session management for the application")
        end

        # Override parse_args to also trigger custom parsing
        def parse_args(args : Array(String))
          super(args)
          parse_options
        end

        def execute : Result
          parse_options
          generator = begin
            AzuCLI::Generate::Session.new(project: get_project_name, backend: @backend)
          rescue ex : ArgumentError
            return usage_error(ex.message.to_s)
          end

          Logger.info("Setting up #{@backend} sessions...")
          generator.render(".", force: @force, interactive: false, list: false, color: true)

          Logger.info("Next steps:")
          Logger.info("1. Run 'shards install'")
          Logger.info("2. SESSION_SECRET is in .env for development; set it in the environment in production")
          Logger.info("3. Set REDIS_URL (default redis://localhost:6379)") if @backend == "redis"
          success("Session setup completed")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--backend", "-b"
              args[index + 1]?.try { |backend| @backend = backend }
            when "--force", "-f"
              @force = true
            end
          end
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
