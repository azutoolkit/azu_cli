require "../database"
require "./drop"
require "./create"
require "./migrate"
require "./seed"

module AzuCLI
  module Commands
    module DB
      # Reset database (drop, create, migrate, seed)
      class Reset < Database
        property force : Bool = false
        property with_seed : Bool = true

        def initialize
          super("db:reset", "Drop, create, and migrate the database")
        end

        def execute : Result
          parse_options

          db_name = @database_name || infer_database_name

          unless @force
            print "Are you sure you want to reset database '#{db_name}'? All data will be lost. [y/N]: "
            response = gets
            unless response && response.downcase.starts_with?("y")
              return error("Database reset cancelled")
            end
          end

          Logger.info("Resetting database '#{db_name}'...")
          show_database_info

          # Drop database if it exists
          if database_exists?(db_name)
            Logger.info("Dropping database...")
            drop_cmd = Drop.new
            drop_cmd.force = true
            drop_cmd.database_name = @database_name
            drop_cmd.environment = @environment
            result = drop_cmd.execute
            return result unless result.success?
          end

          # Create database
          Logger.info("Creating database...")
          create_cmd = Create.new
          create_cmd.database_name = @database_name
          create_cmd.environment = @environment
          result = create_cmd.execute
          return result unless result.success?

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

          Logger.info("✓ Database reset completed successfully")
          success("Database reset completed")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--force", "-f"
              @force = true
            when "--no-seed"
              @with_seed = false
            when "--seed"
              @with_seed = true
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

