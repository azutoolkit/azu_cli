require "../../spec_helper"
require "../../support/command_helpers"

include CommandHelpers

# Answers from a table instead of the machine.
private class FakeSystem < AzuCLI::Diagnostics::System
  getter calls = [] of String
  property reachable = true
  property free = true
  property denied = false

  def initialize(@commands : Hash(String, {Int32, String}) = {} of String => {Int32, String})
  end

  def capture(command : String, args : Array(String), chdir : String) : {Int32, String}?
    line = ([command] + args).join(" ")
    @calls << line
    @commands[line]?
  end

  def tcp_reachable?(host : String, port : Int32, timeout : Time::Span) : Bool
    @calls << "tcp #{host}:#{port}"
    reachable
  end

  def port_state(port : Int32) : AzuCLI::Diagnostics::PortState
    @calls << "bind #{port}"
    return AzuCLI::Diagnostics::PortState::Denied if denied
    free ? AzuCLI::Diagnostics::PortState::Free : AzuCLI::Diagnostics::PortState::InUse
  end
end

private GOOD_COMMANDS = {
  "crystal --version"                 => {0, "Crystal 1.19.1 [a3178c32b] (2026-01-20)\n\nLLVM: 20.1.8\n"},
  "shards --version"                  => {0, "Shards 0.19.1 (2025-01-01)\n"},
  "shards check"                      => {0, "Dependencies are satisfied\n"},
  "docker --version"                  => {0, "Docker version 27.0.0\n"},
  "git check-ignore -q .env"          => {0, ""},
  "git ls-files --error-unmatch .env" => {1, ""},
}

private def checks(root : String, env = {} of String => String, system = FakeSystem.new(GOOD_COMMANDS))
  AzuCLI::Diagnostics::Checks.new(root, ->(name : String) { env[name]? }, system)
end

