require "../database"
require "cql"

module AzuCLI
  module Commands
    module DB
      # Run data migrations separately from schema migrations
      class DataMigrate < Database
        property version : Int64?
        property verbose : Bool = false
        property dry_run : Bool = false
        property steps : Int32?

        def initialize
          super("db:data:migrate", "Run pending data migrations")
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

          ensure_data_migrations_dir

          # Check if data migrations exist
          unless has_data_migrations?
            return error("No data migration files found. Create data migrations using 'azu generate data:migration NAME'")
          end

          # Handle dry-run mode
          if @dry_run
            return execute_dry_run
          end

          # Create a temporary data migration runner script
          runner_script = create_data_migration_runner_script("up", version, steps)

          Logger.info("Running data migrations...")
          show_database_info if @verbose

          # Execute the runner script
          result = execute_runner_script(runner_script)

          # Clean up the temporary script
          File.delete(runner_script) if File.exists?(runner_script)

          if result
            Logger.info("✓ Data migrations completed successfully")
            success("Data migrations completed")
          else
            error("Data migration failed")
          end
        rescue ex : Exception
          error("Data migration command failed: #{ex.message}")
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
            when "--env", "-e"
              if env = args[index + 1]?
                @environment = env
              end
            end
          end
        end

        # Check if data migrations directory has migration files
        private def has_data_migrations? : Bool
          return false unless Dir.exists?(data_migrations_dir)
          !Dir.glob("#{data_migrations_dir}/*.cr").empty?
        end

        # Get data migrations directory
        private def data_migrations_dir : String
          "./src/db/data_migrations"
        end

        # Ensure data migrations directory exists
        private def ensure_data_migrations_dir
          Dir.mkdir_p(data_migrations_dir) unless Dir.exists?(data_migrations_dir)
        end

        # Create a temporary data migration runner script
        private def create_data_migration_runner_script(action : String, version : Int64? = nil, steps : Int32? = nil) : String
          project_root = Dir.current
          script_path = File.join(project_root, "tmp_data_migrate_#{Time.utc.to_unix}.cr")
          schema_name, schema_symbol = detect_schema_info

          script_content = String.build do |io|
            io << "require \"cql\"\n"
            io << "require \"pg\"\n"
            io << "require \"./src/db/schema.cr\"\n"
            io << "require \"./src/db/data_migrations/*\"\n\n"
            io << "config = CQL::MigratorConfig.new(\n"
            io << "  schema_file_path: \"src/db/schema.cr\",\n"
            io << "  schema_name: :#{schema_name},\n"
            io << "  schema_symbol: :#{schema_symbol},\n"
            io << "  auto_sync: false\n" # Data migrations don't affect schema
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

        # Execute the data migration runner script
        private def execute_runner_script(script_path : String) : Bool
          success = system("crystal run #{script_path}")
          success
        end

        # Execute dry-run mode
        private def execute_dry_run : Result
          Logger.info("DRY RUN MODE - No data changes will be made")
          Logger.info("=" * 50)

          # Get data migration files
          data_migrations = Dir.glob("#{data_migrations_dir}/*.cr")

          if data_migrations.empty?
            Logger.info("No data migration files found")
            return success("No data migrations")
          end

          Logger.info("Data migration files found:")
          data_migrations.each do |file|
            filename = File.basename(file, ".cr")
            Logger.info("  #{filename}")
          end

          Logger.info("=" * 50)
          Logger.info("To apply these data migrations, run without --dry-run")

          success("Dry run completed")
        end

        # Public test helper to access private method for testing
        def test_create_data_migration_runner_script(action : String, version : Int64? = nil, steps : Int32? = nil) : String
          create_data_migration_runner_script(action, version, steps)
        end
      end
    end
  end
end
