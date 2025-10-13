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
end
