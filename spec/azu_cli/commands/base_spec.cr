require "../../spec_helper"
require "../../support/test_helpers"

# Create a concrete implementation of Base for testing
class TestCommand < AzuCLI::Commands::Base
  def initialize
    super("test", "Test command for testing base functionality")
  end

  def execute : AzuCLI::Commands::Result
    success("Test command executed successfully")
  end
end

describe AzuCLI::Commands::Base do
  describe "#initialize" do
    it "sets up command properties" do
      command = TestCommand.new

      command.name.should eq("test")
      command.description.should eq("Test command for testing base functionality")
      command.options.should be_empty
      command.args.should be_empty
      command.all_args.should be_empty
    end
  end

  describe "#parse_args" do
    it "parses simple arguments" do
      command = TestCommand.new
      command.parse_args(["arg1", "arg2", "arg3"])

      command.args.should eq(["arg1", "arg2", "arg3"])
      command.all_args.should eq(["arg1", "arg2", "arg3"])
    end

    it "parses long options with values" do
      command = TestCommand.new
      command.parse_args(["--name", "value", "--other", "other_value"])

      command.options["name"].should eq("value")
      command.options["other"].should eq("other_value")
      command.args.should be_empty
    end

    it "parses long options with equals format" do
      command = TestCommand.new
      command.parse_args(["--name=value", "--other=other_value"])

      command.options["name"].should eq("value")
      command.options["other"].should eq("other_value")
      command.args.should be_empty
    end

    it "parses short options with values" do
      command = TestCommand.new
      command.parse_args(["-n", "value", "-o", "other_value"])

      command.options["n"].should eq("value")
      command.options["o"].should eq("other_value")
      command.args.should be_empty
    end

    it "parses boolean flags" do
      command = TestCommand.new
      command.parse_args(["--debug", "--verbose", "--help"])

      command.options["debug"].should eq("true")
      command.options["verbose"].should eq("true")
      command.options["help"].should eq("true")
      command.args.should be_empty
    end

    it "parses short boolean flags" do
      command = TestCommand.new
      command.parse_args(["-d", "-v", "-h"])

      command.options["d"].should eq("true")
      command.options["v"].should eq("true")
      command.options["h"].should eq("true")
      command.args.should be_empty
    end

    it "parses mixed arguments and options" do
      command = TestCommand.new
      command.parse_args(["arg1", "--name", "value", "arg2", "--debug", "arg3"])

      command.args.should eq(["arg1", "arg2", "arg3"])
      command.options["name"].should eq("value")
      command.options["debug"].should eq("true")
    end

    it "handles options without values" do
      command = TestCommand.new
      command.parse_args(["--name"])

      command.options["name"].should eq("true")
      command.args.should be_empty
    end

    it "handles short options without values" do
      command = TestCommand.new
      command.parse_args(["-n"])

      command.options["n"].should eq("true")
      command.args.should be_empty
    end

    it "resets state on multiple calls" do
      command = TestCommand.new
      command.parse_args(["--name", "value"])
      command.parse_args(["--other", "other_value"])

      command.options.has_key?("name").should be_false
      command.options["other"].should eq("other_value")
    end
  end

  describe "#get_option" do
    it "returns option value" do
      command = TestCommand.new
      command.parse_args(["--name", "value"])

      command.get_option("name").should eq("value")
    end

    it "returns default when option not found" do
      command = TestCommand.new
      command.parse_args([] of String)

      command.get_option("name", "default").should eq("default")
    end

    it "returns empty string as default" do
      command = TestCommand.new
      command.parse_args([] of String)

      command.get_option("name").should eq("")
    end
  end

  describe "#has_option?" do
    it "returns true when option exists" do
      command = TestCommand.new
      command.parse_args(["--name", "value"])

      command.has_option?("name").should be_true
    end

    it "returns false when option does not exist" do
      command = TestCommand.new
      command.parse_args([] of String)

      command.has_option?("name").should be_false
    end
  end

  describe "#get_arg" do
    it "returns argument at index" do
      command = TestCommand.new
      command.parse_args(["arg1", "arg2", "arg3"])

      command.get_arg(0).should eq("arg1")
      command.get_arg(1).should eq("arg2")
      command.get_arg(2).should eq("arg3")
    end

    it "returns nil for out of bounds index" do
      command = TestCommand.new
      command.parse_args(["arg1"])

      command.get_arg(1).should be_nil
    end
  end

  describe "#get_args" do
    it "returns all arguments including flags" do
      command = TestCommand.new
      command.parse_args(["arg1", "--name", "value", "arg2"])

      command.get_args.should eq(["arg1", "--name", "value", "arg2"])
    end
  end

  describe "#success" do
    it "creates success result" do
      command = TestCommand.new
      result = command.success("Operation completed")

      result.success?.should be_true
      result.message.should eq("Operation completed")
      result.error.should eq("")
    end

    it "creates success result without message" do
      command = TestCommand.new
      result = command.success

      result.success?.should be_true
      result.message.should eq("")
      result.error.should eq("")
    end
  end

  describe "#error" do
    it "creates error result" do
      command = TestCommand.new
      result = command.error("Something went wrong")

      result.success?.should be_false
      result.message.should eq("")
      result.error.should eq("Something went wrong")
    end
  end

  describe "#validate_required_args" do
    it "returns true when enough arguments provided" do
      command = TestCommand.new
      command.parse_args(["arg1", "arg2"])

      command.validate_required_args(2).should be_true
    end

    it "returns false when not enough arguments provided" do
      command = TestCommand.new
      command.parse_args(["arg1"])

      TestHelpers::TestSetup.with_captured_output do |capture|
        command.validate_required_args(2).should be_false
        capture.stderr.should contain("Missing required arguments")
      end
    end

    it "returns true when exact number of arguments provided" do
      command = TestCommand.new
      command.parse_args(["arg1", "arg2"])

      command.validate_required_args(2).should be_true
    end
  end

  describe "#validate_required_options" do
    it "returns true when all required options provided" do
      command = TestCommand.new
      command.parse_args(["--name", "value", "--other", "other_value"])

      command.validate_required_options(["name", "other"]).should be_true
    end

    it "returns false when some required options missing" do
      command = TestCommand.new
      command.parse_args(["--name", "value"])

      TestHelpers::TestSetup.with_captured_output do |capture|
        command.validate_required_options(["name", "other"]).should be_false
        capture.stderr.should contain("Missing required options: other")
      end
    end

    it "returns true when no required options specified" do
      command = TestCommand.new
      command.parse_args([] of String)

      command.validate_required_options([] of String).should be_true
    end
  end

  describe "#show_help" do
    it "displays command help" do
      command = TestCommand.new

      TestHelpers::TestSetup.with_captured_output do |capture|
        command.show_help
        capture.stdout.should contain("Usage: azu test")
        capture.stdout.should contain("Description: Test command for testing base functionality")
        capture.stdout.should contain("Options:")
        capture.stdout.should contain("--help")
        capture.stdout.should contain("--version")
      end
    end
  end

  describe "#show_examples" do
    it "displays default examples" do
      command = TestCommand.new

      TestHelpers::TestSetup.with_captured_output do |capture|
        command.show_examples
        capture.stdout.should contain("azu test --help")
      end
    end
  end

  describe "boolean flag detection" do
    it "recognizes common boolean flags" do
      command = TestCommand.new

      # Test boolean flag parsing by checking if they're treated as boolean
      command.parse_args(["--debug"])
      command.has_option?("debug").should be_true
      command.get_option("debug").should eq("true")

      command.parse_args(["-d"])
      command.has_option?("d").should be_true
      command.get_option("d").should eq("true")

      command.parse_args(["--help"])
      command.has_option?("help").should be_true
      command.get_option("help").should eq("true")
    end

    it "does not recognize non-boolean flags as boolean" do
      command = TestCommand.new

      # Test that non-boolean flags require values
      command.parse_args(["--name", "value"])
      command.has_option?("name").should be_true
      command.get_option("name").should eq("value")

      command.parse_args(["--config", "path"])
      command.has_option?("config").should be_true
      command.get_option("config").should eq("path")
    end
  end

  describe "edge cases" do
    it "handles empty argument list" do
      command = TestCommand.new
      command.parse_args([] of String)

      command.args.should be_empty
      command.options.should be_empty
      command.all_args.should be_empty
    end

    it "handles single argument" do
      command = TestCommand.new
      command.parse_args(["single"])

      command.args.should eq(["single"])
      command.get_arg(0).should eq("single")
    end

    it "handles single option" do
      command = TestCommand.new
      command.parse_args(["--name", "value"])

      command.options["name"].should eq("value")
      command.args.should be_empty
    end

    it "handles options at end of argument list" do
      command = TestCommand.new
      command.parse_args(["arg1", "arg2", "--name", "value"])

      command.args.should eq(["arg1", "arg2"])
      command.options["name"].should eq("value")
    end

    it "handles options at beginning of argument list" do
      command = TestCommand.new
      command.parse_args(["--name", "value", "arg1", "arg2"])

      command.args.should eq(["arg1", "arg2"])
      command.options["name"].should eq("value")
    end
  end
end
