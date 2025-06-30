require "../spec_helper"

# Test command for testing base functionality
class TestCommand < AzuCLI::Command
  command_name "test"
  description "Test command for specs"
  usage "test [options]"

  def execute(args : Hash(String, String | Array(String))) : String | Nil
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

  describe "#parse_args" do
    it "parses long options correctly" do
      cmd = TestCommand.new
      args = ["--debug", "--output", "file.txt", "--verbose"]
      parsed = cmd.parse_args(args)

      parsed["debug"].should eq("true")
      parsed["output"].should eq("file.txt")
      parsed["verbose"].should eq("true")
    end

    it "parses short options correctly" do
      cmd = TestCommand.new
      args = ["-d", "-o", "file.txt", "-v"]
      parsed = cmd.parse_args(args)

      parsed["d"].should eq("true")
      parsed["o"].should eq("file.txt")
      parsed["v"].should eq("true")
    end

    it "parses options with equals correctly" do
      cmd = TestCommand.new
      args = ["--output=file.txt", "--level=debug"]
      parsed = cmd.parse_args(args)

      parsed["output"].should eq("file.txt")
      parsed["level"].should eq("debug")
    end

    it "parses positional arguments correctly" do
      cmd = TestCommand.new
      args = ["create", "user", "--debug", "admin"]
      parsed = cmd.parse_args(args)

      positional = cmd.get_positional_args(parsed)
      positional.should eq(["create", "user", "admin"])
      parsed["debug"].should eq("true")
    end
  end

  describe "#get_flag" do
    it "gets flag values correctly" do
      cmd = TestCommand.new
      args = {"output" => "file.txt", "debug" => "true"}

      cmd.get_flag(args, "output").should eq("file.txt")
      cmd.get_flag(args, "debug").should eq("true")
      cmd.get_flag(args, "missing", "default").should eq("default")
    end

    it "handles array values correctly" do
      cmd = TestCommand.new
      args = {"files" => ["file1.txt", "file2.txt"]}

      cmd.get_flag(args, "files").should eq("file1.txt")
    end
  end

  describe "#has_flag?" do
    it "checks flag presence correctly" do
      cmd = TestCommand.new
      args = {"debug" => "true", "output" => "file.txt"}

      cmd.has_flag?(args, "debug").should be_true
      cmd.has_flag?(args, "output").should be_true
      cmd.has_flag?(args, "missing").should be_false
    end
  end

  describe "#run" do
    it "executes command successfully" do
      cmd = TestCommand.new
      result = cmd.run("", ["--debug"])

      result.should eq("Test command executed")
    end

    it "handles validation errors" do
      cmd = TestCommand.new
      # Should not raise error but should handle gracefully
      result = cmd.run("", ["--help"])
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
end
