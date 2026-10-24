require "../spec_helper"
require "file_utils"
require "json"
require "digest/sha256"

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
    path = File.join(__DIR__, "../fixtures/dotenv_corpus.json")
    corpus = JSON.parse(File.read(path)).as_a

    it "is the corpus azu pins (same SHA256 in azu's spec/azu/env_spec.cr)" do
      corpus.size.should be > 0
      Digest::SHA256.hexdigest(File.read(path)).should eq "67bad3660aca88d0600542f9f9587b3d5545d963872c290cf054470ef6594a2e"
    end

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
    it "knows the names and families that change how processes start, case-insensitively" do
      %w[LD_PRELOAD ld_library_path DYLD_INSERT_LIBRARIES PATH path SHELL IFS BASH_ENV ENV HOME TMPDIR SHELLOPTS PS4 PROMPT_COMMAND CDPATH GLOBIGNORE
        SHARDS_CACHE_PATH SHARDS_INSTALL_PATH GIT_SSH_COMMAND GIT_DIR CRYSTAL_PATH CRYSTAL_OPTS CRYSTAL_LIBRARY_PATH CRYSTAL_CACHE_DIR CRYSTAL_WORKERS
        DOCKER_HOST DOCKER_CONFIG DOCKER_CONTEXT COMPOSE_FILE COMPOSE_PROJECT_NAME SSH_ASKPASS SSH_AUTH_SOCK
        CC cc CXX CPP CFLAGS CXXFLAGS LDFLAGS CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH PKG_CONFIG PKG_CONFIG_PATH PKG_CONFIG_LIBDIR
        GLIBC_TUNABLES GCONV_PATH LOCPATH NLSPATH SSL_CERT_FILE SSL_CERT_DIR HTTP_PROXY https_proxy ALL_PROXY no_proxy
        EDITOR VISUAL PAGER BROWSER NODE_OPTIONS PYTHONPATH PYTHONSTARTUP PERL5LIB PERL5OPT RUBYOPT RUBYLIB XDG_CONFIG_HOME XDG_DATA_DIRS].each do |name|
        AzuCLI::DotEnv.unsafe_name?(name).should be_true
      end
      %w[PORT DATABASE_URL CSRF_SECRET PATHS MY_PATH CRYSTAL_ENV CRYSTAL_LOG_SOURCES GITHUB_TOKEN HOMEPAGE TERM CCACHE_X LOG_LEVEL LANGUAGE_X TIMEZONE MY_TZ GOFLAGS_X].each do |name|
        AzuCLI::DotEnv.unsafe_name?(name).should be_false
      end
    end

    it "knows the toolchain, TLS, resolver, language-runtime, locale and path-redirecting families" do
      %w[CPPFLAGS cppflags FFLAGS RUSTFLAGS LDLIBS LIBS AR AS LD COMPILER_PATH GCC_EXEC_PREFIX OBJC_INCLUDE_PATH SDKROOT DEVELOPER_DIR
        OPENSSL_CONF OPENSSL_MODULES CURL_CA_BUNDLE REQUESTS_CA_BUNDLE NODE_EXTRA_CA_CERTS FTP_PROXY CURL_HOME WGETRC HOSTALIASES LOCALDOMAIN RES_OPTIONS
        PERLLIB PERLIO LUA_PATH LUA_CPATH JAVA_TOOL_OPTIONS _JAVA_OPTIONS CLASSPATH GEM_HOME GEM_PATH BUNDLE_GEMFILE bundle_path
        NPM_CONFIG_REGISTRY npm_config_registry HOMEBREW_PREFIX homebrew_no_auto_update GOPROXY GOFLAGS CARGO_HOME CARGO_BUILD_RUSTC RUSTC_WRAPPER MAKEFLAGS
        TERMINFO TERMINFO_DIRS TERMCAP MANPATH LANG LANGUAGE LC_ALL lc_messages LOCALE_ARCHIVE TZ TZDIR MALLOC_CHECK_ MALLOC_PERTURB_ ARGV0 _
        USER LOGNAME PWD OLDPWD USERPROFILE AZU_OUTPUT_PATH azu_templates_path].each do |name|
        AzuCLI::DotEnv.unsafe_name?(name).should be_true
      end
    end

    it "skips a denylisted name even when .env.example lists it" do
      with_dir do |dir|
        File.write(File.join(dir, ".env"), "CPPFLAGS=-include./evil.h\nnpm_config_registry=http://evil\nAZU_OUTPUT_PATH=/etc\nSPEC_FINE_URL=http://ok\n")
        File.write(File.join(dir, ".env.example"), "CPPFLAGS=\nnpm_config_registry=\n")
        AzuCLI::DotEnv.warning_io = IO::Memory.new
        begin
          with_env({"CPPFLAGS" => nil, "npm_config_registry" => nil, "AZU_OUTPUT_PATH" => nil, "SPEC_FINE_URL" => nil}) do
            AzuCLI::DotEnv.load_all(dir).should eq ["SPEC_FINE_URL"]
            ENV["CPPFLAGS"]?.should be_nil
            ENV["npm_config_registry"]?.should be_nil
            ENV["AZU_OUTPUT_PATH"]?.should be_nil
          end
        ensure
          AzuCLI::DotEnv.warning_io = STDERR
        end
      end
    end

    it "recognises application settings by their name" do
      %w[DATABASE_URL REDIS_URL PORT HOST CRYSTAL_ENV AZU_DB_LAZY APP_NAME SESSION_SECRET CSRF_SECRET JOOBQ_REDIS SMTP_USER MAIL_FROM
        STRIPE_SECRET API_KEY GITHUB_TOKEN CACHE_URL DB_HOST DB_PORT DB_PASSWORD].each { |name| AzuCLI::DotEnv.app_name?(name).should be_true }
      %w[LOG_LEVEL TEMPLATES_PATH PORT_REUSE SOMETHING_ELSE].each { |name| AzuCLI::DotEnv.app_name?(name).should be_false }
    end

    it "applies an unknown name only when .env.example lists it, and never a denylisted one" do
      with_dir do |dir|
        File.write(File.join(dir, ".env"), "AZU_CLI_SPEC_OK=1\nSPEC_LOG_LEVEL=debug\nSPEC_UNLISTED=x\nCC=./evil.sh\nSPEC_COMMENTED=1\n")
        File.write(File.join(dir, ".env.example"), "# docs\nSPEC_LOG_LEVEL=info\n# SPEC_COMMENTED=\nCC=\n")
        warnings = IO::Memory.new
        AzuCLI::DotEnv.warning_io = warnings
        begin
          with_env({"AZU_CLI_SPEC_OK" => nil, "SPEC_LOG_LEVEL" => nil, "SPEC_UNLISTED" => nil, "CC" => nil, "SPEC_COMMENTED" => nil}) do
            AzuCLI::DotEnv.load_all(dir).sort.should eq ["AZU_CLI_SPEC_OK", "SPEC_COMMENTED", "SPEC_LOG_LEVEL"]
            ENV["CC"]?.should be_nil
            ENV["SPEC_UNLISTED"]?.should be_nil
            warnings.to_s.should contain("SPEC_UNLISTED")
            warnings.to_s.should contain(".env.example")
            warnings.to_s.should contain("ignoring CC")
            warnings.to_s.should_not contain("evil.sh")
          end
        ensure
          AzuCLI::DotEnv.warning_io = STDERR
        end
      end
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

    it "ignores an --env value that is another flag, and flags after --" do
      AzuCLI.command_environment(["serve", "--env", "--port", "3000"]).should be_nil
      AzuCLI.command_environment(["serve", "-e"]).should be_nil
      AzuCLI.command_environment(["db:migrate", "--", "--env", "production"]).should be_nil
    end

    it "warns when the shell's DATABASE_URL will win over .env.test" do
      with_dir do |dir|
        File.write(File.join(dir, ".env.test"), "DATABASE_URL=sqlite3://./test.db\n")
        warnings = IO::Memory.new
        AzuCLI::DotEnv.warning_io = warnings
        begin
          with_env({"DATABASE_URL" => "postgres://prod:hunter2@db/prod", "CRYSTAL_ENV" => nil}) do
            AzuCLI.load_project_env(["test"], dir)
            warnings.to_s.should contain("DATABASE_URL is set in your environment")
            warnings.to_s.should_not contain("hunter2")
            ENV["DATABASE_URL"].should eq "postgres://prod:hunter2@db/prod"
          end
        ensure
          AzuCLI::DotEnv.warning_io = STDERR
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
