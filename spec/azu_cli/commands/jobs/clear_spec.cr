require "../../../spec_helper"

describe AzuCLI::Commands::Jobs::Clear do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::Jobs::Clear.new
      command.name.should eq("jobs:clear")
    end

    it "has correct description" do
      command = AzuCLI::Commands::Jobs::Clear.new
      command.description.should contain("clear")
    end
  end

  describe "default properties" do
    it "has all set to false by default" do
      command = AzuCLI::Commands::Jobs::Clear.new
      command.all.should be_false
    end

    it "has failed set to false by default" do
      command = AzuCLI::Commands::Jobs::Clear.new
      command.failed.should be_false
    end

    it "has force set to false by default" do
      command = AzuCLI::Commands::Jobs::Clear.new
      command.force.should be_false
    end
  end

  describe "option parsing" do
    it "parses --all option" do
      command = AzuCLI::Commands::Jobs::Clear.new
      command.parse_args(["--all"])

      command.all.should be_true
    end

    it "parses --failed option" do
      command = AzuCLI::Commands::Jobs::Clear.new
      command.parse_args(["--failed"])

      command.failed.should be_true
    end

    it "parses --force option" do
      command = AzuCLI::Commands::Jobs::Clear.new
      command.parse_args(["--force"])

      command.force.should be_true
    end

    it "parses -f short option" do
      command = AzuCLI::Commands::Jobs::Clear.new
      command.parse_args(["-f"])

      command.force.should be_true
    end

    it "parses --queue option" do
      command = AzuCLI::Commands::Jobs::Clear.new
      command.parse_args(["--queue", "mailers"])

      command.queue.should eq("mailers")
    end

    it "parses -q short option" do
      command = AzuCLI::Commands::Jobs::Clear.new
      command.parse_args(["-q", "notifications"])

      command.queue.should eq("notifications")
    end
  end
end
