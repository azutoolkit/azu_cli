require "../../../spec_helper"

describe AzuCLI::Commands::DB::Setup do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::DB::Setup.new
      command.name.should eq("db:setup")
    end

    it "has correct description" do
      command = AzuCLI::Commands::DB::Setup.new
      command.description.should contain("setup")
    end
  end

  describe "option parsing" do
    it "parses --env option" do
      command = AzuCLI::Commands::DB::Setup.new
      command.parse_args(["--env", "test"])

      command.environment.should eq("test")
    end

    it "parses --seed option" do
      command = AzuCLI::Commands::DB::Setup.new
      command.parse_args(["--seed"])

      command.with_seed.should be_true
    end

    it "parses --no-seed option" do
      command = AzuCLI::Commands::DB::Setup.new
      command.parse_args(["--no-seed"])

      command.with_seed.should be_false
    end

    it "has with_seed set to false by default" do
      command = AzuCLI::Commands::DB::Setup.new
      command.with_seed.should be_false
    end
  end
end
