require "../database"

module AzuCLI
  module Commands
    module DB
      # Seed database with initial data
      class Seed < Database
        property file : String?
        property verbose : Bool = false

        def initialize
          super("db:seed", "seed the database with initial data")
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

          seed_path = @file || seed_file

          unless File.exists?(seed_path)
            Logger.warn("Seed file not found: #{seed_path}")
            Logger.info("Create a seed file at #{seed_file} to populate your database")
            return success("No seed file found")
          end

          Logger.info("Seeding database '#{db_name}'...")
          show_database_info if @verbose

          run_seed_file(seed_path)

          Logger.info("✓ Database seeded successfully")
          success("Database seeded")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--file", "-f"
              if f = args[index + 1]?
                @file = f
              end
            when "--verbose"
              @verbose = true
            when "--env", "-e"
              if env = args[index + 1]?
                @environment = env
              end
            end
          end
        end

        private def run_seed_file(path : String)
          # Set environment variable for seed file to use
          ENV["DATABASE_URL"] = database_connection_url

          # Execute the seed file
          output = IO::Memory.new
          error = IO::Memory.new

          status = Process.run(
            "crystal",
            ["run", path],
            output: output,
            error: error
          )

          if status.success?
            Logger.info(output.to_s) if @verbose && !output.empty?
          else
            raise "Seed file execution failed:\n#{error}"
          end
        rescue ex
          raise "Failed to run seed file: #{ex.message}"
        end
      end
    end
  end
end
