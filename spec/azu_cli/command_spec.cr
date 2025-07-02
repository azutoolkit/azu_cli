require "../spec_helper"

# Test command for testing base functionality
class TestCommand < AzuCLI::Command
  command_name "test"
  description "Test command for specs"
  usage "test [options]"

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
  end

  def execute_with_options(
    options : Hash(String, String | Bool | Array(String)),
    args : Array(String),
  ) : String | Nil
    "Test command executed"
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
      cmd.usage.should eq("test [options]")
      TestCommand.usage.should eq("test [options]")
    end
  end

  describe "OptionParser integration" do
    it "parses long options correctly" do
      cmd = TestCommand.new
      result = cmd.run("", ["--debug", "--output", "file.txt", "--verbose"])

      cmd.get_option_bool("debug").should be_true
      cmd.get_option("output").should eq("file.txt")
      cmd.get_option_bool("verbose").should be_true
    end

    it "parses short options correctly" do
      cmd = TestCommand.new
      result = cmd.run("", ["-d", "-o", "file.txt"])

      cmd.get_option_bool("debug").should be_true
      cmd.get_option("output").should eq("file.txt")
    end

    it "parses options with equals correctly" do
      cmd = TestCommand.new
      result = cmd.run("", ["--output=file.txt", "--level=debug"])

      cmd.get_option("output").should eq("file.txt")
      cmd.get_option("level").should eq("debug")
    end

    it "handles positional arguments correctly" do
      cmd = TestCommand.new
      result = cmd.run("", ["create", "user", "--debug", "admin"])

      cmd.get_remaining_args.should eq(["create", "user", "admin"])
      cmd.get_option_bool("debug").should be_true
      cmd.get_first_arg.should eq("create")
      cmd.has_remaining_args?.should be_true
    end

    it "handles force option" do
      cmd = TestCommand.new
      result = cmd.run("", ["--force"])

      cmd.get_option_bool("force").should be_true
    end

    it "handles quiet option" do
      cmd = TestCommand.new
      result = cmd.run("", ["--quiet"])

      cmd.get_option_bool("quiet").should be_true
    end
  end

  describe "option access methods" do
    it "gets option values correctly" do
      cmd = TestCommand.new
      cmd.run("", ["--output", "file.txt", "--debug"])

      cmd.get_option("output").should eq("file.txt")
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

    it "handles argument requirements" do
      cmd = TestCommand.new
      cmd.run("", ["arg1", "arg2"])

      expect_raises(AzuCLI::Command::ArgumentError) do
        cmd.require_args(3, "Need at least 3 arguments")
      end

      # Should not raise
      cmd.require_args(2)
    end
  end

  describe "#run" do
    it "executes command successfully" do
      cmd = TestCommand.new
      result = cmd.run("", ["--debug"])

      result.should eq("Test command executed")
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
      # Should not raise error but should handle gracefully
      result = cmd.run("", ["--invalid-option"])
      result.should eq("")
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
  end
end
