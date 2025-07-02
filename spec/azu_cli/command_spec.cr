require "../spec_helper"

# Test command for testing base functionality
class TestCommand < AzuCLI::Command
  command_name "test"
  description "Test command for specs"
  usage "test [options] <args>"

  def setup_command_options(parser : OptionParser)
    parser.on("-d", "--debug", "Enable debug mode") do
      parsed_options["debug"] = true
    end

    parser.on("-o", "--output FILE", "Output file") do |file|
      parsed_options["output"] = file
    end

    parser.on("--level LEVEL", "Set level") do |level|
      parsed_options["level"] = level
    end

    parser.on("--config FILE", "Configuration file") do |file|
      parsed_options["config"] = file
    end
  end

  def execute_with_options(
    options : Hash(String, String | Bool | Array(String)),
    args : Array(String),
  ) : String | Nil
    if get_option_bool("debug")
      "Test command executed in debug mode with #{args.size} arguments"
    else
      "Test command executed with #{args.size} arguments"
    end
  end
end

# Test command that requires arguments
class RequireArgsCommand < AzuCLI::Command
  command_name "require-test"
  description "Command that requires arguments"
  usage "require-test <name> <type> [options]"

  def execute_with_options(
    options : Hash(String, String | Bool | Array(String)),
    args : Array(String),
  ) : String | Nil
    require_args(2, "This command requires at least 2 arguments: <name> <type>")
    "Required args command executed with: #{args[0]}, #{args[1]}"
  end
end

