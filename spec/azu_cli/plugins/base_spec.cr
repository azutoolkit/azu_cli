require "../../spec_helper"

# Create a concrete implementation of Base for testing
class TestPlugin < AzuCLI::Plugins::Base
  property load_called : Bool = false
  property unload_called : Bool = false

  def on_load
    @load_called = true
    super
  end

  def on_unload
    @unload_called = true
    super
  end
end

# Create a test command for plugin testing
class PluginTestCommand < AzuCLI::Commands::Base
  def initialize
    super("plugin_test", "Test command for plugin testing")
  end

  def execute : AzuCLI::Commands::Result
    success("Plugin test executed")
  end
end

describe AzuCLI::Plugins::Base do
  describe "#initialize" do
    it "sets plugin properties" do
      plugin = TestPlugin.new("test_plugin", "A test plugin", "1.0.0")

      plugin.name.should eq("test_plugin")
      plugin.description.should eq("A test plugin")
      plugin.version.should eq("1.0.0")
      plugin.enabled.should be_true
    end

    it "has default values for optional parameters" do
      plugin = TestPlugin.new("minimal")

      plugin.name.should eq("minimal")
      plugin.description.should eq("")
      plugin.version.should eq("1.0.0")
    end
  end

  describe "#on_load" do
    it "logs plugin load" do
      plugin = TestPlugin.new("test_plugin")

      plugin.on_load

      plugin.load_called.should be_true
    end
  end

  describe "#on_unload" do
    it "logs plugin unload" do
      plugin = TestPlugin.new("test_plugin")

      plugin.on_unload

      plugin.unload_called.should be_true
    end
  end

  describe "#before_command" do
    it "can be called without error" do
      plugin = TestPlugin.new("test_plugin")
      command = PluginTestCommand.new

      # Should not raise - default implementation is empty
      plugin.before_command(command, ["arg1", "arg2"])
    end
  end

  describe "#after_command" do
    it "can be called with success result" do
      plugin = TestPlugin.new("test_plugin")
      command = PluginTestCommand.new
      result = command.success("Operation completed")

      plugin.after_command(command, result)
    end

    it "can be called with error result" do
      plugin = TestPlugin.new("test_plugin")
      command = PluginTestCommand.new
      result = command.error("Operation failed")

      plugin.after_command(command, result)
    end
  end

  describe "#on_error" do
    it "can be called with exception" do
      plugin = TestPlugin.new("test_plugin")
      command = PluginTestCommand.new
      exception = Exception.new("Test error")

      plugin.on_error(command, exception)
    end
  end

  describe "#info" do
    it "returns plugin information hash" do
      plugin = TestPlugin.new("test_plugin", "A test plugin", "2.0.0")

      info = plugin.info

      info["name"].should eq("test_plugin")
      info["description"].should eq("A test plugin")
      info["version"].should eq("2.0.0")
      info["enabled"].should eq("true")
    end
  end

  describe "#enable" do
    it "enables the plugin" do
      plugin = TestPlugin.new("test_plugin")
      plugin.disable

      plugin.enable

      plugin.enabled?.should be_true
    end
  end

  describe "#disable" do
    it "disables the plugin" do
      plugin = TestPlugin.new("test_plugin")

      plugin.disable

      plugin.enabled?.should be_false
    end
  end

  describe "#enabled?" do
    it "returns true when enabled" do
      plugin = TestPlugin.new("test_plugin")

      plugin.enabled?.should be_true
    end

    it "returns false when disabled" do
      plugin = TestPlugin.new("test_plugin")
      plugin.disable

      plugin.enabled?.should be_false
    end
  end
end
