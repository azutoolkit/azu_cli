require "../../../spec_helper"

describe AzuCLI::Commands::Jobs::Retry do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::Jobs::Retry.new
      command.name.should eq("jobs:retry")
    end

    it "has correct description" do
      command = AzuCLI::Commands::Jobs::Retry.new
      command.description.should contain("retry")
    end
  end

  describe "default properties" do
    it "has all set to false by default" do
      command = AzuCLI::Commands::Jobs::Retry.new
      command.all.should be_false
    end
  end

  describe "option parsing" do
    it "parses --all option" do
      command = AzuCLI::Commands::Jobs::Retry.new
      command.parse_args(["--all"])

      command.all.should be_true
    end

    it "parses --queue option" do
      command = AzuCLI::Commands::Jobs::Retry.new
      command.parse_args(["--queue", "critical"])

      command.queue.should eq("critical")
    end

    it "parses -q short option" do
      command = AzuCLI::Commands::Jobs::Retry.new
      command.parse_args(["-q", "high"])

      command.queue.should eq("high")
    end

    it "parses --verbose option" do
      command = AzuCLI::Commands::Jobs::Retry.new
      command.parse_args(["--verbose"])

      command.verbose.should be_true
    end
  end
end