describe AzuCLI::Diagnostics::Checks do
  describe "#crystal" do
    it "is ok at or above the shard.yml floor" do
      in_tmp_project do |dir|
        check = checks(dir).crystal

        check.status.ok?.should be_true
        check.message.should contain("1.19.1")
        check.hint.should be_nil
      end
    end

    it "fails below the floor, naming both versions and a hint" do
      in_tmp_project do |dir|
        system = FakeSystem.new(GOOD_COMMANDS.merge({"crystal --version" => {0, "Crystal 1.18.2 [abc] (2025-01-01)\n"}}))
        check = checks(dir, system: system).crystal

        check.status.fail?.should be_true
        check.message.should contain("1.18.2")
        check.message.should contain("1.19.1")
        check.hint.to_s.should contain("install Crystal 1.19.1")
      end
    end

    it "reads floors written as a requirement, with two components, or not at all" do
      in_tmp_project(shard_yml: "name: blog\nversion: 0.1.0\ncrystal: '~> 1.19'\n") do |dir|
        checks(dir).crystal_floor.should eq "1.19"
        checks(dir).crystal.status.ok?.should be_true
      end
      in_tmp_project(shard_yml: "name: blog\nversion: 0.1.0\n") do |dir|
        checks(dir).crystal_floor.should be_nil
        checks(dir).crystal.message.should eq "Crystal 1.19.1"
      end
    end

    it "fails when crystal is not installed" do
      in_tmp_project do |dir|
        check = checks(dir, system: FakeSystem.new).crystal

        check.status.fail?.should be_true
        check.hint.to_s.should contain("crystal-lang.org")
      end
    end
  end

  describe "#shards and #dependencies" do
    it "reports the shards version" do
      in_tmp_project do |dir|
        checks(dir).shards.message.should eq "Shards 0.19.1 (2025-01-01)"
      end
    end

    it "fails when shards check says the installed shards differ" do
      in_tmp_project(files: {"shard.lock" => "version: 2.0\n"}) do |dir|
        system = FakeSystem.new(GOOD_COMMANDS.merge({"shards check" => {1, "Dependencies aren't satisfied"}}))
        check = checks(dir, system: system).dependencies

        check.status.fail?.should be_true
        check.hint.should eq "run 'shards install'"
      end
    end

    it "warns about a missing shard.lock and is ok when installed and locked" do
      in_tmp_project do |dir|
        checks(dir).dependencies.status.warn?.should be_true
      end
      in_tmp_project(files: {"shard.lock" => "version: 2.0\n"}) do |dir|
        checks(dir).dependencies.status.ok?.should be_true
      end
    end
  end

  describe "#database" do
    it "warns when DATABASE_URL is unset in a project that uses CQL, and is ok when the project has no database" do
      in_tmp_project do |dir|
        checks(dir).database.status.warn?.should be_true
      end
      in_tmp_project(shard_yml: "name: blog\nversion: 0.1.0\n") do |dir|
        checks(dir).database.status.ok?.should be_true
      end
    end

    it "checks that a SQLite file is writable, or that its directory is" do
      in_tmp_project(files: {"db/blog.db" => ""}) do |dir|
        checks(dir, {"DATABASE_URL" => "sqlite3://./db/blog.db?journal_mode=wal"}).database.status.ok?.should be_true
      end
      in_tmp_project(files: {"db/.keep" => ""}) do |dir|
        check = checks(dir, {"DATABASE_URL" => "sqlite3://./db/new.db"}).database
        check.status.warn?.should be_true
        check.hint.should eq "run 'azu db:setup'"
      end
      in_tmp_project do |dir|
        checks(dir, {"DATABASE_URL" => "sqlite3://./nowhere/new.db"}).database.status.fail?.should be_true
        checks(dir, {"DATABASE_URL" => "sqlite3::memory:"}).database.status.ok?.should be_true
      end
    end

    it "connects to a server with a timeout and never prints the password" do
      in_tmp_project do |dir|
        system = FakeSystem.new(GOOD_COMMANDS)
        check = checks(dir, {"DATABASE_URL" => "postgres://app:hunter2@db.internal:5433/blog"}, system).database

        check.status.ok?.should be_true
        check.message.should contain("postgres://db.internal:5433/blog")
        check.message.should_not contain("hunter2")
        check.message.should_not contain("app:")
        system.calls.should contain("tcp db.internal:5433")
      end
    end

    it "fails, without the password, when the server does not answer" do
      in_tmp_project do |dir|
        system = FakeSystem.new(GOOD_COMMANDS)
        system.reachable = false
        check = checks(dir, {"DATABASE_URL" => "mysql://root:hunter2@localhost/blog"}, system).database

        check.status.fail?.should be_true
        check.message.should contain("mysql://localhost:3306/blog")
        (check.message + check.hint.to_s).should_not contain("hunter2")
        check.message.should contain("3s")
      end
    end

    it "connects to an IPv6 literal without its brackets and prints it with them" do
      in_tmp_project do |dir|
        system = FakeSystem.new(GOOD_COMMANDS)
        check = checks(dir, {"DATABASE_URL" => "postgres://u:p@[::1]:5432/db"}, system).database

        check.status.ok?.should be_true
        system.calls.should contain("tcp ::1:5432")
        check.message.should contain("postgres://[::1]:5432/db")
      end
    end

    it "only warns for a unix socket URL, without connecting" do
      in_tmp_project do |dir|
        ["postgres:///db?host=/var/run/postgresql", "postgres://u:p@/db", "mysql://u@localhost/db?host=/tmp/mysql.sock"].each do |url|
          system = FakeSystem.new(GOOD_COMMANDS)
          check = checks(dir, {"DATABASE_URL" => url}, system).database

          check.status.warn?.should be_true
          system.calls.reject(&.starts_with?("git")).select(&.starts_with?("tcp")).should be_empty
        end
      end
    end

    it "prints neither the user nor any part of a password, however the URL is malformed" do
      leaks = {
        "postgres://app:12/tail-of-secret@db.internal:5432/blog" => ["app", "12", "tail-of-secret"],
        "postgres://app:p@ss-word@db.internal:5432/blog"         => ["app", "p@ss", "ss-word"],
        "postgres://app:p/ss@w/rd@db.internal/blog"              => ["app", "ss", "rd"],
        "jdoe-acct:secret-pass@db.internal/blog"                 => ["jdoe-acct", "secret-pass"],
        "myuser:hunter2@db.internal:5432/blog"                   => ["myuser", "hunter2"],
        "weird://alice:pw-x@db.internal/blog"                    => ["weird", "alice", "pw-x"],
      }
      leaks.each do |url, secrets|
        in_tmp_project do |dir|
          check = checks(dir, {"DATABASE_URL" => url}, FakeSystem.new(GOOD_COMMANDS)).database
          text = check.message + " " + check.hint.to_s

          secrets.each { |secret| text.should_not contain(secret) }
        end
      end
    end

    it "still checks the host when the user and password are stripped from a malformed URL" do
      in_tmp_project do |dir|
        system = FakeSystem.new(GOOD_COMMANDS)
        check = checks(dir, {"DATABASE_URL" => "postgres://app:p@ss-word@db.internal:5432/blog"}, system).database

        check.status.ok?.should be_true
        check.message.should contain("postgres://db.internal:5432/blog")
        system.calls.should contain("tcp db.internal:5432")
      end
    end

    it "fails on a URL without a host" do
      in_tmp_project do |dir|
        checks(dir, {"DATABASE_URL" => "blog"}).database.status.fail?.should be_true
      end
    end
  end

  describe "#environment" do
    it "names the variables .env.example leaves blank that are not set, never their values" do
      files = {".env.example" => "PORT=4000\nCSRF_SECRET=\nSESSION_SECRET=\n# DATABASE_URL=\nAPI_TOKEN=\n"}
      in_tmp_project(files: files) do |dir|
        check = checks(dir, {"API_TOKEN" => "tok-123"}).environment

        check.status.warn?.should be_true
        check.message.should eq "not set: CSRF_SECRET"
        check.message.should_not contain("tok-123")
      end
    end

    it "expects SESSION_SECRET once authentication is generated, and fails in production" do
      files = {".env.example" => "CSRF_SECRET=\nSESSION_SECRET=\n", "src/initializers/session.cr" => ""}
      in_tmp_project(files: files) do |dir|
        checks(dir, {"CSRF_SECRET" => "x"}).environment.message.should eq "not set: SESSION_SECRET"
        checks(dir, {"CRYSTAL_ENV" => "production"}).environment.status.fail?.should be_true
      end
    end

    it "is ok when every blank variable is set, or there is no example" do
      in_tmp_project(files: {".env.example" => "CSRF_SECRET=\n"}) do |dir|
        checks(dir, {"CSRF_SECRET" => "x"}).environment.status.ok?.should be_true
      end
      in_tmp_project do |dir|
        checks(dir).environment.status.ok?.should be_true
      end
    end
  end

  describe "#secrets" do
    it "warns about short or placeholder secrets without printing them" do
      in_tmp_project do |dir|
        check = checks(dir, {"CSRF_SECRET" => "changeme", "SESSION_SECRET" => Random::Secure.hex(32)}).secrets

        check.status.warn?.should be_true
        check.message.should contain("CSRF_SECRET")
        check.message.should_not contain("SESSION_SECRET")
        check.message.should_not contain("changeme")
      end
    end

    it "is ok for long random secrets and for secrets that are not set" do
      in_tmp_project do |dir|
        checks(dir, {"CSRF_SECRET" => Random::Secure.hex(32)}).secrets.status.ok?.should be_true
        checks(dir).secrets.status.ok?.should be_true
      end
    end

    it "flags a secret written into the source, and fails in production" do
      in_tmp_project(files: {"src/blog.cr" => %(config.secret = "a-literal-secret"\n)}) do |dir|
        check = checks(dir, {"CRYSTAL_ENV" => "production"}).secrets

        check.status.fail?.should be_true
        check.message.should contain("src/blog.cr")
        check.message.should_not contain("a-literal-secret")
      end
    end

    it "accepts secrets read from the environment in the source" do
      in_tmp_project(files: {"src/blog.cr" => %(config.secret = ENV["SESSION_SECRET"]?.presence || ""\n)}) do |dir|
        checks(dir).secrets.status.ok?.should be_true
      end
    end
  end

  describe "#port" do
    it "is ok when the port is free, default 4000, and warns when it is taken" do
      in_tmp_project do |dir|
        system = FakeSystem.new(GOOD_COMMANDS)
        checks(dir, system: system).port.message.should eq "port 4000 is free"
        system.calls.should contain("bind 4000")

        system.free = false
        check = checks(dir, {"PORT" => "8080"}, system).port
        check.status.warn?.should be_true
        check.message.should contain("8080")
      end
    end

    it "says so when a port below 1024 is not allowed, instead of calling it in use" do
      in_tmp_project do |dir|
        system = FakeSystem.new(GOOD_COMMANDS)
        system.denied = true
        check = checks(dir, {"PORT" => "80"}, system).port
        check.status.warn?.should be_true
        check.message.should contain("cannot be used")
        check.message.should_not contain("in use")
      end
    end

    it "fails on a PORT that is not a port" do
      in_tmp_project do |dir|
        ["abc", "0", "70000"].each { |value| checks(dir, {"PORT" => value}).port.status.fail?.should be_true }
      end
    end
  end

  describe "#docker" do
    it "is ok when installed, and when absent unless the project has a Dockerfile" do
      in_tmp_project do |dir|
        checks(dir).docker.message.should eq "docker is installed"
        checks(dir, system: FakeSystem.new).docker.status.ok?.should be_true
      end
      in_tmp_project(files: {"Dockerfile" => "FROM scratch\n"}) do |dir|
        checks(dir, system: FakeSystem.new).docker.status.warn?.should be_true
      end
    end
  end

  describe "#gitignore" do
    it "is ok without a .env, and when git ignores it" do
      in_tmp_project do |dir|
        checks(dir).gitignore.message.should eq "no .env file"
      end
      in_tmp_project(files: {".env" => "A=1\n"}) do |dir|
        checks(dir).gitignore.status.ok?.should be_true
      end
    end

    it "fails when .env is not ignored, and when it is tracked" do
      in_tmp_project(files: {".env" => "A=1\n"}) do |dir|
        not_ignored = FakeSystem.new(GOOD_COMMANDS.merge({"git check-ignore -q .env" => {1, ""}}))
        check = checks(dir, system: not_ignored).gitignore
        check.status.fail?.should be_true
        check.hint.should eq "add '.env' to .gitignore"

        tracked = FakeSystem.new(GOOD_COMMANDS.merge({"git ls-files --error-unmatch .env" => {0, ".env"}}))
        checks(dir, system: tracked).gitignore.message.should eq ".env is tracked by git"
      end
    end

    it "falls back to .gitignore outside a git repository" do
      outside = GOOD_COMMANDS.merge({"git check-ignore -q .env" => {128, "fatal: not a git repository"}})
      in_tmp_project(files: {".env" => "A=1\n", ".gitignore" => "/lib/\n.env\n"}) do |dir|
        checks(dir, system: FakeSystem.new(outside)).gitignore.status.ok?.should be_true
      end
      in_tmp_project(files: {".env" => "A=1\n", ".gitignore" => "/lib/\n"}) do |dir|
        checks(dir, system: FakeSystem.new(outside)).gitignore.status.fail?.should be_true
      end
    end
  end

  describe "#run" do
    it "runs every check once, in order, with ids" do
      in_tmp_project do |dir|
        checks(dir).run.map(&.id).should eq %w(crystal shards dependencies database env secrets port docker gitignore)
      end
    end
  end
end
