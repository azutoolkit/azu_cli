require "../database"
require "./seed_runner"

module AzuCLI
  module Commands
    module DB
      # Seed database with initial data
      class Seed < Database
        property file : String?
        property verbose : Bool = false
        property force : Bool = false
        property list : Bool = false
        property status : Bool = false
        property only : String?

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

          # Initialize seed runner
          seed_runner = SeedRunner.new(@environment, "./src/db/seeds")

          # Handle list command
          if @list
            seed_runner.list_seeds
            return success("Seed list displayed")
          end

          # Handle status command
          if @status
            status = seed_runner.get_seed_status
            Logger.info("Seed Status for environment: #{@environment}")
            Logger.info("=" * 50)
            status.each do |seed, state|
              status_icon = state == "executed" ? "✓" : "⏱"
              Logger.info("#{status_icon} #{seed}")
            end
            return success("Seed status displayed")
          end

          # Handle specific file
          if file = @file
            # Validate path to prevent directory traversal attacks
            seeds_dir = File.expand_path("./src/db/seeds")
            resolved_path = File.expand_path(file)
            unless resolved_path.starts_with?(seeds_dir) || resolved_path.starts_with?(File.expand_path("."))
              return error("Invalid seed file path: file must be within the project directory")
            end

            unless File.exists?(file)
              return error("Seed file not found: #{file}")
            end

            Logger.info("Running seed file: #{file}")
            show_database_info if @verbose

            if @force
              success = seed_runner.force_run_seed(file)
            else
              success = seed_runner.run_seed_file(file)
            end

            if success
              Logger.info("✓ Seed file executed successfully")
              return success("Seed file executed")
            else
              return error("Seed file execution failed")
            end
          end

          # Handle only specific seeds
          if only = @only
            seed_files = only.split(",").map(&.strip)
            Logger.info("Running specific seeds: #{seed_files.join(", ")}")
            show_database_info if @verbose

            success = seed_runner.run_seeds(seed_files)
            if success
              Logger.info("✓ Selected seeds executed successfully")
              return success("Selected seeds executed")
            else
              return error("Seed execution failed")
            end
          end

          # Run all seeds for environment
          Logger.info("Seeding database '#{db_name}' for environment '#{@environment}'...")
          show_database_info if @verbose

          success = seed_runner.run_seeds
          if success
            Logger.info("✓ Database seeded successfully")
            success("Database seeded")
          else
            error("Seed execution failed")
          end
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
            when "--force"
              @force = true
            when "--list"
              @list = true
            when "--status"
              @status = true
            when "--only"
              if o = args[index + 1]?
                @only = o
              end
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
