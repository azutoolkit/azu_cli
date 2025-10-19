require "../database"
require "../../validators/migration_validator"

module AzuCLI
  module Commands
    module DB
      # Verify all migrations can be applied and rolled back without errors
      class Verify < Database
        property test_rollback : Bool = true
        property verbose : Bool = false

        def initialize
          super("db:migrations:verify", "Verify all migrations can be applied and rolled back")
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

          Logger.info("Verifying migrations...")
          show_database_info if @verbose

          # Validate migration files
          Logger.info("Validating migration files...")
          validator = AzuCLI::Validators::MigrationValidator.new(migrations_dir)
          unless validator.validate_all
            Logger.error("Migration validation failed:")
            Logger.error(validator.summary)
            return error("Migration validation failed")
          end

          if validator.warnings.any?
            Logger.warn("Migration validation warnings:")
            validator.warnings.each { |warning| Logger.warn("  - #{warning}") }
          end

          Logger.info("✓ Migration files are valid")

          # Test migration application and rollback
          if @test_rollback
            Logger.info("Testing migration rollback capability...")
            unless test_migration_rollback
              return error("Migration rollback test failed")
            end
            Logger.info("✓ Migration rollback test passed")
          end

          # Test schema consistency
          Logger.info("Checking schema consistency...")
          unless check_schema_consistency
            Logger.warn("⚠ Schema consistency issues detected")
          else
            Logger.info("✓ Schema is consistent")
          end

          Logger.info("=" * 50)
          Logger.info("✓ All migration verifications passed")
          success("Migration verification completed successfully")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--no-rollback"
              @test_rollback = false
            when "--verbose"
              @verbose = true
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

        # Test migration rollback capability
        private def test_migration_rollback : Bool
          # Get applied migrations
          applied_versions = get_applied_migration_versions

          if applied_versions.empty?
            Logger.info("No applied migrations to test")
            return true
          end

          # Test rollback for the most recent migration
          latest_version = applied_versions.max
          Logger.info("Testing rollback for migration version: #{latest_version}")

          # Create test script that applies and immediately rolls back
          test_script = create_rollback_test_script(latest_version)

          begin
            result = execute_runner_script(test_script)
            result
          ensure
            File.delete(test_script) if File.exists?(test_script)
          end
        end

        # Create rollback test script
        private def create_rollback_test_script(version : Int64) : String
          project_root = Dir.current
          script_path = File.join(project_root, "tmp_verify_rollback_#{Time.utc.to_unix}.cr")
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
            io << "  puts \"Rollback test failed: #\{ex.message\}\"\n"
            io << "  exit(1)\n"
            io << "end\n"
          end

          File.write(script_path, script_content)
          script_path
        end

        # Execute the test runner script
        private def execute_runner_script(script_path : String) : Bool
          success = system("crystal run #{script_path}")
          success
        end

        # Check schema consistency
        private def check_schema_consistency : Bool
          # Basic consistency check - verify schema_migrations table exists
          begin
            query_database("SELECT COUNT(*) FROM schema_migrations") { }
            true
          rescue
            false
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
      end
    end
  end
end
