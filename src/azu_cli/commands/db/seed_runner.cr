require "../database"
require "../../scratch_file"

module AzuCLI::Commands::DB
  # Runs application seeds after loading their database configuration, with durable
  # completion records. Seeds must remain idempotent: their effects and recording
  # completion happen in separate processes and cannot share one transaction.
  class SeedRunner < Database
    property seeds_dir : String
    getter executed_seeds = [] of String

    def initialize(environment : String = "development", @seeds_dir : String = "./src/db/seeds")
      super("seed:runner", "Seed file runner with dependency management")
      @environment = environment
    end

    def execute : Result
      success("Seed runner initialized")
    end

    def run_seeds(names : Array(String)? = nil) : Bool
      files = names ? resolve_files(names) : find_seed_files
      return true if files.empty?
      files.all? { |file| run_seed_file(file) }
    end

    def run_seed_file(file : String) : Bool
      path = seed_path(file)
      ensure_seed_versions_table
      load_executed_seeds
      key = seed_key(path)
      if executed?(path)
        Logger.info("Skipping already executed seed: #{key}")
        return true
      end
      script = database_script_header
      script += "require \"./src/models/**\"\n" unless Dir.glob("./src/models/**/*.cr").empty?
      script += "require #{("./" + key).inspect}\n"
      env = {"DATABASE_URL" => database_connection_url, "AZU_ENV" => @environment, "CRYSTAL_ENV" => @environment}
      ok = AzuCLI::ScratchFile.with(".azu_seed_", script) do |runner|
        run_crystal_script(runner, "Seed", env)
      end
      return false unless ok
      marker = @adapter.in?("postgres", "postgresql") ? "$1" : "?"
      ::DB.open(database_connection_url) do |db|
        db.exec("INSERT INTO seed_versions (seed_name) VALUES (#{marker})", key)
      end
      @executed_seeds << key
      Logger.info("Seed completed: #{key}")
      true
    rescue ex
      Logger.error("Seed failed: #{ex.message}")
      false
    end

    # Directory-based seeds and the legacy entry point are both supported. New
    # projects leave the legacy file as documentation only; it is safe to delete.
    def find_seed_files : Array(String)
      files = [] of String
      files << "./src/db/seed.cr" if File.file?("./src/db/seed.cr")
      files.concat(Dir.glob(File.join(@seeds_dir, "shared", "*.cr")).sort)
      files.concat(Dir.glob(File.join(@seeds_dir, @environment, "*.cr")).sort)
      files.uniq
    end

    def resolve_files(names : Array(String)) : Array(String)
      available = find_seed_files
      names.map do |name|
        matches = available.select do |file|
          stem = File.basename(file, ".cr")
          name == file || name == seed_key(file) || name == File.basename(file) || name == stem || name == stem.sub(/^\d+_/, "")
        end
        raise ArgumentError.new("Seed '#{name}' must match exactly one available seed (found #{matches.size}); use db:seed --list") unless matches.size == 1
        matches.first
      end.uniq
    end

    def get_seed_status : Hash(String, String)
      load_executed_seeds
      find_seed_files.to_h { |file| {seed_key(file), executed?(file) ? "executed" : "pending"} }
    end

    def force_run_seed(file : String) : Bool
      path = seed_path(file)
      ensure_seed_versions_table
      marker = @adapter.in?("postgres", "postgresql") ? "$1" : "?"
      ::DB.open(database_connection_url) do |db|
        db.exec("DELETE FROM seed_versions WHERE seed_name = #{marker}", seed_key(path))
        # Remove unambiguous records written by the older basename-based runner.
        if unique_legacy_name?(path)
          db.exec("DELETE FROM seed_versions WHERE seed_name = #{marker}", File.basename(path, ".cr"))
        end
      end
      run_seed_file(path)
    rescue ex
      Logger.error("Seed failed: #{ex.message}")
      false
    end

    def list_seeds
      get_seed_status.each { |name, status| Logger.info("#{status}: #{name}") }
    end

    private def seed_path(file : String) : String
      root = File.realpath(Dir.current)
      path = File.realpath(file)
      unless path.starts_with?(root + File::SEPARATOR) && path.ends_with?(".cr") && File.file?(path)
        raise ArgumentError.new("Seed file must be a Crystal file inside the project")
      end
      path
    end

    private def seed_key(file : String) : String
      Path[seed_path(file)].relative_to(File.realpath(Dir.current)).to_s
    end

    private def unique_legacy_name?(file : String) : Bool
      name = File.basename(file, ".cr")
      find_seed_files.count { |candidate| File.basename(candidate, ".cr") == name } == 1
    end

    private def executed?(file : String) : Bool
      @executed_seeds.includes?(seed_key(file)) ||
        (@executed_seeds.includes?(File.basename(file, ".cr")) && unique_legacy_name?(file))
    end

    private def load_executed_seeds
      @executed_seeds.clear
      query_database("SELECT seed_name FROM seed_versions ORDER BY executed_at") do |rs|
        rs.each { @executed_seeds << rs.read(String) }
      end
    rescue ex
      # A fresh database has no tracking table. Connection and other errors must
      # remain visible, rather than causing already-run seeds to execute again.
      raise ex unless ex.message.to_s.matches?(/no such table|does not exist|doesn't exist/i)
    end

    private def ensure_seed_versions_table
      execute_on_database(<<-SQL)
        CREATE TABLE IF NOT EXISTS seed_versions (
          seed_name VARCHAR(255) PRIMARY KEY,
          executed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        SQL
    end
  end
end
