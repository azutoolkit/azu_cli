require "../base"
require "../../generators/session"
require "yaml"

module AzuCLI
  module Commands
    module Session
      # Setup session support
      class Setup < Base
        property backend : String = "redis"
        property force : Bool = false

        def initialize
          super("session:setup", "Setup session management for the application")
        end

        def execute : Result
          parse_options

          Logger.info("Setting up session support...")
          Logger.info("Backend: #{@backend}")

          # Get project name
          project_name = get_project_name

          # Generate session initializer
          generator = AzuCLI::Generate::Session.new(
            project: project_name,
            backend: @backend
          )

          Logger.info("Generating session configuration...")
          generator.render(".", force: @force, interactive: false, list: false, color: true)

          # Create migration if using database backend
          if generator.needs_migration?
            Logger.info("Creating sessions migration...")
            create_sessions_migration
          end

          # Update shard.yml with dependencies
          update_dependencies(generator.dependencies)

          Logger.info("✓ Session setup completed successfully")
          puts ""
          Logger.info("Next steps:")
          Logger.info("1. Run 'shards install' to install dependencies")

          if generator.needs_migration?
            Logger.info("2. Run 'azu db:migrate' to create sessions table")
          end

          Logger.info("#{generator.needs_migration? ? "3" : "2"}. Configure SESSION_SECRET environment variable")
          Logger.info("#{generator.needs_migration? ? "4" : "3"}. Require session initializer in your application:")
          Logger.info("     require \"./initializers/session\"")

          puts ""
          Logger.info("Session backend: #{@backend}")

          case @backend
          when "redis"
            Logger.info("Redis URL: Set REDIS_URL environment variable (default: redis://localhost:6379)")
          when "database"
            Logger.info("Database: Use your existing DATABASE_URL")
          when "memory"
            Logger.info("Memory: No external dependencies required (development only)")
          end

          success("Session setup completed")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--backend", "-b"
              backend = args[index + 1]? if index + 1 < args.size
              if backend && ["redis", "memory", "database"].includes?(backend)
                @backend = backend
              end
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

        private def create_sessions_migration
          timestamp = Time.utc.to_s("%Y%m%d%H%M%S")
          migration_file = "./src/db/migrations/#{timestamp}_create_sessions.cr"

          Dir.mkdir_p("./src/db/migrations")

          File.write(migration_file, <<-MIGRATION)
            # Create sessions table for database-backed session storage

            CQL::Schema.define do |schema|
              schema.create :sessions do
                primary :id, Int64, auto: true
                column :session_id, String, size: 255, unique: true, null: false
                column :data, String, null: false
                column :created_at, Time, default: "NOW()"
                column :updated_at, Time, default: "NOW()"
                column :expires_at, Time, null: false

                add_index :sessions, :session_id
                add_index :sessions, :expires_at
              end
            end
          MIGRATION

          Logger.info("Created migration: #{migration_file}")
        end

        private def update_dependencies(dependency : String)
          return if dependency.empty?

          Logger.info("Add to your shard.yml if not already present:")
          Logger.info("")
          Logger.info("dependencies:")

          case dependency
          when "redis"
            Logger.info("  redis:")
            Logger.info("    github: stefanwille/crystal-redis")
          when "cql"
            Logger.info("  cql:")
            Logger.info("    github: azutoolkit/cql")
          end
        end
      end
    end
  end
end

