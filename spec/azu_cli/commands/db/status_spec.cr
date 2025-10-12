require "../../../spec_helper"

describe AzuCLI::Commands::DB::Status do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::DB::Status.new
      command.name.should eq("db:status")
    end

    it "has correct description" do
      command = AzuCLI::Commands::DB::Status.new
      command.description.should contain("status")
    end
  end

  describe "option parsing" do
    it "parses --env option" do
      command = AzuCLI::Commands::DB::Status.new
      command.parse_args(["--env", "test"])

      command.environment.should eq("test")
    end

    it "parses -e short option" do
      command = AzuCLI::Commands::DB::Status.new
      command.parse_args(["-e", "production"])

      command.environment.should eq("production")
    end
  end
end
