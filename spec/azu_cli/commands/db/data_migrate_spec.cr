require "../../../spec_helper"

describe AzuCLI::Commands::DB::DataMigrate do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::DB::DataMigrate.new
      command.name.should eq("db:data:migrate")
    end

    it "has correct description" do
      command = AzuCLI::Commands::DB::DataMigrate.new
      command.description.should contain("data migration")
    end

    it "has verbose set to false by default" do
      command = AzuCLI::Commands::DB::DataMigrate.new
      command.verbose.should be_false
    end

    it "has dry_run set to false by default" do
      command = AzuCLI::Commands::DB::DataMigrate.new
      command.dry_run.should be_false
    end
  end

  describe "option parsing" do
    it "parses --version option" do
      command = AzuCLI::Commands::DB::DataMigrate.new
      command.parse_args(["--version", "20241011000000"])

      command.version.should eq(20241011000000_i64)
    end

    it "parses -v short option" do
      command = AzuCLI::Commands::DB::DataMigrate.new
      command.parse_args(["-v", "12345"])

      command.version.should eq(12345_i64)
    end

    it "parses --steps option" do
      command = AzuCLI::Commands::DB::DataMigrate.new
      command.parse_args(["--steps", "5"])

      command.steps.should eq(5)
    end

    it "parses -s short option" do
      command = AzuCLI::Commands::DB::DataMigrate.new
      command.parse_args(["-s", "3"])

      command.steps.should eq(3)
    end

    it "parses --verbose option" do
      command = AzuCLI::Commands::DB::DataMigrate.new
      command.parse_args(["--verbose"])

      command.verbose.should be_true
    end

    it "parses --dry-run option" do
      command = AzuCLI::Commands::DB::DataMigrate.new
      command.parse_args(["--dry-run"])

      command.dry_run.should be_true
    end

    it "parses --env option" do
      command = AzuCLI::Commands::DB::DataMigrate.new
      command.parse_args(["--env", "test"])

      command.environment.should eq("test")
    end

    it "parses -e short option" do
      command = AzuCLI::Commands::DB::DataMigrate.new
      command.parse_args(["-e", "staging"])

      command.environment.should eq("staging")
    end

    it "parses multiple options" do
      command = AzuCLI::Commands::DB::DataMigrate.new
      command.parse_args(["--verbose", "--dry-run", "--env", "test", "--steps", "2"])

      command.verbose.should be_true
      command.dry_run.should be_true
      command.environment.should eq("test")
      command.steps.should eq(2)
    end
  end

  describe "data migration script generation" do
    it "generates script with relative paths" do
      command = AzuCLI::Commands::DB::DataMigrate.new

      script_path = command.test_create_data_migration_runner_script("up", nil, nil)
      script_content = File.read(script_path)

      script_content.should contain("require \"./src/db/schema.cr\"")
      script_content.should contain("require \"./src/db/data_migrations/*\"")

      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with PostgreSQL driver requirement" do
      command = AzuCLI::Commands::DB::DataMigrate.new

      script_path = command.test_create_data_migration_runner_script("up", nil, nil)
      script_content = File.read(script_path)

      script_content.should contain("require \"pg\"")

      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with auto_sync set to false" do
      command = AzuCLI::Commands::DB::DataMigrate.new

      script_path = command.test_create_data_migration_runner_script("up", nil, nil)
      script_content = File.read(script_path)

      # Data migrations don't affect schema
      script_content.should contain("auto_sync: false")

      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with version migration command" do
      command = AzuCLI::Commands::DB::DataMigrate.new

      script_path = command.test_create_data_migration_runner_script("up", 20241013000000_i64, nil)
      script_content = File.read(script_path)

      script_content.should contain("migrator.up_to(20241013000000_i64)")

      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with steps migration command" do
      command = AzuCLI::Commands::DB::DataMigrate.new

      script_path = command.test_create_data_migration_runner_script("up", nil, 3)
      script_content = File.read(script_path)

      script_content.should contain("migrator.up(3)")

      File.delete(script_path) if File.exists?(script_path)
    end

    it "generates script with basic up migration command" do
      command = AzuCLI::Commands::DB::DataMigrate.new

      script_path = command.test_create_data_migration_runner_script("up", nil, nil)
      script_content = File.read(script_path)

      script_content.should contain("migrator.up\n")

      File.delete(script_path) if File.exists?(script_path)
    end
  end
end
