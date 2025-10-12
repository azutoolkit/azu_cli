require "../../../spec_helper"

describe AzuCLI::Commands::DB::Reset do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::DB::Reset.new
      command.name.should eq("db:reset")
    end

    it "has correct description" do
      command = AzuCLI::Commands::DB::Reset.new
      command.description.should contain("reset")
    end
  end

  describe "option parsing" do
    it "parses --env option" do
      command = AzuCLI::Commands::DB::Reset.new
      command.parse_args(["--env", "test"])

      command.environment.should eq("test")
    end

    it "parses --no-seed option" do
      command = AzuCLI::Commands::DB::Reset.new
      command.parse_args(["--no-seed"])

      command.with_seed.should be_false
    end

    it "parses --seed option" do
      command = AzuCLI::Commands::DB::Reset.new
      command.parse_args(["--seed"])

      command.with_seed.should be_true
    end

    it "parses --force option" do
      command = AzuCLI::Commands::DB::Reset.new
      command.parse_args(["--force"])

      command.force.should be_true
    end

    it "has defaults set correctly" do
      command = AzuCLI::Commands::DB::Reset.new

      command.with_seed.should be_true
      command.force.should be_false
    end
  end
end
