require "../database"

module AzuCLI
  module Commands
    module DB
      # Validate database configuration and connectivity
      class Validate < Database
        property check_connection : Bool = true
        property check_permissions : Bool = true
        property check_migrations : Bool = true

        def initialize
          super("db:validate", "Validate database configuration and connectivity")
        end

        # Override parse_args to also trigger custom parsing
        def parse_args(args : Array(String))
          super(args)
          parse_options
        end

        def execute : Result
          parse_options

          db_name = @database_name || infer_database_name

          Logger.info("Validating database configuration...")
          show_database_info

          validation_passed = true

          # Check connection
          if @check_connection
            Logger.info("Checking database connection...")
            if validate_connection
              Logger.info("✓ Database connection successful")
            else
              Logger.error("✗ Database connection failed")
              validation_passed = false
            end
          end

          # Check database existence
          Logger.info("Checking database existence...")
          if database_exists?(db_name)
            Logger.info("✓ Database '#{db_name}' exists")
          else
            Logger.warn("⚠ Database '#{db_name}' does not exist")
            Logger.info("Run 'azu db:create' to create the database")
          end

          # Check permissions
          if @check_permissions && database_exists?(db_name)
            Logger.info("Checking database permissions...")
            if check_database_permissions
              Logger.info("✓ Database permissions are sufficient")
            else
              Logger.error("✗ Insufficient database permissions")
              validation_passed = false
            end
          end

          # Check migrations
          if @check_migrations
            Logger.info("Checking migration files...")
            if check_migration_files
              Logger.info("✓ Migration files are valid")
            else
              Logger.warn("⚠ Migration files have issues")
            end
          end

          # Summary
          Logger.info("=" * 50)
          if validation_passed
            Logger.info("✓ Database validation passed")
            success("Database validation completed successfully")
          else
            Logger.error("✗ Database validation failed")
            error("Database validation failed")
          end
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--no-connection"
              @check_connection = false
            when "--no-permissions"
              @check_permissions = false
            when "--no-migrations"
              @check_migrations = false
            when "--env", "-e"
              if env = args[index + 1]?
                @environment = env
              end
            end
          end
        end

        # Check database permissions
        private def check_database_permissions : Bool
          begin
            # Test basic read permission
            query_database("SELECT 1") { }

            # Test write permission (create a temporary table)
            execute_on_database("CREATE TEMP TABLE _azu_validation_test (id INT)")
            execute_on_database("DROP TABLE _azu_validation_test")

            true
          rescue ex
            Logger.error("Permission check failed: #{ex.message}")
            false
          end
        end

        # Check migration files
        private def check_migration_files : Bool
          migrations_dir = "./src/db/migrations"

          unless Dir.exists?(migrations_dir)
            Logger.warn("Migrations directory does not exist: #{migrations_dir}")
            return false
          end

          migration_files = Dir.glob("#{migrations_dir}/*.cr")

          if migration_files.empty?
            Logger.info("No migration files found")
            return true
          end

          valid_count = 0
          migration_files.each do |file|
            filename = File.basename(file, ".cr")

            # Check if filename matches expected pattern
            unless filename.match(/^\d+_/)
              Logger.warn("Invalid migration filename: #{filename}")
              next
            end

            # Check if file can be loaded
            begin
              content = File.read(file)
              unless content.includes?("CQL::Migration")
                Logger.warn("Migration file does not extend CQL::Migration: #{filename}")
                next
              end

              valid_count += 1
            rescue ex
              Logger.warn("Error reading migration file #{filename}: #{ex.message}")
            end
          end

          Logger.info("Found #{migration_files.size} migration files, #{valid_count} valid")
          valid_count > 0
        end
      end
    end
  end
end
