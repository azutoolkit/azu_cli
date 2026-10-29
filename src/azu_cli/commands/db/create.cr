require "../database"

module AzuCLI
  module Commands
    module DB
      # Create database command
      class Create < Database
        property force : Bool = false

        def initialize
          super("db:create", "Create the database for the current environment")
        end

        # Override parse_args to also trigger custom parsing
        def parse_args(args : Array(String))
          super(args)
          parse_options
        end

        def execute : Result
          parse_options

          db_name = @database_name || infer_database_name

          if database_exists?(db_name)
            if @force
              Logger.warn("Database '#{db_name}' already exists. Dropping...")
              drop_database(db_name)
            else
              return error("Database '#{db_name}' already exists. Use --force to recreate.")
            end
          end

          Logger.info("Creating database '#{db_name}'...")
          create_database(db_name)
          Logger.info("✓ Database '#{db_name}' created successfully")

          success("Database created")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--force", "-f"
              @force = true
            when "--database", "-d"
              if db = args[index + 1]?
                @database_name = db
              end
            when "--env", "-e"
              if env = args[index + 1]?
                @environment = env
              end
            end
          end
        end

        private def create_database(db_name : String)
          case @adapter
          when "postgres", "postgresql"
            execute_on_server("CREATE DATABASE #{quote_database_name(db_name)}")
          when "mysql"
            execute_on_server("CREATE DATABASE #{quote_database_name(db_name)}")
          when "sqlite", "sqlite3"
            create_sqlite_database(db_name)
          else
            raise "Unsupported adapter: #{@adapter}"
          end
        rescue ex
          raise "Failed to create database: #{ex.message}"
        end

        private def drop_database(db_name : String)
          case @adapter
          when "postgres", "postgresql"
            terminate_database_connections(db_name)
            execute_on_server("DROP DATABASE IF EXISTS #{quote_database_name(db_name)}")
          when "mysql"
            execute_on_server("DROP DATABASE IF EXISTS #{quote_database_name(db_name)}")
          when "sqlite", "sqlite3"
            File.delete(sqlite_path(db_name)) if File.exists?(sqlite_path(db_name))
          end
        rescue ex
          raise "Failed to drop database: #{ex.message}"
        end
      end
    end
  end
end
