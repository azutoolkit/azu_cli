require "../../spec_helper"

describe AzuCLI::Commands::Help do
  it "lists every registered command, and only those" do
    # The help text is plain `puts` lines, so check the source of the overview.
    help = File.read("src/azu_cli/commands/help.cr")
    names = AzuCLI::CLI.new.command_names
    aliases = %w(g server s t help)

    (names - aliases).each { |name| help.should contain(name) }
    names.should_not contain("plugin")
    help.should_not contain("plugin <operation>")
  end

  describe "#execute" do
    it "displays general help when no command specified" do
      command = AzuCLI::Commands::Help.new
      command.parse_args([] of String)

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Help information displayed")
    end

    it "displays help for new command" do
      command = AzuCLI::Commands::Help.new
      command.parse_args(["new"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Help information displayed")
    end

    it "displays help for generate command" do
      command = AzuCLI::Commands::Help.new
      command.parse_args(["generate"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Help information displayed")
    end

    it "displays help for g alias" do
      command = AzuCLI::Commands::Help.new
      command.parse_args(["g"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Help information displayed")
    end

    it "displays help for db command" do
      command = AzuCLI::Commands::Help.new
      command.parse_args(["db"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Help information displayed")
    end

    it "displays help for serve command" do
      command = AzuCLI::Commands::Help.new
      command.parse_args(["serve"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Help information displayed")
    end

    it "displays help for test command" do
      command = AzuCLI::Commands::Help.new
      command.parse_args(["test"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Help information displayed")
    end

    it "displays help for jobs command" do
      command = AzuCLI::Commands::Help.new
      command.parse_args(["jobs"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Help information displayed")
    end

    it "displays help for session command" do
      command = AzuCLI::Commands::Help.new
      command.parse_args(["session"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Help information displayed")
    end

    it "handles unknown command gracefully" do
      command = AzuCLI::Commands::Help.new
      command.parse_args(["unknown_command"])

      result = command.execute

      result.success?.should be_true
    end
  end

  describe "#show_help" do
    it "displays command name and description" do
      command = AzuCLI::Commands::Help.new

      # Just ensure it doesn't crash
      command.show_help
    end
  end
end
