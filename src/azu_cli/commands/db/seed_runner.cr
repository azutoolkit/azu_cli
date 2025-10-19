require "../database"
require "db"

module AzuCLI
  module Commands
    module DB
      # Manages seed file execution with dependency tracking
      class SeedRunner < Database
        property environment : String
        property seeds_dir : String
        property executed_seeds : Array(String)

        def initialize(@environment : String = "development", @seeds_dir : String = "./src/db/seeds")
          super("seed:runner", "Seed file runner with dependency management")
          @executed_seeds = [] of String
        end

        def execute : Result
          # This class is used internally by other commands
          # The main execution logic is in the run_seeds method
          success("Seed runner initialized")
        end

        # Run seeds for the specified environment
        def run_seeds(files : Array(String)? = nil) : Bool
          ensure_seed_versions_table
          load_executed_seeds

          seed_files = files || find_seed_files

          if seed_files.empty?
            Logger.info("No seed files found for environment: #{@environment}")
            return true
          end

          Logger.info("Running #{seed_files.size} seed files for environment: #{@environment}")

          success = true
          seed_files.each do |file|
            unless run_seed_file(file)
              success = false
              break
            end
          end

          success
        end

        # Run a specific seed file
        def run_seed_file(file : String) : Bool
          filename = File.basename(file, ".cr")

          if @executed_seeds.includes?(filename)
            Logger.info("Skipping already executed seed: #{filename}")
            return true
          end

          Logger.info("Running seed: #{filename}")

          begin
            # Set environment variable for seed file to use
            ENV["DATABASE_URL"] = database_connection_url
            ENV["AZU_ENV"] = @environment

            # Execute the seed file
            output = IO::Memory.new
            error = IO::Memory.new

            status = Process.run(
              "crystal",
              ["run", file],
              output: output,
              error: error
            )

            if status.success?
              Logger.info("✓ Seed completed: #{filename}")
              mark_seed_as_executed(filename)
              true
            else
              Logger.error("✗ Seed failed: #{filename}")
              Logger.error("Error: #{error}")
              false
            end
          rescue ex
            Logger.error("✗ Seed execution failed: #{filename}")
            Logger.error("Exception: #{ex.message}")
            false
          end
        end

        # Find seed files for the current environment
        def find_seed_files : Array(String)
          files = [] of String

          # Look for environment-specific seeds
          env_dir = File.join(@seeds_dir, @environment)
          if Dir.exists?(env_dir)
            files.concat(Dir.glob("#{env_dir}/*.cr").sort)
          end

          # Look for shared seeds
          shared_dir = File.join(@seeds_dir, "shared")
          if Dir.exists?(shared_dir)
            files.concat(Dir.glob("#{shared_dir}/*.cr").sort)
          end

          files
        end

        # Load executed seeds from database
        private def load_executed_seeds
          @executed_seeds.clear

          begin
            query_database("SELECT seed_name FROM seed_versions ORDER BY executed_at") do |rs|
              rs.each do
                @executed_seeds << rs.read(String)
              end
            end
          rescue
            # Table might not exist yet, that's okay
            @executed_seeds = [] of String
          end
        end

        # Mark seed as executed in database
        private def mark_seed_as_executed(seed_name : String)
          begin
            execute_on_database(
              "INSERT INTO seed_versions (seed_name, executed_at) VALUES ('#{seed_name}', '#{Time.utc}')"
            )
            @executed_seeds << seed_name
          rescue ex
            Logger.warn("Failed to mark seed as executed: #{ex.message}")
          end
        end

        # Ensure seed_versions table exists
        private def ensure_seed_versions_table
          begin
            execute_on_database(<<-SQL)
              CREATE TABLE IF NOT EXISTS seed_versions (
                id SERIAL PRIMARY KEY,
                seed_name VARCHAR(255) NOT NULL UNIQUE,
                executed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
              )
            SQL
          rescue ex
            Logger.warn("Failed to create seed_versions table: #{ex.message}")
          end
        end

        # Get seed status
        def get_seed_status : Hash(String, String)
          status = {} of String => String

          find_seed_files.each do |file|
            filename = File.basename(file, ".cr")
            if @executed_seeds.includes?(filename)
              status[filename] = "executed"
            else
              status[filename] = "pending"
            end
          end

          status
        end

        # Force re-run a specific seed
        def force_run_seed(file : String) : Bool
          filename = File.basename(file, ".cr")

          # Remove from executed seeds if it exists
          @executed_seeds.delete(filename)

          # Remove from database
          begin
            execute_on_database("DELETE FROM seed_versions WHERE seed_name = '#{filename}'")
          rescue
            # Ignore errors
          end

          # Run the seed
          run_seed_file(file)
        end

        # List available seeds
        def list_seeds
          seed_files = find_seed_files

          if seed_files.empty?
            Logger.info("No seed files found for environment: #{@environment}")
            return
          end

          Logger.info("Available seed files for environment: #{@environment}")
          Logger.info("=" * 50)

          seed_files.each do |file|
            filename = File.basename(file, ".cr")
            status = @executed_seeds.includes?(filename) ? "✓ executed" : "⏱ pending"
            Logger.info("#{status} #{filename}")
          end
        end
      end
    end
  end
end
