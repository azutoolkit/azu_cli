require "../database"

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

          all_migrations = load_migrations
          applied = get_applied_migrations

          if all_migrations.empty?
            Logger.info("No migrations found in #{migrations_dir}")
            return success("No migrations")
          end

          puts "Migration Status:"
          puts "#{"-" * 80}"
          puts "#{"Status".ljust(10)} | #{"Version".ljust(20)} | Migration Name"
          puts "#{"-" * 80}"

          all_migrations.each do |migration|
            status = applied.includes?(migration) ? "✓ Applied" : "  Pending"
            timestamp = migration.split("_").first
            name = migration.split("_", 2).last.gsub("_", " ").capitalize

            puts "#{status.ljust(10)} | #{timestamp.ljust(20)} | #{name}"
          end

          puts "#{"-" * 80}"
          puts "Total: #{all_migrations.size} migrations (#{applied.size} applied, #{all_migrations.size - applied.size} pending)"

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
      end
    end
  end
end
