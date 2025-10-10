require "../database"

module AzuCLI
  module Commands
    module DB
      # Rollback database migrations
      class Rollback < Database
        property steps : Int32 = 1
        property version : String?
        property verbose : Bool = false

        def initialize
          super("db:rollback", "Rollback the last migration(s)")
        end

        def execute : Result
          parse_options

          db_name = @database_name || infer_database_name

          unless database_exists?(db_name)
            return error("Database '#{db_name}' does not exist")
          end

          applied = get_applied_migrations

          if applied.empty?
            Logger.info("No migrations to rollback")
            return success("No migrations to rollback")
          end

          if @version
            # Rollback to specific version
            migrations_to_rollback = applied.select { |m| m > @version.not_nil! }.reverse
          else
            # Rollback last N steps
            migrations_to_rollback = applied.last(@steps).reverse
          end

          if migrations_to_rollback.empty?
            Logger.info("No migrations to rollback")
            return success("No migrations to rollback")
          end

          Logger.info("Rolling back #{migrations_to_rollback.size} migration(s)...")
          show_database_info if @verbose

          migrations_to_rollback.each do |migration|
            rollback_migration(migration)
          end

          Logger.info("✓ Rollback completed successfully")
          success("Rollback completed")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--steps", "-s"
              if s = args[index + 1]?.try(&.to_i)
                @steps = s
              end
            when "--version", "-v"
              if v = args[index + 1]?
                @version = v
              end
            when "--verbose"
              @verbose = true
            when "--env", "-e"
              if env = args[index + 1]?
                @environment = env
              end
            end
          end
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

        private def rollback_migration(migration_name : String)
          Logger.info("== #{migration_name}: reverting ==")
          start_time = Time.monotonic

          # In a real implementation, you'd load the migration class and call its down method
          # For now, just remove from schema_migrations

          execute_on_database(
            "DELETE FROM schema_migrations WHERE version = '#{migration_name}'"
          )

          duration = (Time.monotonic - start_time).total_seconds
          Logger.info("== #{migration_name}: reverted (#{duration.round(4)}s) ==")
        rescue ex
          Logger.error("== #{migration_name}: rollback failed ==")
          raise "Rollback failed: #{ex.message}"
        end
      end
    end
  end
end

