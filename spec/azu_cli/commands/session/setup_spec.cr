require "../../../spec_helper"
require "../../../support/command_helpers"

include CommandHelpers

private APP_FILE         = "handlers = [\n  Azu::Handler::RequestId.new,\n  Azu::Handler::Rescuer.new,\n]\n"
private AUTH_INITIALIZER = File.read(File.join(__DIR__, "../../../../src/azu_cli/templates/auth/src/initializers/session.cr.ecr"))

private def setup(args : Array(String) = [] of String) : AzuCLI::Commands::Result
  run_command(AzuCLI::Commands::Session::Setup.new, args)[0]
end

describe AzuCLI::Commands::Session::Setup do
  it "writes the initializer and mounts the handler" do
    in_tmp_project(files: {"src/blog.cr" => APP_FILE}) do
      setup.success?.should be_true

      File.exists?("src/initializers/session.cr").should be_true
      File.read("src/blog.cr").should contain("Session::SessionHandler(UserSession).new(Session.session),")
    end
  end

  it "refuses to overwrite an existing initializer without --force, and overwrites it with --force" do
    in_tmp_project(files: {"src/blog.cr" => APP_FILE, "src/initializers/session.cr" => "# mine\n"}) do
      result = setup
      result.success?.should be_false
      result.exit_code.should eq 1
      result.error.should contain("src/initializers/session.cr exists")
      result.error.should contain("--force")
      File.read("src/initializers/session.cr").should eq "# mine\n"

      setup(["--force"]).success?.should be_true
      File.read("src/initializers/session.cr").should contain("class UserSession < Session::Base")
    end
  end

  it "never overwrites the initializer of `azu generate auth`, even with --force" do
    in_tmp_project(files: {"src/blog.cr" => APP_FILE, "src/initializers/session.cr" => AUTH_INITIALIZER}) do
      result = setup(["--force"])
      result.success?.should be_false
      result.error.should contain("azu generate auth")
      File.read("src/initializers/session.cr").should eq AUTH_INITIALIZER
    end
  end

  it "recognises an older auth initializer by its authenticated? method, and says how to replace it" do
    initializer = "class UserSession < Session::Base\n  property user_id : Int64? = nil\n\n  def authenticated? : Bool\n    !user_id.nil?\n  end\nend\n"
    in_tmp_project(files: {"src/blog.cr" => APP_FILE, "src/initializers/session.cr" => initializer}) do
      error = setup(["-f"]).error.to_s
      error.should contain("looks like it was written by `azu generate auth`")
      error.should contain("delete")
      error.should contain("config.store")
      File.read("src/initializers/session.cr").should eq initializer
    end
  end

  it "refuses (exit 1), even with --force, when auth's files exist and its initializer was deleted" do
    {"src/services/auth_throttle.cr" => "", "src/endpoints/sessions/create_endpoint.cr" => ""}.each do |path, content|
      in_tmp_project(files: {"src/blog.cr" => APP_FILE, path => content}) do
        result = setup(["--force"])
        result.success?.should be_false
        result.exit_code.should eq 1
        result.error.should contain(path.starts_with?("src/endpoints") ? "src/endpoints/sessions" : path)
        File.exists?("src/initializers/session.cr").should be_false
        File.exists?(".env").should be_false
      end
    end
  end

  it "shows the help for -h and --help without writing anything" do
    in_tmp_project(files: {"src/blog.cr" => APP_FILE}) do
      ["-h", "--help"].each do |flag|
        result, output = run_command(AzuCLI::Commands::Session::Setup.new, [flag])
        result.success?.should be_true
        output.should contain("Usage: azu session:setup")
      end
      File.exists?("src/initializers/session.cr").should be_false
    end
  end

  it "refuses, writing nothing, when the app file has no place for the session handler" do
    in_tmp_project(files: {"src/blog.cr" => "handlers = [\n  Azu::Handler::Rescuer.new,\n]\n"}) do
      result = setup
      result.success?.should be_false
      result.error.should contain("Azu::Handler::RequestId.new,")
      File.exists?("src/initializers/session.cr").should be_false
      File.exists?(".env").should be_false
    end
  end

  it "refuses outside a project with an app file" do
    in_tmp_project do
      result = setup
      result.success?.should be_false
      result.error.should contain("src/blog.cr")
      File.exists?("src/initializers/session.cr").should be_false
    end
  end

  it "takes --backend and -b" do
    in_tmp_project(files: {"src/blog.cr" => APP_FILE}) do
      setup(["--backend", "memory"]).success?.should be_true
      File.read("src/initializers/session.cr").should contain("Session::MemoryStore(UserSession).new")
      setup(["-b", "redis", "--force"]).success?.should be_true
      File.read("src/initializers/session.cr").should contain("Session::RedisStore(UserSession)")
      setup(["--backend=cookie", "--force"]).success?.should be_true
      File.read("src/initializers/session.cr").should contain("Session::CookieStore(UserSession).new")
    end
  end

  it "is a usage error (exit 2) for an unknown option, a --backend without value, an unknown backend or an argument" do
    in_tmp_project(files: {"src/blog.cr" => APP_FILE}) do
      [["--bogus"], ["-x"], ["--backend"], ["--backend", "--force"], ["-b"], ["--backend="], ["--backend", "database"], ["redis"]].each do |args|
        result = setup(args)
        result.success?.should be_false
        result.exit_code.should eq 2
      end
      File.exists?("src/initializers/session.cr").should be_false
    end
  end
end
