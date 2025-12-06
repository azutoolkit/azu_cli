require "../../spec_helper"

# Create test commands for configuration middleware testing
class ConfigTestCommand < AzuCLI::Commands::Base
  def initialize(name : String = "config_test")
    super(name, "Test command for configuration middleware")
  end

  def execute : AzuCLI::Commands::Result
    success("Config test executed")
  end
end

describe AzuCLI::Middleware::Configuration do
  describe "#before" do
    it "loads configuration" do
      middleware = AzuCLI::Middleware::Configuration.new
      command = ConfigTestCommand.new

      # Should not raise
      middleware.before(command, [] of String)
    end

    it "validates configuration for generate command" do
      middleware = AzuCLI::Middleware::Configuration.new
      command = ConfigTestCommand.new("generate")

      middleware.before(command, ["model", "User"])
    end

    it "validates configuration for db command" do
      middleware = AzuCLI::Middleware::Configuration.new
      command = ConfigTestCommand.new("db")

      middleware.before(command, ["migrate"])
    end

    it "validates configuration for serve command" do
      middleware = AzuCLI::Middleware::Configuration.new
      command = ConfigTestCommand.new("serve")

      middleware.before(command, [] of String)
    end

    it "handles unknown commands without validation" do
      middleware = AzuCLI::Middleware::Configuration.new
      command = ConfigTestCommand.new("unknown_command")

      # Should not raise for unknown commands
      middleware.before(command, [] of String)
    end
  end
end
