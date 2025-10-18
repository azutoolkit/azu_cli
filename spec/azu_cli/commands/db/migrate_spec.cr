require "../../../spec_helper"

describe AzuCLI::Commands::DB::Migrate do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::DB::Migrate.new
      command.name.should eq("db:migrate")
    end

    it "has correct description" do
      command = AzuCLI::Commands::DB::Migrate.new
      command.description.should contain("migration")
    end

    it "has verbose set to false by default" do
      command = AzuCLI::Commands::DB::Migrate.new
      command.verbose.should be_false
    end

    it "has dry_run set to false by default" do
      command = AzuCLI::Commands::DB::Migrate.new
      command.dry_run.should be_false
    end

    it "has dump_schema method available" do
      command = AzuCLI::Commands::DB::Migrate.new
      # Test that method exists by calling it
      command.dump_schema
    end
  end

  describe "option parsing" do
    it "parses --version option" do
      command = AzuCLI::Commands::DB::Migrate.new
      command.parse_args(["--version", "20241011000000"])

      command.version.should eq(20241011000000_i64)
    end

    it "parses -v short option" do
      command = AzuCLI::Commands::DB::Migrate.new
      command.parse_args(["-v", "12345"])

      command.version.should eq(12345_i64)
    end

    it "parses --verbose option" do
      command = AzuCLI::Commands::DB::Migrate.new
      command.parse_args(["--verbose"])

      command.verbose.should be_true
    end

    it "parses --dry-run option" do
      command = AzuCLI::Commands::DB::Migrate.new
      command.parse_args(["--dry-run"])

      command.dry_run.should be_true
    end

    it "parses --env option" do
      command = AzuCLI::Commands::DB::Migrate.new
      command.parse_args(["--env", "test"])

      command.environment.should eq("test")
    end

    it "parses -e short option" do
      command = AzuCLI::Commands::DB::Migrate.new
      command.parse_args(["-e", "staging"])

      command.environment.should eq("staging")
    end

    it "parses multiple options" do
      command = AzuCLI::Commands::DB::Migrate.new
      command.parse_args(["--verbose", "--dry-run", "--env", "test"])

      command.verbose.should be_true
      command.dry_run.should be_true
      command.environment.should eq("test")
    end
  end

  describe "schema dump integration" do
    it "has access to schema_file_path method" do
      command = AzuCLI::Commands::DB::Migrate.new
      command.schema_file_path.should eq("./src/db/schema.cr")
    end

    it "has access to map_adapter_to_cql method" do
      command = AzuCLI::Commands::DB::Migrate.new
      command.adapter = "postgres"
      command.map_adapter_to_cql.should eq(CQL::Adapter::Postgres)
    end

    it "can call dump_schema without raising errors" do
      command = AzuCLI::Commands::DB::Migrate.new
      # Should not raise error even if db doesn't exist
      # This is a smoke test to verify the method exists and can be called
      command.dump_schema
    end
  end

  describe "migration script generation" do
    it "generates script with relative paths" do
      command = AzuCLI::Commands::DB::Migrate.new

      # Call the test helper method
      script_path = command.test_create_migration_runner_script("up", nil, nil)

      # Read the generated script
      script_content = File.read(script_path)

      # Verify it contains relative paths
      script_content.should contain("require \"./src/db/schema.cr\"")
      script_content.should contain("require \"./src/db/migrations/*\"")

      # Clean up
      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with PostgreSQL driver requirement" do
      command = AzuCLI::Commands::DB::Migrate.new

      # Call the test helper method
      script_path = command.test_create_migration_runner_script("up", nil, nil)

      # Read the generated script
      script_content = File.read(script_path)

      # Verify it contains PostgreSQL driver requirement
      script_content.should contain("require \"pg\"")

      # Clean up
      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with correct CQL configuration" do
      command = AzuCLI::Commands::DB::Migrate.new

      script_path = command.test_create_migration_runner_script("up", nil, nil)
      script_content = File.read(script_path)

      # Verify CQL configuration is present
      script_content.should contain("CQL::MigratorConfig.new")
      script_content.should contain("schema_file_path: \"src/db/schema.cr\"")
      script_content.should contain("schema_name: :")   # Schema name is dynamic
      script_content.should contain("schema_symbol: :") # Schema symbol is dynamic
      script_content.should contain("auto_sync: true")

      # Clean up
      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with version migration command" do
      command = AzuCLI::Commands::DB::Migrate.new

      script_path = command.test_create_migration_runner_script("up", 20241013000000_i64, nil)
      script_content = File.read(script_path)

      # Verify version-specific migration command
      script_content.should contain("migrator.up_to(20241013000000_i64)")

      # Clean up
      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with steps migration command" do
      command = AzuCLI::Commands::DB::Migrate.new

      script_path = command.test_create_migration_runner_script("up", nil, 3)
      script_content = File.read(script_path)

      # Verify steps migration command
      script_content.should contain("migrator.up(3)")

      # Clean up
      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with basic up migration command" do
      command = AzuCLI::Commands::DB::Migrate.new

      script_path = command.test_create_migration_runner_script("up", nil, nil)
      script_content = File.read(script_path)

      # Verify basic up command
      script_content.should contain("migrator.up\n")

      # Clean up
      File.delete(script_path) if File.exists?(script_path)
    end
  end
end
