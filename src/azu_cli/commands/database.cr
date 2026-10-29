require "./base"
require "../scratch_file"
require "db"
require "pg"
require "cql/mysql"
require "sqlite3"
require "uri"
require "cql"

module AzuCLI
  module Commands
    # Base class for database commands
    abstract class Database < Base
      # A SQLite URL that names no file (`sqlite3::memory:`, `sqlite3:`): there is nothing to create or drop.
      class InMemoryDatabase < Exception
      end

      property database_url : String?
      property adapter : String = "postgres"
      property database_name : String?
      property host : String = "localhost"
      property port : Int32 = 5432
      property username : String = "postgres"
      property password : String = ""
      property environment : String = "development"
      @sqlite_file : String?
      @url_database_name : String?

      # Connection pool configuration
      property pool_size : Int32 = 10
      property pool_timeout : Int32 = 5
      property checkout_timeout : Int32 = 5

      # Connection health tracking
      property last_connection_check : Time?
      property connection_healthy : Bool = false

      def initialize(name : String = "", description : String = "")
        super(name, description)
        load_database_config
      end

      # Load database configuration from environment or config files
      private def load_database_config
        @environment = ENV["AZU_ENV"]? || ENV["CRYSTAL_ENV"]? || @environment

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
          @adapter = ENV["AZU_DB_ADAPTER"]? || project_adapter || @adapter
        end

        # Load connection pool configuration
        @pool_size = ENV["AZU_DB_POOL_SIZE"]?.try(&.to_i) || @pool_size
        @pool_timeout = ENV["AZU_DB_POOL_TIMEOUT"]?.try(&.to_i) || @pool_timeout
        @checkout_timeout = ENV["AZU_DB_CHECKOUT_TIMEOUT"]?.try(&.to_i) || @checkout_timeout
      end

      # Parse DATABASE_URL into components
      private def parse_database_url(url : String)
        if url.matches?(/\Asqlite3?:/i)
          @adapter = "sqlite3"
          return remember_sqlite_file(url) # URI.parse rejects `sqlite3://:memory:` and reads the `.` of `./db` as a host
        end

        uri = URI.parse(url)
        @adapter = uri.scheme || "postgres"
        @host = uri.hostname || "localhost"
        @port = uri.port || default_port_for_adapter
        @username = uri.user || "postgres"
        @password = uri.password || ""
        @database_name = URI.decode(uri.path.lstrip('/'))
      end

      # The file a SQLite URL names (`sqlite3://./db/app.db?journal_mode=wal` is `./db/app.db`), and the
      # database name it goes by. The scheme is cut by hand because a SQLite URL is not an authority URL.
      private def remember_sqlite_file(url : String)
        @sqlite_file = url.sub(/\Asqlite3?:(\/\/)?/i, "").split('?', 2).first
        @database_name = @url_database_name = File.basename(@sqlite_file.to_s, ".db")
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

      # Adapter of the project's database driver shard (sqlite3, mysql). PostgreSQL wins when its driver
      # is there, and is what a project without any driver gets.
      private def project_adapter : String?
        dependencies = Utils.project_dependencies
        return if dependencies.includes?("pg")
        {"sqlite3", "mysql"}.find { |driver| dependencies.includes?(driver) }
      end

      # File of a SQLite database. The file of DATABASE_URL belongs to the database that URL names; any
      # other name (`--database other`) is `db/<name>.db`, like the generated project's initializer, so
      # db:drop never deletes the URL's file for another name. SQLite needs no server and creates the
      # file on first use.
      protected def sqlite_path(db_name : String) : String
        file = @sqlite_file
        return "./db/#{db_name}.db" unless file && db_name == @url_database_name
        if file.empty? || file.lstrip('/').starts_with?(":memory:")
          raise InMemoryDatabase.new("#{@database_url} is an in-memory database: it has no file to create, check or drop")
        end
        file
      end

      # Infer database name from current directory
      private def infer_database_name : String
        project_name = Dir.current.split("/").last
        # Sanitize project name to be a valid database identifier:
        # - Replace spaces and hyphens with underscores
        # - Remove any characters that aren't alphanumeric or underscores
        # - Ensure it starts with a letter or underscore
        sanitized_name = project_name
          .gsub(/[\s\-]/, "_")
          .gsub(/[^a-zA-Z0-9_]/, "")
        sanitized_name = "_#{sanitized_name}" if sanitized_name.matches?(/^\d/)
        sanitized_name = "app" if sanitized_name.empty?
        "#{sanitized_name}_#{@environment}"
      end

      # Get connection URL for database server (without database name)
      protected def server_connection_url : String
        case @adapter
        when "postgres", "postgresql"
          network_connection_url("postgresql", "postgres")
        when "mysql"
          network_connection_url("mysql", "mysql")
        when "sqlite", "sqlite3"
          "sqlite3:#{sqlite_path(@database_name || infer_database_name)}"
        else
          raise "Unsupported database adapter: #{@adapter}"
        end
      end

      # Get connection URL for specific database
      protected def database_connection_url(db_name : String? = nil) : String
        db = db_name || @database_name || infer_database_name

        case @adapter
        when "postgres", "postgresql"
          network_connection_url("postgresql", db)
        when "mysql"
          network_connection_url("mysql", db)
        when "sqlite", "sqlite3"
          "sqlite3:#{sqlite_path(db)}"
        else
          raise "Unsupported database adapter: #{@adapter}"
        end
      end

      # Preserve driver TLS/deadline options when selecting the administrative database.
      private def network_connection_url(scheme : String, db_name : String) : String
        URI.new(scheme: scheme, host: @host, port: @port,
          user: @username, password: @password,
          path: "/#{URI.encode_path_segment(db_name)}",
          query: @database_url.try { |url| URI.parse(url).query }).to_s
      end

      protected def quote_database_name(name : String) : String
        raise "Database name must not be empty or contain NUL" if name.empty? || name.includes?('\0')
        quote = @adapter == "mysql" ? "`" : "\""
        quote + name.gsub(quote, quote + quote) + quote
      end

      protected def terminate_database_connections(name : String)
        ::DB.open(server_connection_url) do |db|
          db.exec("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = $1 AND pid <> pg_backend_pid()", name)
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

      # Enhanced error handling with specific remediation steps
      private def handle_database_error(ex : Exception)
        message = ex.message || ""

        case
        when message.includes?("connection") || message.includes?("connect")
          Logger.error("Database connection failed")
          Logger.info("Check your database connection settings:")
          Logger.info("  - Verify database server is running")
          Logger.info("  - Check host and port: #{@host}:#{@port}")
          Logger.info("  - Verify credentials: #{@username}")
          Logger.info("  - Check firewall settings")
        when message.includes?("authentication") || message.includes?("password")
          Logger.error("Database authentication failed")
          Logger.info("Check your database credentials:")
          Logger.info("  - Username: #{@username}")
          Logger.info("  - Verify password is correct")
          Logger.info("  - Check if user has required permissions")
        when message.includes?("permission") || message.includes?("access")
          Logger.error("Database permission denied")
          Logger.info("Check your database permissions:")
          Logger.info("  - User needs CREATE, DROP, ALTER privileges")
          Logger.info("  - Run: GRANT ALL PRIVILEGES ON DATABASE #{@database_name} TO #{@username}")
        when message.includes?("timeout")
          Logger.error("Database operation timed out")
          Logger.info("Try increasing timeout settings:")
          Logger.info("  - Set AZU_DB_POOL_TIMEOUT=#{@pool_timeout * 2}")
          Logger.info("  - Set AZU_DB_CHECKOUT_TIMEOUT=#{@checkout_timeout * 2}")
        else
          Logger.error("Database operation failed: #{message}")
        end
      end

      # Check database connection health
      protected def check_connection_health : Bool
        return @connection_healthy if @last_connection_check &&
                                      (Time.utc - @last_connection_check.not_nil!).total_seconds < 30

        begin
          query_database("SELECT 1") { }
          @connection_healthy = true
          @last_connection_check = Time.utc
          true
        rescue ex
          @connection_healthy = false
          @last_connection_check = Time.utc
          Logger.warn("Database health check failed: #{ex.message}")
          false
        end
      end

      # Validate database connection before operations
      protected def validate_connection : Bool
        unless check_connection_health
          Logger.error("Database connection is not healthy")
          return false
        end
        true
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
            # MySQL returns COUNT(*) as a BIGINT, which crystal-db reads as Int64 (not the Int32 of PostgreSQL)
            db_conn.scalar("SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = ?", db).as(Int64) > 0
          end
        when "sqlite", "sqlite3"
          File.exists?(sqlite_path(db))
        else
          false
        end
      rescue ex : InMemoryDatabase
        raise ex
      rescue ex : Exception
        Logger.debug("Failed to check database existence: #{ex.message}")
        false
      end

      protected def sqlite? : Bool
        @adapter.in?("sqlite", "sqlite3")
      end

      # An empty file is an empty SQLite database
      protected def create_sqlite_database(db_name : String) : Nil
        path = sqlite_path(db_name)
        Dir.mkdir_p(File.dirname(path))
        File.touch(path)
      end

      # Get migrations directory
      protected def migrations_dir : String
        "./#{AzuCLI::Config::Paths::MIGRATIONS}"
      end

      # Get seed file path
      protected def seed_file : String
        "./src/db/seed.cr"
      end

      # Ensure migrations directory exists
      protected def ensure_migrations_dir
        Dir.mkdir_p(migrations_dir) unless Dir.exists?(migrations_dir)
      end

      # What a migration or seed script printed, sorted for a card: the migrations CQL's table lists, the log lines of
      # the app it loads (`2026-10-27T17:59:41Z  INFO - ...`), and anything else it printed.
      class ScriptOutput
        LOG_LINE      = /\A\d{4}-\d\d-\d\dT[\d:.]+Z\s+([A-Z]+) - (.*)\z/
        MIGRATION_ROW = /\A\s*│\s*(✔|✗)\s*│\s*(\S+)\s*│\s*(\d+)\s*│/
        BOX           = /\A\s*[┌├└│]/
        # Lines the azu migrate script prints before `up`: the plan marker, then one per migration it will apply.
        PLAN    = "AZU_PLAN"
        PENDING = "AZU_PENDING"

        # The migrations the script said it would apply ({version, name}), nil when it said nothing.
        getter planned : Array({String, String})?

        getter migrations = [] of {Bool, String, String}
        getter warnings = [] of String
        getter printed = [] of String

        def initialize(lines : Array(String))
          lines.each do |line|
            next if line.blank?
            if line.strip == PLAN
              @planned = [] of {String, String}
            elsif line.starts_with?("#{PENDING} ")
              _, version, name = line.split(' ', 3)
              (@planned ||= [] of {String, String}) << {version, name.split("::").last}
            elsif row = MIGRATION_ROW.match(line)
              migrations << {row[1] == "✔", row[2], row[3]}
            elsif log = LOG_LINE.match(line)
              warnings << log[2] if {"WARN", "ERROR", "FATAL"}.includes?(log[1])
            elsif !line.matches?(BOX)
              printed << line.rstrip
            end
          end
        end

        # "applied CreatePosts, AddTagsToPosts", "rolled back CreatePosts", or "done".
        def summary : String
          if plan = planned
            return plan.empty? ? "nothing to do: up to date" : "applied #{plan.map(&.[1]).join(", ")}"
          end
          return "done" if migrations.empty?
          applied, rolled_back = migrations.partition(&.[0])
          [{"applied", applied}, {"rolled back", rolled_back}].reject(&.[1].empty?).join("; ") do |(verb, rows)|
            "#{verb} #{rows.map(&.[1]).join(", ")}"
          end
        end

        # The line a running task shows: a log line's message, without its time and level.
        def self.note(line : String) : String
          return "planning" if line.strip == PLAN || line.starts_with?("#{PENDING} ")
          LOG_LINE.match(line).try(&.[2]) || line.strip
        end
      end

      # Runs `crystal run script`. On a terminal it is a task of a card that lists the migrations the script applied
      # or rolled back; warnings and what the script printed follow the card, and all of its output, on stderr, when
      # it failed. Elsewhere the output passes through.
      protected def run_crystal_script(script : String, task_name : String, env : Hash(String, String)? = nil) : Bool
        return Process.run("crystal", ["run", script], env: env, output: STDOUT, error: STDERR).success? unless rich?

        lines = [] of String
        ok = false
        g = ui.as(UI::Rich).terminal.glyphs
        ui.group("#{task_name} #{g.dot} #{@database_name || infer_database_name}") do
          ui.task(task_name, "compiling") do |task|
            reader, writer = IO.pipe
            process = Process.new("crystal", ["run", script], env: env, output: writer, error: writer)
            writer.close
            reader.each_line do |line|
              lines << line
              next if line.blank?
              task.detail = "running" if task.detail == "compiling"
              task.note = ScriptOutput.note(line)
            end
            ok = process.wait.success?
            next task.fail("crystal run failed") unless ok

            output = ScriptOutput.new(lines)
            task.finish(detail: output.summary)
          end
        end
        return ok.tap { lines.each { |line| STDERR.puts line } } unless ok

        output = ScriptOutput.new(lines)
        output.warnings.each { |warning| ui.warn(warning) }
        output.printed.first(40).each { |line| ui.note("  #{line}") }
        ok
      end

      # Display database info
      protected def show_database_info
        if rich?
          g = ui.as(UI::Rich).terminal.glyphs
          where = sqlite? ? (sqlite_path(@database_name || infer_database_name) rescue "memory") : "#{@host}:#{@port}"
          ui.note("#{g.pointer} #{@database_name || infer_database_name} #{g.dot} #{@adapter} #{g.dot} #{where} #{g.dot} #{@environment}")
          return
        end
        Logger.info("Database: #{@database_name || infer_database_name}")
        Logger.info("Adapter: #{@adapter}")
        Logger.info("Host: #{@host}:#{@port}")
        Logger.info("Environment: #{@environment}")
      end

      # Get schema file path
      def schema_file_path : String
        "./src/db/schema.cr"
      end

      # Detect schema name from project's schema file
      # Returns tuple of {schema_name, schema_symbol}
      # Examples: "BlogDB" → {"BlogDB", "blog_db"}
      # Uses centralized Utils.detect_schema_info for consistency
      protected def detect_schema_info : {String, String}
        Utils.detect_schema_info
      end

      # Map adapter string to CQL::Adapter enum
      def map_adapter_to_cql
        case @adapter
        when "postgres", "postgresql"
          CQL::Adapter::Postgres
        when "mysql"
          CQL::Adapter::MySql
        when "sqlite", "sqlite3"
          CQL::Adapter::SQLite
        else
          raise "Unsupported adapter: #{@adapter}"
        end
      end

      # Header shared by the temporary runner scripts (migrate, rollback, verify, data:migrate).
      #
      # Azu is required first (as in the application's main file: `azu/cql` needs `Azu::CONFIG`),
      # then the initializers are loaded before the schema so `CQL.config` and `Azu::CQL` exist when
      # `src/db/schema.cr` is evaluated: the schema takes its URL, adapter and pool from CQL's
      # configuration. The migrator never rewrites `src/db/schema.cr` (`auto_sync: false`), which
      # would otherwise replace it with a plain dump that embeds the database URI and password.
      protected def migrator_script_header(migrations_glob : String = "./#{AzuCLI::Config::Paths::MIGRATIONS}/*") : String
        schema_name, _ = detect_schema_info
        database_script_header + <<-CR
          require #{migrations_glob.inspect}
          config = CQL::MigratorConfig.new(auto_sync: false)
          migrator = #{schema_name}.migrator(config)

          CR
      end

      # Migrations and seeds load the same configuration before evaluating models.
      protected def database_script_header : String
        String.build do |io|
          io << "require \"cql\"\n"
          io << "require #{adapter_shard.inspect}\n"
          if initializers?
            io << "require \"azu\"\n"
            io << "require \"./src/initializers/**\"\n"
          end
          io << "require \"./src/db/schema.cr\"\n"
        end
      end

      # Shard that provides the database driver for the configured adapter
      protected def adapter_shard : String
        case @adapter
        when "mysql"
          "cql/mysql"
        when "sqlite", "sqlite3"
          "sqlite3"
        else
          "pg"
        end
      end

      # Whether the project has initializers to load (they configure CQL)
      protected def initializers? : Bool
        !Dir.glob("./src/initializers/*.cr").empty?
      end

      # Versions recorded in `cql_schema_migrations`, oldest first.
      #
      # The CLI links only the PostgreSQL driver, so for SQLite and MySQL the project reads them itself
      # (a runner script, like the migrations). A missing table is "nothing applied yet"; any other
      # failure is reported rather than shown as an empty list.
      protected def applied_migration_versions : Array(Int64)
        return applied_versions_from_project if {"sqlite", "sqlite3", "mysql"}.includes?(@adapter)

        versions = [] of Int64
        query_database("SELECT version FROM cql_schema_migrations ORDER BY version") do |rs|
          rs.each { versions << rs.read(Int64) }
        end
        versions
      rescue ex
        warn_unreadable_migrations(ex.message)
        [] of Int64
      end

      private def applied_versions_from_project : Array(Int64)
        script = applied_versions_script
        output = IO::Memory.new
        error = IO::Memory.new
        status = Process.run("crystal", ["run", script], output: output, error: error)
        unless status.success?
          warn_unreadable_migrations(error.to_s.lines.last?)
          return [] of Int64
        end
        output.to_s.lines.compact_map { |line| line.starts_with?("APPLIED ") ? line[8..].to_i64? : nil }.sort!
      ensure
        File.delete(script) if script && File.exists?(script)
      end

      private def applied_versions_script : String
        ScratchFile.create("tmp_applied_", migrator_script_header + "migrator.applied_migrations.each { |migration| puts \"APPLIED \#{migration.version}\" }\n", Dir.current)
      end

      private def warn_unreadable_migrations(message : String?)
        return if message.nil? || message.matches?(/does not exist|doesn't exist|no such table/i)
        Logger.warn("Could not read the applied migrations: #{message}")
      end

      # Public test helper to access private method for testing
      def test_applied_versions_script : String
        applied_versions_script
      end

      # Dump current database schema to file
      def dump_schema
        return unless Dir.exists?("./src/db")

        begin
          Logger.debug("Updating schema file...")

          cql_adapter = map_adapter_to_cql
          connection_url = database_connection_url
          schema_name, schema_symbol = detect_schema_info

          dumper = CQL::SchemaDump.new(cql_adapter, connection_url)
          # CQL::SchemaDump expects symbol literals, but we have strings
          # We'll use a workaround with case statement for known patterns
          case schema_name
          when "AppSchema"
            dumper.dump_to_file(schema_file_path, :AppSchema, :app_schema)
          else
            # For dynamic schema names, we write the file manually
            write_dynamic_schema_file(schema_name, schema_symbol, cql_adapter, connection_url)
          end
          dumper.close

          Logger.info("✓ Schema file updated: #{schema_file_path}")
        rescue ex
          Logger.warn("Failed to dump schema: #{ex.message}")
          # Don't fail the migration if schema dump fails
        end
      end

      # Write schema file with dynamic schema name
      private def write_dynamic_schema_file(schema_name : String, schema_symbol : String, adapter, connection_url : String)
        # For now, we skip schema dumping for dynamic schemas
        # This is a limitation of Crystal's compile-time symbols
        Logger.debug("Skipping schema dump for dynamic schema: #{schema_name}")
      end

      # Public test helper to access protected method for testing
      def test_detect_schema_info : {String, String}
        detect_schema_info
      end
    end
  end
end
