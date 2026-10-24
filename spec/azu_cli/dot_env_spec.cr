require "../spec_helper"
require "file_utils"

private def with_env(vars : Hash(String, String?), &)
  saved = vars.keys.to_h { |name| {name, ENV[name]?} }
  vars.each { |name, value| value ? (ENV[name] = value) : ENV.delete(name) }
  begin
    yield
  ensure
    saved.each { |name, value| value ? (ENV[name] = value) : ENV.delete(name) }
  end
end

private def with_dir(&)
  dir = File.tempname("azu-cli-dotenv")
  Dir.mkdir_p(dir)
  begin
    yield dir
  ensure
    FileUtils.rm_rf(dir)
  end
end

# The grammar is the one of Azu::Env.parse in the azu shard (spec/azu/env_spec.cr there).
describe AzuCLI::DotEnv do
  describe ".parse" do
    it "reads pairs, comments, export, quotes and multi-line values" do
      text = "# c\nA=1\n  B = two  \nexport C=3\nD=v # note\nE='a $B \\n'\nF=\"x\\ny\\\"\"\nG=\"one\ntwo\"\nH=\nI=a#b\n"
      AzuCLI::DotEnv.parse(text).should eq({
        "A" => "1", "B" => "two", "C" => "3", "D" => "v", "E" => "a $B \\n", "F" => "x\ny\"",
        "G" => "one\ntwo", "H" => "", "I" => "a#b",
      })
    end

    it "does no interpolation or shell evaluation" do
      AzuCLI::DotEnv.parse("A=$(echo hi)\nB=${A}\nC=`id`\n").should eq({"A" => "$(echo hi)", "B" => "${A}", "C" => "`id`"})
    end

    it "handles CRLF and a BOM" do
      AzuCLI::DotEnv.parse("\uFEFFA=1\r\nB=\"x\"\r\n").should eq({"A" => "1", "B" => "x"})
    end

    it "raises a ParseError naming file and line, never the text" do
      error = expect_raises(AzuCLI::DotEnv::ParseError) { AzuCLI::DotEnv.parse("A=1\nnot a pair topsecret\n", ".env") }
      error.message.to_s.should contain(".env:2")
      error.message.to_s.should_not contain("topsecret")
      expect_raises(AzuCLI::DotEnv::ParseError) { AzuCLI::DotEnv.parse("A=\"never closed\nB=2") }
      expect_raises(AzuCLI::DotEnv::ParseError) { AzuCLI::DotEnv.parse(%(A="x" y)) }
      expect_raises(AzuCLI::DotEnv::ParseError) { AzuCLI::DotEnv.parse("1A=x") }
    end
  end

  describe ".load" do
    it "never overrides a variable of the process, even an empty one" do
      with_dir do |dir|
        path = File.join(dir, ".env")
        File.write(path, "AZU_CLI_SPEC_A=file\nAZU_CLI_SPEC_B=file\nAZU_CLI_SPEC_C=file\n")
        with_env({"AZU_CLI_SPEC_A" => "process", "AZU_CLI_SPEC_B" => "", "AZU_CLI_SPEC_C" => nil}) do
          AzuCLI::DotEnv.load(path).should eq ["AZU_CLI_SPEC_C"]
          ENV["AZU_CLI_SPEC_A"].should eq "process"
          ENV["AZU_CLI_SPEC_B"].should eq ""
          ENV["AZU_CLI_SPEC_C"].should eq "file"
        end
      end
    end

    it "ignores a missing file" do
      with_dir { |dir| AzuCLI::DotEnv.load(File.join(dir, ".env")).should be_empty }
    end
  end

  describe ".load_all" do
    it "applies process env > .env.local > .env.<CRYSTAL_ENV> > .env" do
      with_dir do |dir|
        File.write(File.join(dir, ".env"), "AZU_CLI_SPEC_P=base\nAZU_CLI_SPEC_Q=base\nAZU_CLI_SPEC_R=base\nAZU_CLI_SPEC_S=base\n")
        File.write(File.join(dir, ".env.staging"), "AZU_CLI_SPEC_P=staging\nAZU_CLI_SPEC_Q=staging\nAZU_CLI_SPEC_R=staging\n")
        File.write(File.join(dir, ".env.local"), "AZU_CLI_SPEC_P=local\nAZU_CLI_SPEC_Q=local\n")
        File.write(File.join(dir, ".env.production"), "AZU_CLI_SPEC_S=production-file\n")
        names = {"AZU_CLI_SPEC_P" => nil, "AZU_CLI_SPEC_Q" => "process", "AZU_CLI_SPEC_R" => nil, "AZU_CLI_SPEC_S" => nil, "CRYSTAL_ENV" => "staging"}
        with_env(names) do
          AzuCLI::DotEnv.load_all(dir)
          ENV["AZU_CLI_SPEC_P"].should eq "local"
          ENV["AZU_CLI_SPEC_Q"].should eq "process"
          ENV["AZU_CLI_SPEC_R"].should eq "staging"
          ENV["AZU_CLI_SPEC_S"].should eq "base"
        end
      end
    end

    it "defaults to .env.development and refuses a CRYSTAL_ENV that escapes the directory" do
      with_dir do |dir|
        File.write(File.join(dir, ".env.development"), "AZU_CLI_SPEC_P=dev\n")
        with_env({"CRYSTAL_ENV" => nil, "AZU_CLI_SPEC_P" => nil}) do
          AzuCLI::DotEnv.load_all(dir)
          ENV["AZU_CLI_SPEC_P"].should eq "dev"
        end
        with_env({"CRYSTAL_ENV" => "../x", "AZU_CLI_SPEC_P" => nil}) do
          AzuCLI::DotEnv.load_all(dir).should be_empty
        end
      end
    end
  end

  describe "AzuCLI.load_project_env" do
    it "loads the project's files for a command that needs them" do
      with_dir do |dir|
        File.write(File.join(dir, ".env"), "AZU_CLI_SPEC_P=from-project\n")
        with_env({"AZU_CLI_SPEC_P" => nil, "CRYSTAL_ENV" => "test"}) do
          AzuCLI.load_project_env(["db:migrate"], dir).should eq ["AZU_CLI_SPEC_P"]
          ENV["AZU_CLI_SPEC_P"].should eq "from-project"
        end
      end
    end

    it "leaves new, init, help, version and completion alone, and does nothing without a command" do
      with_dir do |dir|
        File.write(File.join(dir, ".env"), "AZU_CLI_SPEC_P=from-project\n")
        with_env({"AZU_CLI_SPEC_P" => nil}) do
          %w[new init help version completion --help].each { |command| AzuCLI.load_project_env([command], dir).should be_empty }
          AzuCLI.load_project_env([] of String, dir).should be_empty
          ENV["AZU_CLI_SPEC_P"]?.should be_nil
        end
      end
    end
  end
end
