require "../../../spec_helper"

describe AzuCLI::Commands::DB::Drop do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::DB::Drop.new
      command.name.should eq("db:drop")
    end

    it "has correct description" do
      command = AzuCLI::Commands::DB::Drop.new
      command.description.should contain("Drop")
    end
  end

  describe "option parsing" do
    it "parses --force option" do
      command = AzuCLI::Commands::DB::Drop.new
      command.parse_args(["--force"])

      # Command should not crash
      command.name.should eq("db:drop")
    end

    it "parses --database option" do
      command = AzuCLI::Commands::DB::Drop.new
      command.parse_args(["--database", "test_db"])

      command.database_name.should eq("test_db")
    end

    it "parses --env option" do
      command = AzuCLI::Commands::DB::Drop.new
      command.parse_args(["--env", "test"])

      command.environment.should eq("test")
    end
  end
end
