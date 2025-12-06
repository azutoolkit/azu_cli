require "../../spec_helper"

# Create test commands for plugin testing
class DatabasePluginTestCommand < AzuCLI::Commands::Base
  def initialize(name : String = "db")
    super(name, "Test command for database plugin")
  end

  def execute : AzuCLI::Commands::Result
    success("Database test executed")
  end
end

describe AzuCLI::Plugins::DatabasePlugin do
  describe "#initialize" do
    it "sets correct plugin properties" do
      plugin = AzuCLI::Plugins::DatabasePlugin.new

      plugin.name.should eq("database")
      plugin.description.should eq("Database operations plugin for Azu CLI")
      plugin.version.should eq("1.0.0")
    end
  end

  describe "#before_command" do
    it "validates db command" do
      plugin = AzuCLI::Plugins::DatabasePlugin.new
      command = DatabasePluginTestCommand.new("db")

      # Should not raise
      plugin.before_command(command, ["migrate"])
    end

    it "ignores non-db commands" do
      plugin = AzuCLI::Plugins::DatabasePlugin.new
      command = DatabasePluginTestCommand.new("generate")

      plugin.before_command(command, ["model", "User"])
    end
  end

  describe "#after_command" do
    it "logs success result for db command" do
      plugin = AzuCLI::Plugins::DatabasePlugin.new
      command = DatabasePluginTestCommand.new("db")
      result = command.success("Migration completed")

      plugin.after_command(command, result)
    end

    it "logs error result for db command" do
      plugin = AzuCLI::Plugins::DatabasePlugin.new
      command = DatabasePluginTestCommand.new("db")
      result = command.error("Migration failed")

      plugin.after_command(command, result)
    end

    it "ignores non-db commands" do
      plugin = AzuCLI::Plugins::DatabasePlugin.new
      command = DatabasePluginTestCommand.new("generate")
      result = command.success("Generated successfully")

      plugin.after_command(command, result)
    end
  end

  describe "#on_error" do
    it "logs error for db command" do
      plugin = AzuCLI::Plugins::DatabasePlugin.new
      command = DatabasePluginTestCommand.new("db")
      exception = Exception.new("Database error")

      plugin.on_error(command, exception)
    end

    it "provides connection error suggestions" do
      plugin = AzuCLI::Plugins::DatabasePlugin.new
      command = DatabasePluginTestCommand.new("db")
      exception = Exception.new("connection refused")

      plugin.on_error(command, exception)
    end

    it "provides SQL error suggestions" do
      plugin = AzuCLI::Plugins::DatabasePlugin.new
      command = DatabasePluginTestCommand.new("db")
      exception = Exception.new("SQL syntax error in query")

      plugin.on_error(command, exception)
    end

    it "provides permission error suggestions" do
      plugin = AzuCLI::Plugins::DatabasePlugin.new
      command = DatabasePluginTestCommand.new("db")
      exception = Exception.new("permission denied for table")

      plugin.on_error(command, exception)
    end

    it "ignores non-db commands" do
      plugin = AzuCLI::Plugins::DatabasePlugin.new
      command = DatabasePluginTestCommand.new("generate")
      exception = Exception.new("Generation error")

      plugin.on_error(command, exception)
    end
  end
end
