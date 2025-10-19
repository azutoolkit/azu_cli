require "../../../spec_helper"

describe AzuCLI::Commands::Session::Setup do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::Session::Setup.new
      command.name.should eq("session:setup")
    end

    it "has correct description" do
      command = AzuCLI::Commands::Session::Setup.new
      command.description.should contain("session")
    end

    it "has default backend of redis" do
      command = AzuCLI::Commands::Session::Setup.new
      command.backend.should eq("redis")
    end

    it "has force set to false by default" do
      command = AzuCLI::Commands::Session::Setup.new
      command.force.should be_false
    end
  end

  describe "option parsing" do
    it "parses --backend option" do
      command = AzuCLI::Commands::Session::Setup.new
      command.parse_args(["--backend", "database"])

      command.backend.should eq("database")
    end

    it "parses -b short option" do
      command = AzuCLI::Commands::Session::Setup.new
      command.parse_args(["-b", "memory"])

      command.backend.should eq("memory")
    end

    it "accepts redis backend" do
      command = AzuCLI::Commands::Session::Setup.new
      command.parse_args(["--backend", "redis"])

      command.backend.should eq("redis")
    end

    it "accepts database backend" do
      command = AzuCLI::Commands::Session::Setup.new
      command.parse_args(["--backend", "database"])

      command.backend.should eq("database")
    end

    it "accepts memory backend" do
      command = AzuCLI::Commands::Session::Setup.new
      command.parse_args(["--backend", "memory"])

      command.backend.should eq("memory")
    end

    it "ignores invalid backend" do
      command = AzuCLI::Commands::Session::Setup.new
      command.parse_args(["--backend", "invalid"])

      # Should keep default
      command.backend.should eq("redis")
    end

    it "parses --force option" do
      command = AzuCLI::Commands::Session::Setup.new
      command.parse_args(["--force"])

      command.force.should be_true
    end

    it "parses -f short option" do
      command = AzuCLI::Commands::Session::Setup.new
      command.parse_args(["-f"])

      command.force.should be_true
    end

    it "parses multiple options" do
      command = AzuCLI::Commands::Session::Setup.new
      command.parse_args(["--backend", "database", "--force"])

      command.backend.should eq("database")
      command.force.should be_true
    end
  end
end
