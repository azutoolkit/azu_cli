require "../database"

module AzuCLI
  module Commands
    module DB
      # Drop database command
      class Drop < Database
        property force : Bool = false

        def initialize
          super("db:drop", "Drop the database for the current environment")
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

          unless @force
            print "Are you sure you want to drop database '#{db_name}'? [y/N]: "
            response = gets
            unless response && response.downcase.starts_with?("y")
              return error("Database drop cancelled")
            end
          end

          Logger.info("Dropping database '#{db_name}'...")
          drop_database(db_name)
          Logger.info("✓ Database '#{db_name}' dropped successfully")

          success("Database dropped")
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

        private def drop_database(db_name : String)
          case @adapter
          when "postgres", "postgresql"
            terminate_database_connections(db_name)
            execute_on_server("DROP DATABASE #{quote_database_name(db_name)}")
          when "mysql"
            execute_on_server("DROP DATABASE #{quote_database_name(db_name)}")
          when "sqlite", "sqlite3"
            File.delete(sqlite_path(db_name)) if File.exists?(sqlite_path(db_name))
          else
            raise "Unsupported adapter: #{@adapter}"
          end
        rescue ex
          raise "Failed to drop database: #{ex.message}"
        end
      end
    end
  end
end
