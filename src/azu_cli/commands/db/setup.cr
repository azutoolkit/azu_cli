require "../database"
require "./create"
require "./migrate"
require "./seed"

module AzuCLI
  module Commands
    module DB
      # Setup database (create and migrate)
      class Setup < Database
        property with_seed : Bool = false

        def initialize
          super("db:setup", "setup database (create, migrate, seed)")
        end

        # Override parse_args to also trigger custom parsing
        def parse_args(args : Array(String))
          super(args)
          parse_options
        end

        def execute : Result
          parse_options

          db_name = @database_name || infer_database_name

          Logger.info("Setting up database '#{db_name}'...")
          show_database_info

          # Create database if it doesn't exist
          if database_exists?(db_name)
            Logger.info("Database already exists")
          else
            Logger.info("Creating database...")
            create_cmd = Create.new
            create_cmd.database_name = @database_name
            create_cmd.environment = @environment
            result = create_cmd.execute
            return result unless result.success?
          end

          # Run migrations
          Logger.info("Running migrations...")
          migrate_cmd = Migrate.new
          migrate_cmd.database_name = @database_name
          migrate_cmd.environment = @environment
          result = migrate_cmd.execute
          return result unless result.success?

          # Seed database if requested
          if @with_seed && File.exists?(seed_file)
            Logger.info("Seeding database...")
            seed_cmd = Seed.new
            seed_cmd.database_name = @database_name
            seed_cmd.environment = @environment
            seed_cmd.execute
            # Don't fail if seeding fails
          end

          Logger.info("✓ Database setup completed successfully")
          success("Database setup completed")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--seed"
              @with_seed = true
            when "--no-seed"
              @with_seed = false
            when "--env", "-e"
              if env = args[index + 1]?
                @environment = env
              end
            end
          end
        end
      end
    end
  end
end
