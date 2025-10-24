require "file_utils"

module TestHelpers
  # Temporary directory management for file generation tests
  class TempProject
    getter path : String
    getter original_dir : String

    def initialize(project_name : String = "test_project")
      @original_dir = Dir.current
      @path = File.join(Dir.tempdir, "azu_cli_test_#{project_name}_#{Time.utc.to_unix}")
      Dir.mkdir_p(@path)
      Dir.cd(@path)
    end

    def cleanup
      Dir.cd(@original_dir)
      FileUtils.rm_rf(@path) if Dir.exists?(@path)
    end

    def create_shard_yml(content : String = default_shard_content)
      File.write("shard.yml", content)
    end

    def create_config_dir
      Dir.mkdir_p("config")
    end

    def create_src_dir
      Dir.mkdir_p("src")
    end

    def create_spec_dir
      Dir.mkdir_p("spec")
    end

    private def default_shard_content
      <<-YAML
      name: test_project
      version: 0.1.0
      authors:
        - Test Author <test@example.com>
      description: Test project for Azu CLI
      license: MIT
      dependencies:
        azu:
          github: azutoolkit/azu
        cql:
          github: azutoolkit/cql
      YAML
    end
  end

  # File comparison helpers for generated file verification
  module FileComparison
    def self.compare_files(expected_path : String, actual_path : String) : Bool
      return false unless File.exists?(expected_path) && File.exists?(actual_path)

      expected_content = File.read(expected_path)
      actual_content = File.read(actual_path)

      expected_content == actual_content
    end

    def self.compare_content(expected_content : String, actual_content : String) : Bool
      expected_content == actual_content
    end

    def self.normalize_content(content : String) : String
      # Normalize line endings and whitespace for comparison
      content.gsub(/\r\n/, "\n")
        .gsub(/\r/, "\n")
        .strip
    end
  end

  # Captured output helpers for CLI output testing
  class OutputCapture
    getter stdout : String
    getter stderr : String

    def initialize
      @stdout = ""
      @stderr = ""
    end

    def capture_stdout(&block)
      # For now, just execute the block without capturing output
      # This can be enhanced later with proper output capture
      yield
      @stdout = ""
      @stderr = ""
    end
  end

  # Mock database adapter for database command tests
  class MockDatabaseAdapter
    getter migrations_run : Array(String) = [] of String
    getter seeds_run : Bool = false
    getter schema_loaded : Bool = false

    def run_migration(migration_name : String)
      @migrations_run << migration_name
    end

    def run_seeds
      @seeds_run = true
    end

    def load_schema
      @schema_loaded = true
    end

    def reset!
      @migrations_run.clear
      @seeds_run = false
      @schema_loaded = false
    end
  end

  # Fixture project generators for integration tests
  module FixtureProject
    def self.create_minimal_project(path : String)
      Dir.mkdir_p(path)
      Dir.cd(path) do
        # Create shard.yml
        File.write("shard.yml", minimal_shard_content)

        # Create basic structure
        Dir.mkdir_p("src")
        Dir.mkdir_p("spec")
        Dir.mkdir_p("config")

        # Create basic source file
        File.write("src/test_project.cr", minimal_source_content)

        # Create spec file
        File.write("spec/test_project_spec.cr", minimal_spec_content)
      end
    end

    def self.create_azu_project(path : String)
      Dir.mkdir_p(path)
      Dir.cd(path) do
        # Create shard.yml with Azu dependencies
        File.write("shard.yml", azu_shard_content)

        # Create Azu project structure
        Dir.mkdir_p("src")
        Dir.mkdir_p("spec")
        Dir.mkdir_p("config")
        Dir.mkdir_p("src/models")
        Dir.mkdir_p("src/endpoints")
        Dir.mkdir_p("src/services")
        Dir.mkdir_p("src/requests")
        Dir.mkdir_p("src/pages")
        Dir.mkdir_p("db/migrations")

        # Create basic Azu files
        File.write("src/server.cr", azu_server_content)
        File.write("config/azu.yml", azu_config_content)
        File.write("src/db/schema.cr", azu_schema_content)
      end
    end

    private def self.minimal_shard_content
      <<-YAML
      name: test_project
      version: 0.1.0
      authors:
        - Test Author <test@example.com>
      description: Test project
      license: MIT
      YAML
    end

    private def self.azu_shard_content
      <<-YAML
      name: test_azu_project
      version: 0.1.0
      authors:
        - Test Author <test@example.com>
      description: Test Azu project
      license: MIT
      dependencies:
        azu:
          github: azutoolkit/azu
        cql:
          github: azutoolkit/cql
      YAML
    end

    private def self.minimal_source_content
      <<-CRYSTAL
      puts "Hello, World!"
      CRYSTAL
    end

    private def self.minimal_spec_content
      <<-CRYSTAL
      require "spec"
      require "../src/test_project"

      describe "TestProject" do
        it "works" do
          true.should be_true
        end
      end
      CRYSTAL
    end

    private def self.azu_server_content
      <<-CRYSTAL
      require "azu"

      # Your Azu application code here
      puts "Azu server starting..."
      CRYSTAL
    end

    private def self.azu_config_content
      <<-YAML
      database:
        adapter: postgresql
        database: test_db
        host: localhost
        port: 5432
      YAML
    end

    private def self.azu_schema_content
      <<-CRYSTAL
      require "cql"

      # Database schema definitions
      CRYSTAL
    end
  end

  # Test setup and teardown helpers
  module TestSetup
    def self.with_temp_project(project_name : String = "test_project", &block)
      temp_project = TempProject.new(project_name)
      begin
        yield temp_project
      ensure
        temp_project.cleanup
      end
    end

    def self.with_captured_output(&block)
      capture = OutputCapture.new
      capture.capture_stdout do
        yield capture
      end
      capture
    end
  end
end
