require "../database"
require "cql"
require "../../validators/migration_validator"

module AzuCLI
  module Commands
    module DB
      # Rollback database migrations using CQL's Migrator
      class Rollback < Database
        property steps : Int32 = 1
        property version : Int64?
        property verbose : Bool = false
        property dry_run : Bool = false
        property force : Bool = false

        def initialize
          super("db:rollback", "Rollback the last migration(s)")
        end

        # Override parse_args to also trigger custom parsing
        def parse_args(args : Array(String))
          super(args)
          parse_options
        end

        def execute : Result
          parse_options

          db_name = @database_name || infer_database_name

          unless database_exists?(db_name)
            return error("Database '#{db_name}' does not exist")
          end

          ensure_migrations_dir

          # Check if migrations exist
          unless has_migrations?
            return error("No migration files found")
          end

          # Validate migrations
          validator = AzuCLI::Validators::MigrationValidator.new(migrations_dir)
          unless validator.validate_all
            Logger.error("Migration validation failed:")
            Logger.error(validator.summary)
            return error("Migration validation failed. Use --force to bypass.")
          end

          # Get applied migrations
          applied_versions = get_applied_migration_versions
          if applied_versions.empty?
            Logger.info("No applied migrations to rollback")
            return success("No migrations to rollback")
          end

          # Handle dry-run mode
          if @dry_run
            return execute_dry_run(applied_versions)
          end

          # Show data loss warnings
          unless @force
            show_rollback_warnings(applied_versions)
          end

          # Create a temporary migration runner script
          runner_script = create_migration_runner_script("down", version, steps)

          Logger.info("Rolling back #{@steps} migration(s)...")
          show_database_info if @verbose

          # Execute the runner script
          result = execute_runner_script(runner_script)

          # Clean up the temporary script
          File.delete(runner_script) if File.exists?(runner_script)

          if result
            Logger.info("✓ Rollback completed successfully")
            success("Rollback completed")
          else
            error("Rollback failed")
          end
        rescue ex : Exception
          error("Rollback failed: #{ex.message}")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--steps", "-s"
              if s = args[index + 1]?.try(&.to_i32?)
                @steps = s
              end
            when "--version", "-v"
              if v = args[index + 1]?.try(&.to_i64?)
                @version = v
              end
            when "--verbose"
              @verbose = true
            when "--dry-run"
              @dry_run = true
            when "--force", "-f"
              @force = true
            when "--env", "-e"
              if env = args[index + 1]?
                @environment = env
              end
            end
          end
        end

        # Check if migrations directory has migration files
        private def has_migrations? : Bool
          return false unless Dir.exists?(migrations_dir)
          !Dir.glob("#{migrations_dir}/*.cr").empty?
        end

        # Create a temporary migration runner script
        private def create_migration_runner_script(action : String, version : Int64? = nil, steps : Int32? = nil) : String
          project_root = Dir.current
          script_path = File.join(project_root, "tmp_rollback_#{Time.utc.to_unix}.cr")
          schema_name, schema_symbol = detect_schema_info

          script_content = String.build do |io|
            io << "require \"cql\"\n"
            io << "require \"pg\"\n"
            io << "require \"./src/db/schema.cr\"\n"
            io << "require \"./src/db/migrations/*\"\n\n"
            io << "config = CQL::MigratorConfig.new(\n"
            io << "  schema_file_path: \"src/db/schema.cr\",\n"
            io << "  schema_name: :#{schema_name},\n"
            io << "  schema_symbol: :#{schema_symbol},\n"
            io << "  auto_sync: true\n"
            io << ")\n\n"
            io << "migrator = #{schema_name}.migrator(config)\n\n"

            case action
            when "up"
              if ver = version
                io << "migrator.up_to(#{ver}_i64)\n"
              elsif st = steps
                io << "migrator.up(#{st})\n"
              else
                io << "migrator.up\n"
              end
            when "down"
              if ver = version
                io << "migrator.down_to(#{ver}_i64)\n"
              elsif st = steps
                io << "migrator.rollback(#{st})\n"
              else
                io << "migrator.rollback(#{st || 1})\n"
              end
            when "redo"
              io << "migrator.redo\n"
            end
          end

          File.write(script_path, script_content)
          script_path
        end

        # Execute the migration runner script
        private def execute_runner_script(script_path : String) : Bool
          success = system("crystal run #{script_path}")
          success
        end

        # Execute dry-run mode
        private def execute_dry_run(applied_versions : Array(Int64)) : Result
          Logger.info("DRY RUN MODE - No changes will be made")
          Logger.info("=" * 50)
          
          # Determine which migrations will be rolled back
          migrations_to_rollback = if @version
            applied_versions.select { |v| v >= @version.not_nil! }
          else
            applied_versions.last(@steps)
          end
          
          if migrations_to_rollback.empty?
            Logger.info("No migrations would be rolled back")
            return success("No migrations to rollback")
          end
          
          Logger.info("Migrations that would be rolled back:")
          migrations_to_rollback.each do |version|
            Logger.info("  #{version}")
          end
          
          Logger.info("=" * 50)
          Logger.info("To perform this rollback, run without --dry-run")
          
          success("Dry run completed")
        end

        # Show rollback warnings
        private def show_rollback_warnings(applied_versions : Array(Int64))
          Logger.warn("⚠️  WARNING: This operation will rollback database migrations")
          Logger.warn("This may result in data loss or schema changes")
          
          migrations_to_rollback = if @version
            applied_versions.select { |v| v >= @version.not_nil! }
          else
            applied_versions.last(@steps)
          end
          
          Logger.info("Migrations to be rolled back:")
          migrations_to_rollback.each do |version|
            Logger.info("  - #{version}")
          end
          
          print "Are you sure you want to continue? [y/N]: "
          response = gets
          unless response && response.downcase.starts_with?("y")
            raise "Rollback cancelled by user"
          end
        end

        # Get applied migration versions from database
        private def get_applied_migration_versions : Array(Int64)
          versions = [] of Int64
          query_database("SELECT version FROM schema_migrations ORDER BY version") do |rs|
            rs.each do
              versions << rs.read(Int64)
            end
          end
          versions
        rescue
          [] of Int64
        end

        # Public test helper to access private method for testing
        def test_create_migration_runner_script(action : String, version : Int64? = nil, steps : Int32? = nil) : String
          create_migration_runner_script(action, version, steps)
        end
      end
    end
  end
end
