require "../database"
require "../../validators/migration_validator"

module AzuCLI
  module Commands
    module DB
      # Show migration status
      class Status < Database
        def initialize
          super("db:status", "Show migration status")
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

          show_database_info
          puts ""

          # Use MigrationValidator for better migration handling
          validator = MigrationValidator.new(migrations_dir)
          validator.validate_all

          all_migrations = validator.migration_files.map { |file| File.basename(file, ".cr") }
          applied_versions = get_applied_migration_versions

          if all_migrations.empty?
            Logger.info("No migrations found in #{migrations_dir}")
            return success("No migrations")
          end

          puts "Migration Status:"
          puts "#{"-" * 100}"
          puts "#{"Status".ljust(12)} | #{"Version".ljust(20)} | #{"Applied At".ljust(20)} | Migration Name"
          puts "#{"-" * 100}"

          all_migrations.each do |migration|
            version = migration.split("_").first.to_i64
            is_applied = applied_versions.includes?(version)
            
            status = if is_applied
              "✓ Applied"
            else
              "⏱ Pending"
            end
            
            timestamp = migration.split("_").first
            applied_at = is_applied ? get_migration_applied_at(version) : "N/A"
            name = migration.split("_", 2).last.gsub("_", " ").capitalize

            puts "#{status.ljust(12)} | #{timestamp.ljust(20)} | #{applied_at.ljust(20)} | #{name}"
          end

          puts "#{"-" * 100}"
          puts "Total: #{all_migrations.size} migrations (#{applied_versions.size} applied, #{all_migrations.size - applied_versions.size} pending)"

          # Show validation status
          unless validator.valid?
            puts ""
            Logger.warn("Migration validation issues detected:")
            validator.errors.each { |error| Logger.warn("  - #{error}") }
          end

          unless validator.warnings.empty?
            puts ""
            Logger.info("Migration warnings:")
            validator.warnings.each { |warning| Logger.info("  - #{warning}") }
          end

          success("Status displayed")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--env", "-e"
              if env = args[index + 1]?
                @environment = env
              end
            end
          end
        end

        private def load_migrations : Array(String)
          return [] of String unless Dir.exists?(migrations_dir)

          Dir.glob("#{migrations_dir}/*.cr")
            .map { |path| File.basename(path, ".cr") }
            .select(&.matches?(/^\d+_.*$/))
            .sort!
        end

        private def get_applied_migrations : Array(String)
          migrations = [] of String
          query_database("SELECT version FROM schema_migrations ORDER BY version") do |rs|
            rs.each do
              migrations << rs.read(String)
            end
          end
          migrations
        rescue
          [] of String
        end

        # Get applied migration versions as Int64 array
        private def get_applied_migration_versions : Array(Int64)
          versions = [] of Int64
          query_database("SELECT version FROM schema_migrations ORDER BY version") do |rs|
            rs.each do
              versions << rs.read(Int64)
            end
          end
          versions
        rescue
          [] of Int64
        end

        # Get when a migration was applied
        private def get_migration_applied_at(version : Int64) : String
          query_database("SELECT executed_at FROM schema_migrations WHERE version = ?", version) do |rs|
            rs.each do
              return rs.read(Time).to_s("%Y-%m-%d %H:%M:%S")
            end
          end
          "Unknown"
        rescue
          "Unknown"
        end
      end
    end
  end
end
