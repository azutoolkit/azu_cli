require "../../spec_helper"

describe AzuCLI::Commands::Plugin do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::Plugin.new
      command.name.should eq("plugin")
    end

    it "has correct description" do
      command = AzuCLI::Commands::Plugin.new
      command.description.should contain("Plugin")
    end
  end

  describe "#execute" do
    it "requires operation argument" do
      command = AzuCLI::Commands::Plugin.new
      command.parse_args([] of String)

      result = command.execute

      result.success?.should be_false
      result.error.should contain("Usage")
    end

    it "handles list operation" do
      command = AzuCLI::Commands::Plugin.new
      command.parse_args(["list"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Plugin list displayed")
    end

    it "handles install operation with plugin name" do
      command = AzuCLI::Commands::Plugin.new
      command.parse_args(["install", "my-plugin"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("my-plugin")
    end

    it "handles install operation without plugin name" do
      command = AzuCLI::Commands::Plugin.new
      command.parse_args(["install"])

      result = command.execute

      result.success?.should be_false
      result.error.should contain("Plugin name is required")
    end

    it "handles uninstall operation with plugin name" do
      command = AzuCLI::Commands::Plugin.new
      command.parse_args(["uninstall", "my-plugin"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("my-plugin")
    end

    it "handles uninstall operation without plugin name" do
      command = AzuCLI::Commands::Plugin.new
      command.parse_args(["uninstall"])

      result = command.execute

      result.success?.should be_false
      result.error.should contain("Plugin name is required")
    end

    it "handles enable operation with plugin name" do
      command = AzuCLI::Commands::Plugin.new
      command.parse_args(["enable", "my-plugin"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("my-plugin")
    end

    it "handles enable operation without plugin name" do
      command = AzuCLI::Commands::Plugin.new
      command.parse_args(["enable"])

      result = command.execute

      result.success?.should be_false
      result.error.should contain("Plugin name is required")
    end

    it "handles disable operation with plugin name" do
      command = AzuCLI::Commands::Plugin.new
      command.parse_args(["disable", "my-plugin"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("my-plugin")
    end

    it "handles disable operation without plugin name" do
      command = AzuCLI::Commands::Plugin.new
      command.parse_args(["disable"])

      result = command.execute

      result.success?.should be_false
      result.error.should contain("Plugin name is required")
    end

    it "handles info operation with plugin name" do
      command = AzuCLI::Commands::Plugin.new
      command.parse_args(["info", "generator"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Plugin information displayed")
    end

    it "handles info operation without plugin name" do
      command = AzuCLI::Commands::Plugin.new
      command.parse_args(["info"])

      result = command.execute

      result.success?.should be_false
      result.error.should contain("Plugin name is required")
    end

    it "handles unknown operation" do
      command = AzuCLI::Commands::Plugin.new
      command.parse_args(["unknown"])

      result = command.execute

      result.success?.should be_false
      result.error.should contain("Unknown plugin operation")
    end
  end

  describe "#show_help" do
    it "displays help information" do
      command = AzuCLI::Commands::Plugin.new

      # Just ensure it doesn't crash
      command.show_help
    end
  end
end
