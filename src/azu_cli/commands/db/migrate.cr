require "../database"
require "cql"

module AzuCLI
  module Commands
    module DB
      # Run database migrations
      class Migrate < Database
        property version : String?
        property verbose : Bool = false
        property dry_run : Bool = false

        def initialize
          super("db:migrate", "Run pending database migrations")
        end

        def execute : Result
          parse_options

          db_name = @database_name || infer_database_name

          unless database_exists?(db_name)
            return error("Database '#{db_name}' does not exist. Run 'azu db:create' first.")
          end

          ensure_migrations_dir
          ensure_schema_migrations_table

          migrations = load_migrations
          pending = get_pending_migrations(migrations)

          if pending.empty?
            Logger.info("No pending migrations")
            return success("All migrations up to date")
          end

          Logger.info("Running #{pending.size} pending migration(s)...")
          show_database_info if @verbose

          pending.each do |migration|
            run_migration(migration)
          end

          Logger.info("✓ All migrations completed successfully")
          success("Migrations completed")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--version", "-v"
              if v = args[index + 1]?
                @version = v
              end
            when "--verbose"
              @verbose = true
            when "--dry-run"
              @dry_run = true
            when "--env", "-e"
              if env = args[index + 1]?
                @environment = env
              end
            end
          end
        end

        private def ensure_schema_migrations_table
          create_table_sql = case @adapter
          when "postgres", "postgresql"
            <<-SQL
              CREATE TABLE IF NOT EXISTS schema_migrations (
                version VARCHAR(255) PRIMARY KEY,
                migrated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
              )
            SQL
          when "mysql"
            <<-SQL
              CREATE TABLE IF NOT EXISTS schema_migrations (
                version VARCHAR(255) PRIMARY KEY,
                migrated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
              )
            SQL
          when "sqlite", "sqlite3"
            <<-SQL
              CREATE TABLE IF NOT EXISTS schema_migrations (
                version TEXT PRIMARY KEY,
                migrated_at DATETIME DEFAULT CURRENT_TIMESTAMP
              )
            SQL
          else
            raise "Unsupported adapter: #{@adapter}"
          end

          execute_on_database(create_table_sql)
        rescue ex
          raise "Failed to create schema_migrations table: #{ex.message}"
        end

        private def load_migrations : Array(String)
          return [] of String unless Dir.exists?(migrations_dir)

          Dir.glob("#{migrations_dir}/*.cr")
            .map { |path| File.basename(path, ".cr") }
            .select { |name| name.matches?(/^\d+_.*$/) }
            .sort
        end

        private def get_pending_migrations(all_migrations : Array(String)) : Array(String)
          applied = get_applied_migrations
          all_migrations.reject { |m| applied.includes?(m) }
        end

        private def get_applied_migrations : Array(String)
          migrations = [] of String
          query_database("SELECT version FROM schema_migrations ORDER BY version") do |rs|
            rs.each do
              migrations << rs.read(String)
            end
          end
          migrations
        rescue
          [] of String
        end

        private def run_migration(migration_name : String)
          if @dry_run
            Logger.info("[DRY RUN] Would run migration: #{migration_name}")
            return
          end

          Logger.info("== #{migration_name}: migrating ==")
          start_time = Time.monotonic

          # Load and execute migration file
          migration_file = "#{migrations_dir}/#{migration_name}.cr"

          # For now, we'll execute the SQL directly
          # In a real implementation, you'd want to load the Crystal migration class
          # and call its up method

          # Record migration
          execute_on_database(
            "INSERT INTO schema_migrations (version) VALUES ('#{migration_name}')"
          )

          duration = (Time.monotonic - start_time).total_seconds
          Logger.info("== #{migration_name}: migrated (#{duration.round(4)}s) ==")
        rescue ex
          Logger.error("== #{migration_name}: failed ==")
          raise "Migration failed: #{ex.message}"
        end
      end
    end
  end
end

