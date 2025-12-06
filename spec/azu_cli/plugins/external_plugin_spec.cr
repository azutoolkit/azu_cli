require "../../spec_helper"

# Create test command for plugin testing
class ExternalPluginTestCommand < AzuCLI::Commands::Base
  def initialize
    super("external_test", "Test command for external plugin")
  end

  def execute : AzuCLI::Commands::Result
    success("External plugin test executed")
  end
end

describe AzuCLI::Plugins::ExternalPlugin do
  describe "#initialize" do
    it "sets plugin properties from config" do
      config = {
        "description" => "My custom plugin",
        "version"     => "2.0.0",
      }
      plugin = AzuCLI::Plugins::ExternalPlugin.new("custom_plugin", config)

      plugin.name.should eq("custom_plugin")
      plugin.description.should eq("My custom plugin")
      plugin.version.should eq("2.0.0")
    end

    it "uses default description when not provided" do
      config = {} of String => String
      plugin = AzuCLI::Plugins::ExternalPlugin.new("my_plugin", config)

      plugin.description.should eq("External plugin: my_plugin")
    end

    it "uses default version when not provided" do
      config = {} of String => String
      plugin = AzuCLI::Plugins::ExternalPlugin.new("my_plugin", config)

      plugin.version.should eq("1.0.0")
    end
  end

  describe "#on_load" do
    it "logs plugin load with config" do
      config = {"key" => "value"}
      plugin = AzuCLI::Plugins::ExternalPlugin.new("custom_plugin", config)

      plugin.on_load
    end
  end

  describe "#before_command" do
    it "executes before_command hook if configured" do
      config = {"before_command" => "echo 'before'"}
      plugin = AzuCLI::Plugins::ExternalPlugin.new("custom_plugin", config)
      command = ExternalPluginTestCommand.new

      plugin.before_command(command, ["arg1"])
    end

    it "does nothing without hook configuration" do
      config = {} of String => String
      plugin = AzuCLI::Plugins::ExternalPlugin.new("custom_plugin", config)
      command = ExternalPluginTestCommand.new

      plugin.before_command(command, ["arg1"])
    end
  end

  describe "#after_command" do
    it "executes after_command hook if configured" do
      config = {"after_command" => "echo 'after'"}
      plugin = AzuCLI::Plugins::ExternalPlugin.new("custom_plugin", config)
      command = ExternalPluginTestCommand.new
      result = command.success("Completed")

      plugin.after_command(command, result)
    end

    it "does nothing without hook configuration" do
      config = {} of String => String
      plugin = AzuCLI::Plugins::ExternalPlugin.new("custom_plugin", config)
      command = ExternalPluginTestCommand.new
      result = command.success("Completed")

      plugin.after_command(command, result)
    end
  end

  describe "#on_error" do
    it "executes on_error hook if configured" do
      config = {"on_error" => "echo 'error'"}
      plugin = AzuCLI::Plugins::ExternalPlugin.new("custom_plugin", config)
      command = ExternalPluginTestCommand.new
      exception = Exception.new("Test error")

      plugin.on_error(command, exception)
    end

    it "does nothing without hook configuration" do
      config = {} of String => String
      plugin = AzuCLI::Plugins::ExternalPlugin.new("custom_plugin", config)
      command = ExternalPluginTestCommand.new
      exception = Exception.new("Test error")

      plugin.on_error(command, exception)
    end
  end

  describe "#get_config" do
    it "returns config value when present" do
      config = {"key" => "value"}
      plugin = AzuCLI::Plugins::ExternalPlugin.new("custom_plugin", config)

      plugin.get_config("key").should eq("value")
    end

    it "returns default when config not present" do
      config = {} of String => String
      plugin = AzuCLI::Plugins::ExternalPlugin.new("custom_plugin", config)

      plugin.get_config("missing", "default").should eq("default")
    end

    it "returns empty string as default when not specified" do
      config = {} of String => String
      plugin = AzuCLI::Plugins::ExternalPlugin.new("custom_plugin", config)

      plugin.get_config("missing").should eq("")
    end
  end

  describe "#has_config?" do
    it "returns true when config key exists" do
      config = {"key" => "value"}
      plugin = AzuCLI::Plugins::ExternalPlugin.new("custom_plugin", config)

      plugin.has_config?("key").should be_true
    end

    it "returns false when config key does not exist" do
      config = {} of String => String
      plugin = AzuCLI::Plugins::ExternalPlugin.new("custom_plugin", config)

      plugin.has_config?("missing").should be_false
    end
  end
end
