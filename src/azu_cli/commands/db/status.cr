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

          unless rich?
            show_database_info
            puts ""
          end

          # Use MigrationValidator for better migration handling
          validator = AzuCLI::Validators::MigrationValidator.new(migrations_dir)
          validator.validate_all

          all_migrations = validator.migration_files.map { |file| File.basename(file, ".cr") }
          applied_versions = read_applied_versions(db_name)

          if all_migrations.empty?
            Logger.info("No migrations found in #{migrations_dir}")
            return success("No migrations")
          end

          return show_card(db_name, all_migrations, applied_versions, validator) if rich?

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

        # The migrations as a card: applied ones with their time, pending ones marked, the database in the title.
        private def show_card(db_name : String, migrations : Array(String), applied : Array(Int64), validator) : Result
          g = ui.as(UI::Rich).terminal.glyphs
          rows = migrations.map do |migration|
            version = migration.split("_").first
            done = applied.includes?(version.to_i64)
            name = migration.split("_", 2).last.gsub("_", " ").capitalize
            [done ? UI::Seg[g.ok, UI::Token::Green] : UI::Seg[g.off, UI::Token::Amber], UI::Seg[version, UI::Token::Muted],
             UI::Seg[name], done ? UI::Seg[get_migration_applied_at(version.to_i64), UI::Token::Muted] : UI::Seg["pending", UI::Token::Amber]]
          end
          lines = UI::Table.new(["", "VERSION", "MIGRATION", "APPLIED"], rows).lines(ui.as(UI::Rich).inner_width)
          lines << [] of UI::Seg
          lines << [UI::Seg["#{@adapter} #{g.dot} #{@environment}", UI::Token::Muted]]
          pending = migrations.size - applied.size
          badge = "#{applied.size} applied #{g.dot} #{pending} pending"
          ui.panel("Migrations #{g.dot} #{db_name}", lines, badge, pending > 0 ? UI::Token::Amber : UI::Token::Purple)
          validator.errors.each { |problem| ui.warn(problem) } unless validator.valid?
          validator.warnings.each { |warning| ui.note(warning) }
          success("Status displayed")
        end

        # The applied versions; on a terminal as a task, since reading them compiles a script on SQLite and MySQL.
        private def read_applied_versions(db_name : String) : Array(Int64)
          return applied_migration_versions unless rich?

          ui.group("Status #{ui.as(UI::Rich).terminal.glyphs.dot} #{db_name}") do
            ui.task("Read", "applied migrations") do |task|
              applied_migration_versions.tap { |versions| task.finish(detail: "#{versions.size} applied") }
            end
          end
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
          query_database("SELECT version FROM cql_schema_migrations ORDER BY version") do |rs|
            rs.each do
              migrations << rs.read(Int64).to_s
            end
          end
          migrations
        rescue
          [] of String
        end

        # Get when a migration was applied ("-" when CQL did not record a time)
        private def get_migration_applied_at(version : Int64) : String
          query_database("SELECT created_at FROM cql_schema_migrations WHERE version = #{version}") do |rs|
            rs.each do
              return rs.read(String?).try { |time| time.empty? ? nil : time[0, 19] } || "-"
            end
          end
          "-"
        rescue
          "-"
        end
      end
    end
  end
end
