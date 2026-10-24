require "../spec_helper"
require "file_utils"
require "json"

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

  describe "the shared parser corpus" do
    # spec/fixtures/dotenv_corpus.json is identical in azu and azu_cli (this parser is a copy of Azu::Env's):
    # change one, change both.
    corpus = JSON.parse(File.read(File.join(__DIR__, "../fixtures/dotenv_corpus.json"))).as_a

    corpus.each do |entry|
      it entry["name"].as_s do
        input = entry["input"].as_s
        if line = entry["error_line"]?
          error = expect_raises(AzuCLI::DotEnv::ParseError) { AzuCLI::DotEnv.parse(input) }
          error.line.should eq line.as_i
        else
          AzuCLI::DotEnv.parse(input).should eq entry["expect"].as_h.transform_values(&.as_s)
        end
      end
    end
  end

  describe "untrusted projects" do
    it "knows the names that change how processes start, case-insensitively" do
      %w[LD_PRELOAD ld_library_path DYLD_INSERT_LIBRARIES PATH path SHELL IFS BASH_ENV ENV SHARDS_CACHE_PATH SHARDS_INSTALL_PATH
        CRYSTAL_PATH CRYSTAL_OPTS CRYSTAL_LIBRARY_PATH GIT_SSH_COMMAND GIT_DIR DOCKER_HOST HOME].each do |name|
        AzuCLI::DotEnv.unsafe_name?(name).should be_true
      end
      %w[PORT DATABASE_URL CSRF_SECRET PATHS MY_PATH CRYSTAL_ENV GITHUB_TOKEN HOMEPAGE].each { |name| AzuCLI::DotEnv.unsafe_name?(name).should be_false }
    end

    it "does not let a project's file set them, and warns without printing the value" do
      with_dir do |dir|
        path = File.join(dir, ".env")
        File.write(path, "AZU_CLI_SPEC_OK=1\nLD_PRELOAD=/tmp/evil.so\nCRYSTAL_OPTS=evil-value\nPATH=/tmp/evil\n")
        original_path = ENV["PATH"]
        with_env({"AZU_CLI_SPEC_OK" => nil, "LD_PRELOAD" => nil, "CRYSTAL_OPTS" => nil}) do
          AzuCLI::DotEnv.load(path).should eq ["AZU_CLI_SPEC_OK"]
          ENV["LD_PRELOAD"]?.should be_nil
          ENV["CRYSTAL_OPTS"]?.should be_nil
          ENV["PATH"].should eq original_path
        end
      end
    end

    it "refuses a file larger than 1 MB" do
      with_dir do |dir|
        path = File.join(dir, ".env")
        File.write(path, "A=" + "x" * 1_048_577)
        expect_raises(AzuCLI::DotEnv::ParseError, /larger than 1 MB/) { AzuCLI::DotEnv.load(path) }
      end
    end
  end

  describe "a blank CRYSTAL_ENV" do
    it "counts as unset, when choosing the file and when applying" do
      with_dir do |dir|
        File.write(File.join(dir, ".env"), "CRYSTAL_ENV=staging\nAZU_CLI_SPEC_P=base\n")
        File.write(File.join(dir, ".env.staging"), "AZU_CLI_SPEC_P=staging\n")
        with_env({"CRYSTAL_ENV" => "", "AZU_CLI_SPEC_P" => nil}) do
          AzuCLI::DotEnv.load_all(dir)
          ENV["CRYSTAL_ENV"].should eq "staging"
          ENV["AZU_CLI_SPEC_P"].should eq "staging"
        end
      end
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

    it "reads the environment from the command's --env flag, so the child gets that environment's database" do
      AzuCLI.command_environment(["serve", "--env", "production"]).should eq "production"
      AzuCLI.command_environment(["db:migrate", "-e", "test"]).should eq "test"
      AzuCLI.command_environment(["db:migrate", "--env=staging"]).should eq "staging"
      AzuCLI.command_environment(["serve"]).should be_nil
      AzuCLI.command_environment(["test"]).should eq "test"
      AzuCLI.command_environment(["t", "--env", "production"]).should eq "test"

      with_dir do |dir|
        File.write(File.join(dir, ".env.development"), "AZU_CLI_SPEC_DB=dev\n")
        File.write(File.join(dir, ".env.test"), "AZU_CLI_SPEC_DB=test\n")
        File.write(File.join(dir, ".env.production"), "AZU_CLI_SPEC_DB=prod\n")
        {
          {["serve"], "dev"}, {["serve", "--env", "production"], "prod"}, {["db:migrate", "-e", "test"], "test"}, {["test"], "test"},
        }.each do |args, expected|
          with_env({"AZU_CLI_SPEC_DB" => nil, "CRYSTAL_ENV" => nil}) do
            AzuCLI.load_project_env(args, dir)
            ENV["AZU_CLI_SPEC_DB"].should eq expected
          end
        end
      end
    end

    it "lets the test command override a CRYSTAL_ENV of the shell" do
      with_dir do |dir|
        File.write(File.join(dir, ".env.development"), "AZU_CLI_SPEC_DB=dev\n")
        File.write(File.join(dir, ".env.test"), "AZU_CLI_SPEC_DB=test\n")
        with_env({"AZU_CLI_SPEC_DB" => nil, "CRYSTAL_ENV" => "development"}) do
          AzuCLI.load_project_env(["test"], dir)
          ENV["AZU_CLI_SPEC_DB"].should eq "test"
          ENV["CRYSTAL_ENV"].should eq "test"
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
