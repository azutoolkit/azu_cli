require "../database"
require "cql"

module AzuCLI
  module Commands
    module DB
      # Run database migrations using CQL's Migrator
      class Migrate < Database
        property version : Int64?
        property verbose : Bool = false
        property dry_run : Bool = false
        property steps : Int32?

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
          script_path = File.tempname("azu_migrate", ".cr")

          script_content = String.build do |io|
            io << "require \"cql\"\n"
            io << "require \"./src/db/schema\"\n"
            io << "require \"./src/db/migrations/*\"\n\n"
            io << "config = CQL::MigratorConfig.new(\n"
            io << "  schema_file_path: \"src/db/schema.cr\",\n"
            io << "  schema_name: :AppSchema,\n"
            io << "  schema_symbol: :app_schema,\n"
            io << "  auto_sync: true\n"
            io << ")\n\n"
            io << "migrator = AppSchema.migrator(config)\n\n"

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
      end
    end
  end
end
