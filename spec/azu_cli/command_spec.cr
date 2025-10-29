require "../spec_helper"
require "file_utils"

# Test command for testing command functionality
class CommandSpecTestCommand < AzuCLI::Commands::Base
  def initialize
    super("test", "Test command for specs")
  end

  def execute : AzuCLI::Commands::Result
    if has_option?("debug")
      success("Test command executed in debug mode with #{@args.size} arguments")
    else
      success("Test command executed with #{@args.size} arguments")
    end
  end
end

# Test command that requires arguments
class RequireArgsCommand < AzuCLI::Commands::Base
  def initialize
    super("require-test", "Command that requires arguments")
  end

  def execute : AzuCLI::Commands::Result
    unless validate_required_args(2)
      return error("This command requires at least 2 arguments: <name> <type>")
    end
    success("Required args command executed with: #{@args[0]}, #{@args[1]}")
  end
end

describe AzuCLI::Commands::Base do
  before_each do
    # Clean up tmp directory if it exists
    if Dir.exists?("tmp")
      FileUtils.rm_rf("tmp")
    end
  end

  describe "command metadata" do
    it "sets command name correctly" do
      cmd = CommandSpecTestCommand.new
      cmd.name.should eq("test")
    end

    it "sets description correctly" do
      cmd = CommandSpecTestCommand.new
      cmd.description.should eq("Test command for specs")
    end
  end

  describe "option parsing" do
    it "parses long options correctly" do
      cmd = CommandSpecTestCommand.new
      cmd.parse_args(["--debug", "--output", "file.txt"])

      cmd.has_option?("debug").should be_true
      cmd.get_option("output").should eq("file.txt")
    end

    it "parses short options correctly" do
      cmd = CommandSpecTestCommand.new
      cmd.parse_args(["-d", "-o", "file.txt"])

      cmd.has_option?("d").should be_true
      cmd.get_option("o").should eq("file.txt")
    end

    it "parses options with equals correctly" do
      cmd = CommandSpecTestCommand.new
      cmd.parse_args(["--output=file.txt", "--level=debug"])

      cmd.get_option("output").should eq("file.txt")
      cmd.get_option("level").should eq("debug")
    end

    it "handles positional arguments correctly" do
      cmd = CommandSpecTestCommand.new
      cmd.parse_args(["create", "user", "--debug", "admin"])

      cmd.get_args.should eq(["create", "user", "--debug", "admin"])
      cmd.has_option?("debug").should be_true
    end
  end

  describe "option access methods" do
    it "gets option values correctly" do
      cmd = CommandSpecTestCommand.new
      cmd.parse_args(["--output", "file.txt", "--debug", "--level", "info"])

      cmd.get_option("output").should eq("file.txt")
      cmd.get_option("level").should eq("info")
      cmd.get_option("missing", "default").should eq("default")
      cmd.has_option?("debug").should be_true
      cmd.has_option?("missing").should be_false
    end

    it "checks option presence correctly" do
      cmd = CommandSpecTestCommand.new
      cmd.parse_args(["--debug", "--output", "file.txt"])

      cmd.has_option?("debug").should be_true
      cmd.has_option?("output").should be_true
      cmd.has_option?("missing").should be_false
    end
  end

  describe "argument utilities" do
    it "gets arguments" do
      cmd = CommandSpecTestCommand.new
      cmd.parse_args(["arg1", "arg2", "--debug", "arg3"])

      cmd.get_args.should eq(["arg1", "arg2", "--debug", "arg3"])
      cmd.get_arg(0).should eq("arg1")
      cmd.get_arg(1).should eq("arg2")
    end

    it "handles empty arguments" do
      cmd = CommandSpecTestCommand.new
      cmd.parse_args(["--debug"])

      cmd.get_args.should eq(["--debug"])
      cmd.get_arg(0).should eq("--debug")
      cmd.get_arg(1).should be_nil
    end

    it "validates required arguments" do
      cmd = RequireArgsCommand.new

      # Should fail when not enough arguments
      result = cmd.execute
      result.success?.should be_false
      result.error.should contain("requires at least 2 arguments")

      # Should succeed with enough arguments
      cmd.parse_args(["user", "model"])
      result = cmd.execute
      result.success?.should be_true
      result.message.should contain("user, model")
    end
  end

  describe "execute method" do
    it "executes command successfully" do
      cmd = CommandSpecTestCommand.new
      cmd.parse_args(["--debug", "test"])
      result = cmd.execute

      result.success?.should be_true
      result.message.should contain("Test command executed")
      result.message.should contain("debug mode")
      result.message.should contain("1 arguments")
    end

    it "executes without options" do
      cmd = CommandSpecTestCommand.new
      cmd.parse_args(["test", "arg"])
      result = cmd.execute

      result.success?.should be_true
      result.message.should eq("Test command executed with 2 arguments")
    end
  end

  describe "result handling" do
    it "creates success results" do
      cmd = CommandSpecTestCommand.new
      result = cmd.success("Operation completed")

      result.success?.should be_true
      result.message.should eq("Operation completed")
      result.error.should eq("")
    end

    it "creates error results" do
      cmd = CommandSpecTestCommand.new
      result = cmd.error("Operation failed")

      result.success?.should be_false
      result.message.should eq("")
      result.error.should eq("Operation failed")
    end
  end

  describe "help functionality" do
    it "shows help information" do
      cmd = CommandSpecTestCommand.new
      # This would test the show_help method if it's implemented
      # For now, just test that the command has the method
      cmd.responds_to?(:show_help).should be_true
    end
  end
end
