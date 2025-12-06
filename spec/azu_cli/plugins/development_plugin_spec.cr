require "../../spec_helper"

# Create test commands for plugin testing
class DevelopmentPluginTestCommand < AzuCLI::Commands::Base
  def initialize(name : String = "serve")
    super(name, "Test command for development plugin")
  end

  def execute : AzuCLI::Commands::Result
    success("Development test executed")
  end
end

describe AzuCLI::Plugins::DevelopmentPlugin do
  describe "#initialize" do
    it "sets correct plugin properties" do
      plugin = AzuCLI::Plugins::DevelopmentPlugin.new

      plugin.name.should eq("development")
      plugin.description.should eq("Development server plugin for Azu CLI")
      plugin.version.should eq("1.0.0")
    end
  end

  describe "#before_command" do
    it "validates serve command" do
      plugin = AzuCLI::Plugins::DevelopmentPlugin.new
      command = DevelopmentPluginTestCommand.new("serve")

      plugin.before_command(command, [] of String)
    end

    it "validates dev command" do
      plugin = AzuCLI::Plugins::DevelopmentPlugin.new
      command = DevelopmentPluginTestCommand.new("dev")

      plugin.before_command(command, [] of String)
    end

    it "ignores non-serve commands" do
      plugin = AzuCLI::Plugins::DevelopmentPlugin.new
      command = DevelopmentPluginTestCommand.new("generate")

      plugin.before_command(command, ["model", "User"])
    end
  end

  describe "#after_command" do
    it "logs success result for serve command" do
      plugin = AzuCLI::Plugins::DevelopmentPlugin.new
      command = DevelopmentPluginTestCommand.new("serve")
      result = command.success("Server started")

      plugin.after_command(command, result)
    end

    it "logs error result for serve command" do
      plugin = AzuCLI::Plugins::DevelopmentPlugin.new
      command = DevelopmentPluginTestCommand.new("serve")
      result = command.error("Server failed to start")

      plugin.after_command(command, result)
    end

    it "logs success result for dev command" do
      plugin = AzuCLI::Plugins::DevelopmentPlugin.new
      command = DevelopmentPluginTestCommand.new("dev")
      result = command.success("Dev server started")

      plugin.after_command(command, result)
    end

    it "ignores non-serve commands" do
      plugin = AzuCLI::Plugins::DevelopmentPlugin.new
      command = DevelopmentPluginTestCommand.new("generate")
      result = command.success("Generated successfully")

      plugin.after_command(command, result)
    end
  end

  describe "#on_error" do
    it "logs error for serve command" do
      plugin = AzuCLI::Plugins::DevelopmentPlugin.new
      command = DevelopmentPluginTestCommand.new("serve")
      exception = Exception.new("Server error")

      plugin.on_error(command, exception)
    end

    it "provides port error suggestions" do
      plugin = AzuCLI::Plugins::DevelopmentPlugin.new
      command = DevelopmentPluginTestCommand.new("serve")
      exception = Exception.new("Cannot bind to port 3000")

      plugin.on_error(command, exception)
    end

    it "provides file not found suggestions" do
      plugin = AzuCLI::Plugins::DevelopmentPlugin.new
      command = DevelopmentPluginTestCommand.new("serve")
      exception = File::NotFoundError.new("Not found", file: "src/app.cr")

      plugin.on_error(command, exception)
    end

    it "handles dev command errors" do
      plugin = AzuCLI::Plugins::DevelopmentPlugin.new
      command = DevelopmentPluginTestCommand.new("dev")
      exception = Exception.new("Development error")

      plugin.on_error(command, exception)
    end

    it "ignores non-serve commands" do
      plugin = AzuCLI::Plugins::DevelopmentPlugin.new
      command = DevelopmentPluginTestCommand.new("generate")
      exception = Exception.new("Generation error")

      plugin.on_error(command, exception)
    end
  end
end