describe AzuCLI::Command do
  describe "command metadata" do
    it "sets command name correctly" do
      cmd = TestCommand.new
      cmd.command_name.should eq("test")
      TestCommand.command_name.should eq("test")
    end

    it "sets description correctly" do
      cmd = TestCommand.new
      cmd.description.should eq("Test command for specs")
      TestCommand.description.should eq("Test command for specs")
    end

    it "sets usage correctly" do
      cmd = TestCommand.new
      cmd.usage.should eq("test [options] <args>")
      TestCommand.usage.should eq("test [options] <args>")
    end
  end

  describe "OptionParser integration" do
    it "parses long options correctly" do
      cmd = TestCommand.new
      result = cmd.run("", ["--debug", "--output", "file.txt", "--verbose"])

      cmd.get_option_bool("debug").should be_true
      cmd.get_option("output").should eq("file.txt")
      cmd.get_option_bool("verbose").should be_true
      result.should contain("debug mode")
    end

    it "parses short options correctly" do
      cmd = TestCommand.new
      result = cmd.run("", ["-d", "-o", "file.txt"])

      cmd.get_option_bool("debug").should be_true
      cmd.get_option("output").should eq("file.txt")
      result.should contain("debug mode")
    end

    it "parses options with equals correctly" do
      cmd = TestCommand.new
      result = cmd.run("", ["--output=file.txt", "--level=debug", "--config=app.yml"])

      cmd.get_option("output").should eq("file.txt")
      cmd.get_option("level").should eq("debug")
      cmd.get_option("config").should eq("app.yml")
      result.should_not be_nil
    end

    it "handles positional arguments correctly" do
      cmd = TestCommand.new
      result = cmd.run("", ["create", "user", "--debug", "admin"])

      cmd.get_remaining_args.should eq(["create", "user", "admin"])
      cmd.get_option_bool("debug").should be_true
      cmd.get_first_arg.should eq("create")
      cmd.has_remaining_args?.should be_true
      result.should contain("debug mode")
      result.should contain("3 arguments")
    end

    it "handles force option from base command" do
      cmd = TestCommand.new
      result = cmd.run("", ["--force", "test"])

      cmd.get_option_bool("force").should be_true
      cmd.get_remaining_args.should eq(["test"])
    end

    it "handles quiet option from base command" do
      cmd = TestCommand.new
      result = cmd.run("", ["--quiet", "test"])

      cmd.get_option_bool("quiet").should be_true
      cmd.get_remaining_args.should eq(["test"])
    end

    it "handles verbose option from base command" do
      cmd = TestCommand.new
      result = cmd.run("", ["--verbose", "test"])

      cmd.get_option_bool("verbose").should be_true
      cmd.get_remaining_args.should eq(["test"])
    end
  end

  describe "option access methods" do
    it "gets option values correctly" do
      cmd = TestCommand.new
      cmd.run("", ["--output", "file.txt", "--debug", "--level", "info"])

      cmd.get_option("output").should eq("file.txt")
      cmd.get_option("level").should eq("info")
      cmd.get_option("missing", "default").should eq("default")
      cmd.get_option_bool("debug").should be_true
      cmd.get_option_bool("missing").should be_false
    end

    it "checks option presence correctly" do
      cmd = TestCommand.new
      cmd.run("", ["--debug", "--output", "file.txt"])

      cmd.has_option?("debug").should be_true
      cmd.has_option?("output").should be_true
      cmd.has_option?("missing").should be_false
    end

    it "handles array options" do
      cmd = TestCommand.new
      cmd.run("", ["--debug"])

      cmd.get_option_array("debug").should eq(["true"])
      cmd.get_option_array("missing").should eq([] of String)
    end
  end

  describe "argument utilities" do
    it "gets remaining arguments" do
      cmd = TestCommand.new
      cmd.run("", ["arg1", "arg2", "--debug", "arg3"])

      cmd.get_remaining_args.should eq(["arg1", "arg2", "arg3"])
      cmd.has_remaining_args?.should be_true
      cmd.get_first_arg.should eq("arg1")
      cmd.get_first_arg("default").should eq("arg1")
    end

    it "handles empty arguments" do
      cmd = TestCommand.new
      cmd.run("", ["--debug"])

      cmd.get_remaining_args.should eq([] of String)
      cmd.has_remaining_args?.should be_false
      cmd.get_first_arg.should eq("")
      cmd.get_first_arg("default").should eq("default")
    end

    it "validates required arguments" do
      cmd = RequireArgsCommand.new

      # Should raise when not enough arguments
      result = cmd.run("", ["only_one"])
      result.should eq("") # Error handled gracefully

      # Should succeed with enough arguments
      result = cmd.run("", ["user", "model"])
      result.should eq("Required args command executed with: user, model")
    end
  end

  describe "#run method" do
    it "executes command successfully" do
      cmd = TestCommand.new
      result = cmd.run("", ["--debug", "test"])

      result.should contain("Test command executed")
      result.should contain("debug mode")
      result.should contain("1 arguments")
    end

    it "handles help requests" do
      cmd = TestCommand.new
      result = cmd.run("", ["--help"])

      result.should eq("")
      cmd.help_requested.should be_true
    end

    it "handles version requests" do
      cmd = TestCommand.new
      result = cmd.run("", ["--version"])

      result.should eq("")
      cmd.version_requested.should be_true
    end

    it "handles invalid options gracefully" do
      cmd = TestCommand.new
      result = cmd.run("", ["--invalid-option"])

      result.should eq("") # Should handle error gracefully
    end

    it "executes without options" do
      cmd = TestCommand.new
      result = cmd.run("", ["test", "arg"])

      result.should eq("Test command executed with 2 arguments")
      cmd.get_remaining_args.should eq(["test", "arg"])
    end
  end

  describe "utility methods" do
    it "provides access to config" do
      cmd = TestCommand.new
      config = cmd.config
      config.should be_a(AzuCLI::Config)
    end

    it "provides access to logger" do
      cmd = TestCommand.new
      logger = cmd.log
      logger.should eq(AzuCLI::Logger)
    end
  end

  describe "error handling" do
    it "handles argument errors gracefully" do
      cmd = RequireArgsCommand.new
      result = cmd.run("", [] of String) # No arguments provided

      result.should eq("") # Should return empty string on error
    end

    it "handles unknown options gracefully" do
      cmd = TestCommand.new
      result = cmd.run("", ["--unknown", "value"])

      result.should eq("") # Should handle unknown options gracefully
    end
  end

  describe "validation" do
    it "can be overridden in subclasses" do
      cmd = TestCommand.new
      # This should not raise as base validation is minimal
      cmd.run("", ["--debug"])
      cmd.get_option_bool("debug").should be_true
    end
  end
end
