require "../../spec_helper"

# Create test commands for plugin testing
class GeneratorPluginTestCommand < AzuCLI::Commands::Base
  def initialize(name : String = "generate")
    super(name, "Test command for generator plugin")
  end

  def execute : AzuCLI::Commands::Result
    success("Generator test executed")
  end
end

describe AzuCLI::Plugins::GeneratorPlugin do
  describe "#initialize" do
    it "sets correct plugin properties" do
      plugin = AzuCLI::Plugins::GeneratorPlugin.new

      plugin.name.should eq("generator")
      plugin.description.should eq("Code generation plugin for Azu CLI")
      plugin.version.should eq("1.0.0")
    end
  end

  describe "#before_command" do
    it "validates generate command with valid type" do
      plugin = AzuCLI::Plugins::GeneratorPlugin.new
      command = GeneratorPluginTestCommand.new("generate")

      plugin.before_command(command, ["model", "User"])
    end

    it "validates generate command with auth type (no name required)" do
      plugin = AzuCLI::Plugins::GeneratorPlugin.new
      command = GeneratorPluginTestCommand.new("generate")

      plugin.before_command(command, ["auth"])
    end

    it "ignores non-generate commands" do
      plugin = AzuCLI::Plugins::GeneratorPlugin.new
      command = GeneratorPluginTestCommand.new("db")

      # Should not raise for non-generate commands
      plugin.before_command(command, ["migrate"])
    end

    it "allows help flags" do
      plugin = AzuCLI::Plugins::GeneratorPlugin.new
      command = GeneratorPluginTestCommand.new("generate")

      plugin.before_command(command, ["--help"])
    end

    it "raises on invalid generator type" do
      plugin = AzuCLI::Plugins::GeneratorPlugin.new
      command = GeneratorPluginTestCommand.new("generate")

      expect_raises(ArgumentError, /Invalid generator type/) do
        plugin.before_command(command, ["invalid_type"])
      end
    end

    it "raises on missing generator name" do
      plugin = AzuCLI::Plugins::GeneratorPlugin.new
      command = GeneratorPluginTestCommand.new("generate")

      expect_raises(ArgumentError, /Generator name is required/) do
        plugin.before_command(command, ["model"])
      end
    end

    it "raises on empty args" do
      plugin = AzuCLI::Plugins::GeneratorPlugin.new
      command = GeneratorPluginTestCommand.new("generate")

      expect_raises(ArgumentError, /Generator type is required/) do
        plugin.before_command(command, [] of String)
      end
    end
  end

  describe "#after_command" do
    it "logs success result for generate command" do
      plugin = AzuCLI::Plugins::GeneratorPlugin.new
      command = GeneratorPluginTestCommand.new("generate")
      result = command.success("Generated successfully")

      plugin.after_command(command, result)
    end

    it "logs error result for generate command" do
      plugin = AzuCLI::Plugins::GeneratorPlugin.new
      command = GeneratorPluginTestCommand.new("generate")
      result = command.error("Generation failed")

      plugin.after_command(command, result)
    end

    it "ignores non-generate commands" do
      plugin = AzuCLI::Plugins::GeneratorPlugin.new
      command = GeneratorPluginTestCommand.new("db")
      result = command.success("Database operation completed")

      plugin.after_command(command, result)
    end
  end

  describe "#on_error" do
    it "logs error for generate command" do
      plugin = AzuCLI::Plugins::GeneratorPlugin.new
      command = GeneratorPluginTestCommand.new("generate")
      exception = Exception.new("Generation failed")

      plugin.on_error(command, exception)
    end

    it "ignores non-generate commands" do
      plugin = AzuCLI::Plugins::GeneratorPlugin.new
      command = GeneratorPluginTestCommand.new("db")
      exception = Exception.new("Database error")

      plugin.on_error(command, exception)
    end
  end

  describe "#available_generators" do
    it "returns list of available generators" do
      plugin = AzuCLI::Plugins::GeneratorPlugin.new

      generators = plugin.available_generators

      generators.size.should be > 0
      generators.any? { |g| g.includes?("model") }.should be_true
      generators.any? { |g| g.includes?("endpoint") }.should be_true
      generators.any? { |g| g.includes?("service") }.should be_true
    end
  end
end
