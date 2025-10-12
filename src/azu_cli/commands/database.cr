require "./base"
require "db"
require "pg"
require "uri"

module AzuCLI
  module Commands
    # Base class for database commands
    abstract class Database < Base
      property database_url : String?
      property adapter : String = "postgres"
      property database_name : String?
      property host : String = "localhost"
      property port : Int32 = 5432
      property username : String = "postgres"
      property password : String = ""
      property environment : String = "development"

      def initialize(name : String = "", description : String = "")
        super(name, description)
        load_database_config
      end

      # Load database configuration from environment or config files
      private def load_database_config
        # Try DATABASE_URL first
        if url = ENV["DATABASE_URL"]?
          @database_url = url
          parse_database_url(url)
        elsif url = ENV["AZU_DATABASE_URL"]?
          @database_url = url
          parse_database_url(url)
        else
          # Load from individual environment variables
          @host = ENV["AZU_DB_HOST"]? || @host
          @port = ENV["AZU_DB_PORT"]?.try(&.to_i) || @port
          @database_name = ENV["AZU_DB_NAME"]? || ENV["DATABASE_NAME"]? || infer_database_name
          @username = ENV["AZU_DB_USER"]? || ENV["DATABASE_USER"]? || @username
          @password = ENV["AZU_DB_PASSWORD"]? || ENV["DATABASE_PASSWORD"]? || @password
          @adapter = ENV["AZU_DB_ADAPTER"]? || @adapter
        end

        @environment = ENV["AZU_ENV"]? || ENV["CRYSTAL_ENV"]? || @environment
      end

      # Parse DATABASE_URL into components
      private def parse_database_url(url : String)
        uri = URI.parse(url)
        @adapter = uri.scheme || "postgres"
        @host = uri.host || "localhost"
        @port = uri.port || default_port_for_adapter
        @username = uri.user || "postgres"
        @password = uri.password || ""
        @database_name = uri.path.try(&.lstrip('/')) || ""
      end

      # Get default port for database adapter
      private def default_port_for_adapter : Int32
        case @adapter
        when "postgres", "postgresql"
          5432
        when "mysql"
          3306
        when "sqlite", "sqlite3"
          0
        else
          5432
        end
      end

      # Infer database name from current directory
      private def infer_database_name : String
        project_name = Dir.current.split("/").last
        "#{project_name}_#{@environment}"
      end

      # Get connection URL for database server (without database name)
      protected def server_connection_url : String
        case @adapter
        when "postgres", "postgresql"
          "postgresql://#{@username}:#{@password}@#{@host}:#{@port}/postgres"
        when "mysql"
          "mysql://#{@username}:#{@password}@#{@host}:#{@port}/mysql"
        when "sqlite", "sqlite3"
          "sqlite3:./#{@database_name}.db"
        else
          raise "Unsupported database adapter: #{@adapter}"
        end
      end

      # Get connection URL for specific database
      protected def database_connection_url(db_name : String? = nil) : String
        db = db_name || @database_name || infer_database_name

        case @adapter
        when "postgres", "postgresql"
          "postgresql://#{@username}:#{@password}@#{@host}:#{@port}/#{db}"
        when "mysql"
          "mysql://#{@username}:#{@password}@#{@host}:#{@port}/#{db}"
        when "sqlite", "sqlite3"
          "sqlite3:./#{db}.db"
        else
          raise "Unsupported database adapter: #{@adapter}"
        end
      end

      # Execute SQL on server connection
      protected def execute_on_server(sql : String)
        ::DB.open(server_connection_url) do |db|
          db.exec(sql)
        end
      end

      # Execute SQL on database connection
      protected def execute_on_database(sql : String, db_name : String? = nil)
        ::DB.open(database_connection_url(db_name)) do |db|
          db.exec(sql)
        end
      end

      # Query database and return results
      protected def query_database(sql : String, db_name : String? = nil, &)
        ::DB.open(database_connection_url(db_name)) do |db|
          db.query(sql) do |rs|
            yield rs
          end
        end
      end

      # Check if database exists
      protected def database_exists?(db_name : String? = nil) : Bool
        db = db_name || @database_name || infer_database_name

        case @adapter
        when "postgres", "postgresql"
          ::DB.open(server_connection_url) do |db_conn|
            db_conn.query_one?(
              "SELECT 1 FROM pg_database WHERE datname = $1",
              db,
              as: Int32
            ) == 1
          end
        when "mysql"
          ::DB.open(server_connection_url) do |db_conn|
            db_conn.query_one?(
              "SELECT 1 FROM information_schema.schemata WHERE schema_name = ?",
              db,
              as: Int32
            ) == 1
          end
        when "sqlite", "sqlite3"
          File.exists?("./#{db}.db")
        else
          false
        end
      rescue
        false
      end

      # Get migrations directory
      protected def migrations_dir : String
        "./src/db/migrations"
      end

      # Get seed file path
      protected def seed_file : String
        "./src/db/seed.cr"
      end

      # Ensure migrations directory exists
      protected def ensure_migrations_dir
        Dir.mkdir_p(migrations_dir) unless Dir.exists?(migrations_dir)
      end

      # Display database info
      protected def show_database_info
        Logger.info("Database: #{@database_name || infer_database_name}")
        Logger.info("Adapter: #{@adapter}")
        Logger.info("Host: #{@host}:#{@port}")
        Logger.info("Environment: #{@environment}")
      end
    end
  end
end
