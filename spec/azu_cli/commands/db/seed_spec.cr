require "../../../spec_helper"

describe AzuCLI::Commands::DB::Seed do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::DB::Seed.new
      command.name.should eq("db:seed")
    end

    it "has correct description" do
      command = AzuCLI::Commands::DB::Seed.new
      command.description.should contain("seed")
    end
  end

  describe "option parsing" do
    it "parses --env option" do
      command = AzuCLI::Commands::DB::Seed.new
      command.parse_args(["--env", "test"])

      command.environment.should eq("test")
    end

    it "parses -e short option" do
      command = AzuCLI::Commands::DB::Seed.new
      command.parse_args(["-e", "development"])

      command.environment.should eq("development")
    end
  end
end
