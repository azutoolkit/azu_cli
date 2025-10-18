require "../../../spec_helper"

describe AzuCLI::Commands::DB::Rollback do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::DB::Rollback.new
      command.name.should eq("db:rollback")
    end

    it "has correct description" do
      command = AzuCLI::Commands::DB::Rollback.new
      command.description.should contain("Rollback")
    end
  end

  describe "option parsing" do
    it "parses --steps option" do
      command = AzuCLI::Commands::DB::Rollback.new
      command.parse_args(["--steps", "3"])

      command.steps.should eq(3)
    end

    it "parses -s short option" do
      command = AzuCLI::Commands::DB::Rollback.new
      command.parse_args(["-s", "5"])

      command.steps.should eq(5)
    end

    it "parses --verbose option" do
      command = AzuCLI::Commands::DB::Rollback.new
      command.parse_args(["--verbose"])

      command.verbose.should be_true
    end

    it "parses --env option" do
      command = AzuCLI::Commands::DB::Rollback.new
      command.parse_args(["--env", "test"])

      command.environment.should eq("test")
    end

    it "has default steps of 1" do
      command = AzuCLI::Commands::DB::Rollback.new
      command.steps.should eq(1)
    end
  end

  describe "schema dump integration" do
    it "has dump_schema method available" do
      command = AzuCLI::Commands::DB::Rollback.new
      # Test that method exists by calling it
      command.dump_schema
    end

    it "has access to schema_file_path method" do
      command = AzuCLI::Commands::DB::Rollback.new
      command.schema_file_path.should eq("./src/db/schema.cr")
    end

    it "can call dump_schema without raising errors" do
      command = AzuCLI::Commands::DB::Rollback.new
      # Should not raise error even if db doesn't exist
      # This is a smoke test to verify the method exists and can be called
      command.dump_schema
    end
  end

  describe "rollback script generation" do
    it "generates script with relative paths" do
      command = AzuCLI::Commands::DB::Rollback.new

      # Call the test helper method
      script_path = command.test_create_migration_runner_script("down", nil, nil)

      # Read the generated script
      script_content = File.read(script_path)

      # Verify it contains relative paths
      script_content.should contain("require \"./src/db/schema.cr\"")
      script_content.should contain("require \"./src/db/migrations/*\"")

      # Clean up
      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with PostgreSQL driver requirement" do
      command = AzuCLI::Commands::DB::Rollback.new

      # Call the test helper method
      script_path = command.test_create_migration_runner_script("down", nil, nil)

      # Read the generated script
      script_content = File.read(script_path)

      # Verify it contains PostgreSQL driver requirement
      script_content.should contain("require \"pg\"")

      # Clean up
      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with correct CQL configuration" do
      command = AzuCLI::Commands::DB::Rollback.new

      script_path = command.test_create_migration_runner_script("down", nil, nil)
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

    it "generates script with version rollback command" do
      command = AzuCLI::Commands::DB::Rollback.new

      script_path = command.test_create_migration_runner_script("down", 20241013000000_i64, nil)
      script_content = File.read(script_path)

      # Verify version-specific rollback command
      script_content.should contain("migrator.down_to(20241013000000_i64)")

      # Clean up
      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with steps rollback command" do
      command = AzuCLI::Commands::DB::Rollback.new

      script_path = command.test_create_migration_runner_script("down", nil, 2)
      script_content = File.read(script_path)

      # Verify steps rollback command
      script_content.should contain("migrator.rollback(2)")

      # Clean up
      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with basic rollback command" do
      command = AzuCLI::Commands::DB::Rollback.new

      script_path = command.test_create_migration_runner_script("down", nil, nil)
      script_content = File.read(script_path)

      # Verify basic rollback command
      script_content.should contain("migrator.rollback(1)")

      # Clean up
      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with redo command" do
      command = AzuCLI::Commands::DB::Rollback.new

      script_path = command.test_create_migration_runner_script("redo", nil, nil)
      script_content = File.read(script_path)

      # Verify redo command
      script_content.should contain("migrator.redo")

      # Clean up
      File.delete(script_path) if File.exists?(script_path)
    end
  end
end
