require "../../../spec_helper"

describe AzuCLI::Commands::DB::Verify do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::DB::Verify.new
      command.name.should eq("db:migrations:verify")
    end

    it "has correct description" do
      command = AzuCLI::Commands::DB::Verify.new
      command.description.should contain("Verify")
    end

    it "has test_rollback set to true by default" do
      command = AzuCLI::Commands::DB::Verify.new
      command.test_rollback.should be_true
    end

    it "has verbose set to false by default" do
      command = AzuCLI::Commands::DB::Verify.new
      command.verbose.should be_false
    end
  end

  describe "option parsing" do
    it "parses --no-rollback option" do
      command = AzuCLI::Commands::DB::Verify.new
      command.parse_args(["--no-rollback"])

      command.test_rollback.should be_false
    end

    it "parses --verbose option" do
      command = AzuCLI::Commands::DB::Verify.new
      command.parse_args(["--verbose"])

      command.verbose.should be_true
    end

    it "parses --env option" do
      command = AzuCLI::Commands::DB::Verify.new
      command.parse_args(["--env", "test"])

      command.environment.should eq("test")
    end

    it "parses -e short option" do
      command = AzuCLI::Commands::DB::Verify.new
      command.parse_args(["-e", "staging"])

      command.environment.should eq("staging")
    end

    it "parses multiple options" do
      command = AzuCLI::Commands::DB::Verify.new
      command.parse_args(["--verbose", "--no-rollback", "--env", "test"])

      command.verbose.should be_true
      command.test_rollback.should be_false
      command.environment.should eq("test")
    end
  end

end
