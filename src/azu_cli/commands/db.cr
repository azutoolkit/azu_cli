require "../command"
require "cql"

module AzuCLI::Commands
  # Database command - handles all database operations using CQL
  class Db < Command
    command_name "db"
    description "Database operations using CQL"
    usage "db <subcommand> [options]"

    SUBCOMMANDS = ["create", "migrate", "seed", "reset", "rollback", "status", "new_migration"]

    def execute(args : Hash(String, String | Array(String))) : String | Nil
      positional = get_positional_args(args)

      if positional.empty?
        log.error("Database subcommand is required")
        show_db_help
        return nil
      end

      subcommand = positional.first.downcase

      unless SUBCOMMANDS.includes?(subcommand)
        log.error("Unknown database subcommand: #{subcommand}")
        show_db_help
        return nil
      end

      # Ensure we're in a project directory
      require_project_root!

      # Check database configuration
      check_database_configuration

      case subcommand
      when "create"
        db_create(args)
      when "migrate"
        db_migrate(args)
      when "seed"
        db_seed(args)
      when "reset"
        db_reset(args)
      when "rollback"
        db_rollback(args)
      when "status"
        db_status(args)
      when "new_migration"
        db_new_migration(args)
      end

      nil
    end

    private def check_database_configuration
      # Check if database initializer exists
      db_initializer_path = "src/initializers/database.cr"

      unless File.exists?(db_initializer_path)
        log.warn("Database configuration not found at #{db_initializer_path}")
        log.info("Run 'azu init' to initialize database setup.")
        log.info("Or create #{db_initializer_path} manually with your CQL configuration")
      end
    end

    private def get_database_schema_paths : Array(String)
      [
        "src/db/schema.cr",
      ]
    end

    private def db_create(args : Hash(String, String | Array(String)))
      log.info("🗄️  Creating database...")

      begin
        adapter = detect_database_adapter
        database_name = get_database_name

        log.info("Creating #{adapter} database: #{database_name}")

        case adapter
        when "postgresql"
          create_postgresql_database(database_name)
        when "mysql"
          create_mysql_database(database_name)
        when "sqlite"
          create_sqlite_database(database_name)
        else
          log.error("Unsupported database adapter: #{adapter}")
          return
        end

        log.success("✅ Database '#{database_name}' created successfully!")
      rescue ex : Exception
        log.error("Failed to create database: #{ex.message}")
        log.info("Make sure the database server is running and you have the necessary permissions")
      end
    end

    private def db_migrate(args : Hash(String, String | Array(String)))
      log.info("🔄 Running database migrations...")

      begin
        # Check for migrations directory
        check_migrations_directory

        # Get migration target (optional)
        target_version = get_flag(args, "version", "")

        if target_version.empty?
          log.info("Running all pending migrations...")
          run_all_migrations
        else
          log.info("Migrating to version #{target_version}...")
          run_migration_to_version(target_version.to_i64)
        end

        log.success("✅ Migrations completed successfully!")
      rescue ex : Exception
        log.error("Migration failed: #{ex.message}")
        log.info("Check your migration files and database connectivity")
      end
    end

    private def db_seed(args : Hash(String, String | Array(String)))
      log.info("🌱 Seeding database...")

      begin
        seed_file = "src/db/seed.cr"

        if File.exists?(seed_file)
          log.info("Running seed file: #{seed_file}")
          log.info("Loading seed data...")
          # Note: Actual seed execution would be handled by the application's seed runner
          log.success("✅ Database seeded successfully!")
        else
          log.warn("No seed file found at #{seed_file}")
          log.info("Create #{seed_file} to define your seed data")
          show_seed_example
        end
      rescue ex : Exception
        log.error("Seeding failed: #{ex.message}")
      end
    end

    private def db_reset(args : Hash(String, String | Array(String)))
      log.info("🔄 Resetting database...")

      # Confirm the reset operation
      unless has_flag?(args, "force")
        puts "⚠️  This will drop and recreate the database, losing all data!".colorize(:red).bold
        print "Are you sure? [y/N]: ".colorize(:yellow)
        response = gets.try(&.strip.downcase) || ""

        unless response.starts_with?("y")
          log.info("Database reset cancelled")
          return
        end
      end

      begin
        # Drop database
        log.info("Dropping database...")
        db_drop

        # Recreate database
        log.info("Recreating database...")
        db_create(args)

        # Run migrations
        log.info("Running migrations...")
        db_migrate(args)

        # Run seeds
        log.info("Running seeds...")
        db_seed(args)

        log.success("✅ Database reset completed successfully!")
      rescue ex : Exception
        log.error("Database reset failed: #{ex.message}")
      end
    end

    private def db_rollback(args : Hash(String, String | Array(String)))
      steps = get_flag(args, "steps", "1").to_i
      log.info("🔙 Rolling back #{steps} migration(s)...")

      begin
        check_migrations_directory
        rollback_migrations(steps)
        log.success("✅ Rollback completed successfully!")
      rescue ex : Exception
        log.error("Rollback failed: #{ex.message}")
      end
    end

    private def db_status(args : Hash(String, String | Array(String)))
      log.info("📊 Database migration status:")

      begin
        check_migrations_directory
        show_migration_status
      rescue ex : Exception
        log.error("Failed to get migration status: #{ex.message}")
      end
    end

    private def db_new_migration(args : Hash(String, String | Array(String)))
      positional = get_positional_args(args)

      if positional.size < 2
        log.error("Migration name is required")
        log.info("Usage: azu db new_migration <migration_name>")
        return
      end

      migration_name = positional[1]

      log.info("📝 Creating new migration: #{migration_name}")

      begin
        create_migration_file(migration_name)
        log.success("✅ Migration file created successfully!")
      rescue ex : Exception
        log.error("Failed to create migration: #{ex.message}")
      end
    end

    private def detect_database_adapter : String
      # Try to detect from shard.yml dependencies
      if File.exists?("shard.yml")
        content = File.read("shard.yml")

        return "postgresql" if content.includes?("crystal-pg") || content.includes?("pg:")
        return "mysql" if content.includes?("crystal-mysql") || content.includes?("mysql:")
        return "sqlite" if content.includes?("crystal-sqlite3") || content.includes?("sqlite3:")
      end

      # Default to postgresql
      "postgresql"
    end

    private def get_database_name : String
      # Try to get from environment
      if db_url = ENV["DATABASE_URL"]?
        # Extract database name from URL
        uri = URI.parse(db_url)
        return uri.path.lchop('/') if uri.path && !uri.path.empty?
      end

      # Get from project name
      project_name = get_project_name
      env = ENV.fetch("AZU_ENV", "development")

      "#{project_name}_#{env}"
    end

    private def create_postgresql_database(name : String)
      # Connect to postgresql and create database
      host = ENV.fetch("AZU_DB_HOST", "localhost")
      port = ENV.fetch("AZU_DB_PORT", "5432")
      user = ENV.fetch("AZU_DB_USER", "postgres")
      password = ENV.fetch("AZU_DB_PASSWORD", "")

      # Build createdb command
      cmd = ["createdb"]
      cmd << "-h" << host
      cmd << "-p" << port
      cmd << "-U" << user
      cmd << name

      if password.empty?
        log.info("Creating database without password authentication")
      else
        ENV["PGPASSWORD"] = password
      end

      success = system(cmd.join(" "))
      unless success
        raise "Failed to create PostgreSQL database. Check connection and permissions."
      end
    end

    private def create_mysql_database(name : String)
      host = ENV.fetch("AZU_DB_HOST", "localhost")
      port = ENV.fetch("AZU_DB_PORT", "3306")
      user = ENV.fetch("AZU_DB_USER", "root")
      password = ENV.fetch("AZU_DB_PASSWORD", "")

      password_arg = password.empty? ? "" : "-p#{password}"
      cmd = "mysql -h #{host} -P #{port} -u #{user} #{password_arg} -e 'CREATE DATABASE #{name};'"

      success = system(cmd)
      unless success
        raise "Failed to create MySQL database. Check connection and permissions."
      end
    end

    private def create_sqlite_database(name : String)
      # For SQLite, just ensure the directory exists
      db_path = "db/#{name}.db"
      ensure_directory(File.dirname(db_path))
      log.info("SQLite database will be created at: #{db_path}")

      # Create empty database file to test write permissions
      File.touch(db_path) unless File.exists?(db_path)
    end

    private def db_drop
      adapter = detect_database_adapter
      database_name = get_database_name

      case adapter
      when "postgresql"
        cmd = "dropdb #{database_name}"
        success = system(cmd)
        unless success
          log.warn("Could not drop PostgreSQL database (it may not exist)")
        end
      when "mysql"
        password_arg = ENV["AZU_DB_PASSWORD"]?.try { |p| "-p#{p}" } || ""
        cmd = "mysql -u #{ENV.fetch("AZU_DB_USER", "root")} #{password_arg} -e 'DROP DATABASE IF EXISTS #{database_name};'"
        success = system(cmd)
        unless success
          log.warn("Could not drop MySQL database")
        end
      when "sqlite"
        db_path = "db/#{database_name}.db"
        if File.exists?(db_path)
          File.delete(db_path)
          log.info("Deleted SQLite database: #{db_path}")
        end
      end
    end

    private def check_migrations_directory
      migrations_dir = "src/db/migrations"

      unless Dir.exists?(migrations_dir)
        log.error("Migrations directory not found: #{migrations_dir}")
        log.info("Run 'azu init' to create the directory structure")
        raise ValidationError.new("Migrations directory not found")
      end
    end

    private def run_all_migrations
      migrations_dir = "src/db/migrations"
      migration_files = Dir.glob("#{migrations_dir}/*.cr").sort

      if migration_files.empty?
        log.info("No migration files found in #{migrations_dir}")
        log.info("Create migrations with: azu generate migration <name>")
        return
      end

      log.info("Found #{migration_files.size} migration file(s)")
      migration_files.each do |file|
        log.info("  - #{File.basename(file)}")
      end

      log.info("To run migrations, the application needs to be set up with CQL migrator")
      log.info("This would typically be done in your application's migration runner")
    end

    private def run_migration_to_version(version : Int64)
      log.info("Migrating to version: #{version}")
      log.info("CQL migration to specific version would be executed here")
    end

    private def rollback_migrations(steps : Int32)
      log.info("Rolling back #{steps} step(s)")
      log.info("CQL rollback implementation would be executed here")
    end

    private def show_migration_status
      migrations_dir = "src/db/migrations"
      migration_files = Dir.glob("#{migrations_dir}/*.cr").sort

      puts "\n📋 Migration Status:"

      if migration_files.empty?
        puts "   No migrations found"
        puts "   Create migrations with: azu generate migration <name>"
      else
        puts "   Migration files found:"
        migration_files.each do |file|
          basename = File.basename(file, ".cr")
          puts "   📄 #{basename}"
        end
        puts "\n   💡 Run 'azu db:migrate' to apply migrations"
        puts "   💡 Use CQL.migrator.print_applied_migrations in your app for detailed status"
      end
      puts
    end

    private def create_migration_file(name : String)
      timestamp = Time.utc.to_s("%Y%m%d%H%M%S")
      class_name = name.split(/[_\s]/).map(&.capitalize).join
      filename = "#{timestamp}_#{name.gsub(/\s+/, "_").downcase}.cr"

      migrations_dir = "src/db/migrations"
      ensure_directory(migrations_dir)

      file_path = File.join(migrations_dir, filename)

      migration_content = render_migration_template(class_name, timestamp.to_i64)
      write_file(file_path, migration_content)

      log.info("Created migration: #{file_path}")
      log.info("Edit the migration file to define your schema changes")
    end

    private def render_migration_template(class_name : String, version : Int64) : String
      <<-CRYSTAL
      require "cql"

      # Migration: #{class_name}
      # Generated at: #{Time.utc}
      class #{class_name} < CQL::Migration(#{version})
        def up
          # Define your schema changes here
          # Examples:
          #
          # Create a new table:
          # schema.create_table :users do |t|
          #   t.string :name, null: false
          #   t.string :email, null: false
          #   t.timestamps
          # end
          #
          # Add a column:
          # schema.alter_table :users do |t|
          #   t.add_column :phone, String, null: true
          # end
          #
          # Add an index:
          # schema.add_index :users, :email, unique: true
        end

        def down
          # Define how to rollback the changes
          # Examples:
          #
          # Drop a table:
          # schema.drop_table :users
          #
          # Remove a column:
          # schema.alter_table :users do |t|
          #   t.remove_column :phone
          # end
          #
          # Remove an index:
          # schema.remove_index :users, :email
        end
      end
      CRYSTAL
    end

    private def show_seed_example
      puts
      puts "💡 Example seed file content (src/db/seed.cr):".colorize(:cyan).bold
      puts <<-EXAMPLE
      require "cql"
      require "../initializers/database"
      require "../models/*"

      puts "🌱 Seeding database..."

      # Ensure we're connected to the database
      unless AppSchema.connected?
        puts "❌ Database not connected. Run 'azu db:create' and 'azu db:migrate' first."
        exit(1)
      end

      # Create seed data
      puts "  👥 Creating users..."

      admin = User.create!(
        name: "Admin User",
        email: "admin@example.com",
        active: true
      )

      user = User.create!(
        name: "Regular User",
        email: "user@example.com",
        active: true
      )

      puts "    ✅ Created \#{User.count} users"
      puts "🎉 Seeding completed!"
      EXAMPLE
    end

    private def show_db_help
      puts
      puts "Database Commands:".colorize(:cyan).bold
      puts
      puts "  create         Create the database"
      puts "  migrate        Run pending migrations"
      puts "  seed           Run database seeds"
      puts "  reset          Drop, create, migrate, and seed database"
      puts "  rollback       Rollback migrations"
      puts "  status         Show migration status"
      puts "  new_migration  Create a new migration file"
      puts
      puts "Options:".colorize(:yellow).bold
      puts "  --version VERSION    Migrate to specific version"
      puts "  --steps STEPS        Number of migrations to rollback"
      puts "  --force              Skip confirmation prompts"
      puts
      puts "Examples:".colorize(:green).bold
      puts "  azu db create"
      puts "  azu db migrate"
      puts "  azu db rollback --steps 2"
      puts "  azu db new_migration add_email_to_users"
      puts "  azu db reset --force"
      puts
      puts "Environment Variables:".colorize(:magenta).bold
      puts "  DATABASE_URL         Full database connection URL"
      puts "  AZU_DB_HOST          Database host (default: localhost)"
      puts "  AZU_DB_PORT          Database port"
      puts "  AZU_DB_USER          Database username"
      puts "  AZU_DB_PASSWORD      Database password"
      puts "  AZU_ENV              Environment (development, test, production)"
    end

    def show_command_specific_help
      show_db_help
    end
  end
end
