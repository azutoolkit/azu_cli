require "../../../spec_helper"

describe AzuCLI::Commands::Config::Show do
  describe "#execute" do
    it "displays configuration successfully" do
      command = AzuCLI::Commands::Config::Show.new
      command.parse_args([] of String)

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Configuration displayed successfully")
    end

    it "supports yaml format" do
      command = AzuCLI::Commands::Config::Show.new
      command.parse_args(["--format", "yaml"])

      result = command.execute

      result.success?.should be_true
    end

    it "supports json format" do
      command = AzuCLI::Commands::Config::Show.new
      command.parse_args(["--format", "json"])

      result = command.execute

      result.success?.should be_true
    end

    it "supports table format" do
      command = AzuCLI::Commands::Config::Show.new
      command.parse_args(["--format", "table"])

      result = command.execute

      result.success?.should be_true
    end

    it "fails with unknown format" do
      command = AzuCLI::Commands::Config::Show.new
      command.parse_args(["--format", "xml"])

      result = command.execute

      result.success?.should be_false
      result.error.should contain("Unknown format")
    end

    it "filters by section" do
      command = AzuCLI::Commands::Config::Show.new
      command.parse_args(["--section", "database"])

      result = command.execute

      result.success?.should be_true
    end

    it "fails with unknown section" do
      command = AzuCLI::Commands::Config::Show.new
      command.parse_args(["--section", "nonexistent"])

      result = command.execute

      result.success?.should be_false
      result.error.should contain("Unknown configuration section")
    end
  end

  describe "#show_help" do
    it "displays help information" do
      command = AzuCLI::Commands::Config::Show.new
      command.show_help
    end
  end
end
