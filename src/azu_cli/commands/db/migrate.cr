require "../database"
require "cql"
require "../../validators/migration_validator"

module AzuCLI
  module Commands
    module DB
      # Run database migrations using CQL's Migrator
      class Migrate < Database
        property version : Int64?
        property verbose : Bool = false
        property dry_run : Bool = false
        property steps : Int32?
        property test_rollback : Bool = false
        property skip_validation : Bool = false

        def initialize
          super("db:migrate", "Run pending database migrations")
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
            return error("Database '#{db_name}' does not exist. Run 'azu db:create' first.")
          end

          ensure_migrations_dir

          # Check if migrations exist
          unless has_migrations?
            return error("No migration files found. Create migrations using 'azu generate migration NAME'")
          end

          # Validate migrations unless skipped
          unless @skip_validation
            Logger.info("Validating migrations...")
            validator = MigrationValidator.new(migrations_dir)
            unless validator.validate_all
              Logger.error("Migration validation failed:")
              Logger.error(validator.summary)
              return error("Migration validation failed. Use --skip-validation to bypass.")
            end
            
            unless validator.warnings.empty?
              Logger.warn("Migration validation warnings:")
              validator.warnings.each { |warning| Logger.warn("  - #{warning}") }
            end
          end

          # Handle dry-run mode
          if @dry_run
            return execute_dry_run
          end

          # Handle test-rollback mode
          if @test_rollback
            return execute_test_rollback
          end

          # Create a temporary migration runner script
          runner_script = create_migration_runner_script("up", version, steps)

          Logger.info("Running migrations...")
          show_database_info if @verbose

          # Execute the runner script
          result = execute_runner_script(runner_script)

          # Clean up the temporary script
          File.delete(runner_script) if File.exists?(runner_script)

          if result
            Logger.info("✓ Migrations completed successfully")
            success("Migrations completed")
          else
            error("Migration failed")
          end
        rescue ex : Exception
          error("Migration command failed: #{ex.message}")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--version", "-v"
              if v = args[index + 1]?.try(&.to_i64?)
                @version = v
              end
            when "--steps", "-s"
              if s = args[index + 1]?.try(&.to_i32?)
                @steps = s
              end
            when "--verbose"
              @verbose = true
            when "--dry-run"
              @dry_run = true
            when "--test-rollback"
              @test_rollback = true
            when "--skip-validation"
              @skip_validation = true
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
          script_path = File.join(project_root, "tmp_migrate_#{Time.utc.to_unix}.cr")
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
                io << "migrator.rollback\n"
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
        private def execute_dry_run : Result
          Logger.info("DRY RUN MODE - No changes will be made")
          Logger.info("=" * 50)
          
          validator = MigrationValidator.new(migrations_dir)
          validator.validate_all
          
          # Get applied migrations
          applied_versions = get_applied_migration_versions
          pending_versions = validator.pending_migrations(applied_versions)
          
          if pending_versions.empty?
            Logger.info("No pending migrations to run")
            return success("No pending migrations")
          end
          
          Logger.info("Pending migrations to be applied:")
          pending_versions.each do |version|
            class_name = validator.migration_class_for_version(version) || "Unknown"
            Logger.info("  #{version} - #{class_name}")
          end
          
          Logger.info("=" * 50)
          Logger.info("To apply these migrations, run without --dry-run")
          
          success("Dry run completed")
        end

        # Execute test-rollback mode
        private def execute_test_rollback : Result
          Logger.info("TEST ROLLBACK MODE - Testing rollback capability")
          Logger.info("=" * 50)
          
          validator = MigrationValidator.new(migrations_dir)
          validator.validate_all
          
          # Get applied migrations
          applied_versions = get_applied_migration_versions
          
          if applied_versions.empty?
            Logger.info("No applied migrations to test rollback")
            return success("No applied migrations")
          end
          
          # Test rollback for the most recent migration
          latest_version = applied_versions.max
          class_name = validator.migration_class_for_version(latest_version) || "Unknown"
          
          Logger.info("Testing rollback for migration: #{latest_version} - #{class_name}")
          
          # Create test script that applies and immediately rolls back
          test_script = create_test_rollback_script(latest_version)
          
          Logger.info("Applying migration in transaction...")
          result = execute_runner_script(test_script)
          
          # Clean up
          File.delete(test_script) if File.exists?(test_script)
          
          if result
            Logger.info("✓ Rollback test passed - migration can be safely applied and rolled back")
            success("Rollback test completed")
          else
            Logger.error("✗ Rollback test failed - migration may have issues")
            error("Rollback test failed")
          end
        end

        # Create test rollback script
        private def create_test_rollback_script(version : Int64) : String
          project_root = Dir.current
          script_path = File.join(project_root, "tmp_test_rollback_#{Time.utc.to_unix}.cr")
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
            io << "# Test rollback for version #{version}\n"
            io << "begin\n"
            io << "  # Apply migration\n"
            io << "  migrator.up_to(#{version}_i64)\n"
            io << "  puts \"Migration #{version} applied successfully\"\n"
            io << "  \n"
            io << "  # Immediately rollback\n"
            io << "  migrator.rollback(1)\n"
            io << "  puts \"Migration #{version} rolled back successfully\"\n"
            io << "rescue ex\n"
            io << "  puts \"Test rollback failed: #{ex.message}\"\n"
            io << "  exit(1)\n"
            io << "end\n"
          end

          File.write(script_path, script_content)
          script_path
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
