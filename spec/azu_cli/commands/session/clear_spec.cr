require "../../../spec_helper"

describe AzuCLI::Commands::Session::Clear do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::Session::Clear.new
      command.name.should eq("session:clear")
    end

    it "has correct description" do
      command = AzuCLI::Commands::Session::Clear.new
      command.description.should contain("Clear")
    end

    it "has force set to false by default" do
      command = AzuCLI::Commands::Session::Clear.new
      command.force.should be_false
    end

    it "has backend set to nil by default" do
      command = AzuCLI::Commands::Session::Clear.new
      command.backend.should be_nil
    end
  end

  describe "option parsing" do
    it "parses --force option" do
      command = AzuCLI::Commands::Session::Clear.new
      command.parse_args(["--force"])

      command.force.should be_true
    end

    it "parses -f short option" do
      command = AzuCLI::Commands::Session::Clear.new
      command.parse_args(["-f"])

      command.force.should be_true
    end

    it "parses --backend option" do
      command = AzuCLI::Commands::Session::Clear.new
      command.parse_args(["--backend", "redis"])

      command.backend.should eq("redis")
    end

    it "parses -b short option" do
      command = AzuCLI::Commands::Session::Clear.new
      command.parse_args(["-b", "database"])

      command.backend.should eq("database")
    end

    it "parses multiple options" do
      command = AzuCLI::Commands::Session::Clear.new
      command.parse_args(["--backend", "memory", "--force"])

      command.backend.should eq("memory")
      command.force.should be_true
    end
  end
end
