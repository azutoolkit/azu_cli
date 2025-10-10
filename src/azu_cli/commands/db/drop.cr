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
            # Terminate existing connections
            execute_on_server(<<-SQL)
              SELECT pg_terminate_backend(pg_stat_activity.pid)
              FROM pg_stat_activity
              WHERE pg_stat_activity.datname = '#{db_name}'
                AND pid <> pg_backend_pid()
            SQL
            execute_on_server("DROP DATABASE #{db_name}")
          when "mysql"
            execute_on_server("DROP DATABASE #{db_name}")
          when "sqlite", "sqlite3"
            File.delete("./#{db_name}.db") if File.exists?("./#{db_name}.db")
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

