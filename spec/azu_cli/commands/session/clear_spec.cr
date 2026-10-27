require "../../../spec_helper"
require "../../../support/command_helpers"
require "../../../support/generator_helpers"

include CommandHelpers
include GeneratorHelpers

# Runs the block with REDIS_URL set to `url` (unset when nil), then puts the old value back.
private def with_redis_url(url : String?, &)
  old = ENV["REDIS_URL"]?
  url ? (ENV["REDIS_URL"] = url) : ENV.delete("REDIS_URL")
  yield
ensure
  old ? (ENV["REDIS_URL"] = old) : ENV.delete("REDIS_URL")
end

# A port nothing listens on: a spec that reached Redis by mistake fails instead of deleting keys.
private NO_REDIS = "redis://127.0.0.1:1/15"

describe AzuCLI::Commands::Session::Clear do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::Session::Clear.new
      command.name.should eq("session:clear")
    end

    it "has correct description" do
      command = AzuCLI::Commands::Session::Clear.new
      command.description.should contain("Clear")
    end

    it "has force set to false by default" do
      command = AzuCLI::Commands::Session::Clear.new
      command.force.should be_false
    end

    it "has backend set to nil by default" do
      command = AzuCLI::Commands::Session::Clear.new
      command.backend.should be_nil
    end
  end

  describe "option parsing" do
    it "parses --force option" do
      command = AzuCLI::Commands::Session::Clear.new
      command.parse_args(["--force"])

      command.force.should be_true
    end

    it "parses -f short option" do
      command = AzuCLI::Commands::Session::Clear.new
      command.parse_args(["-f"])

      command.force.should be_true
    end

    it "parses --backend option" do
      command = AzuCLI::Commands::Session::Clear.new
      command.parse_args(["--backend", "redis"])

      command.backend.should eq("redis")
    end

    it "parses -b short option" do
      command = AzuCLI::Commands::Session::Clear.new
      command.parse_args(["-b", "database"])

      command.backend.should eq("database")
    end

    it "parses multiple options" do
      command = AzuCLI::Commands::Session::Clear.new
      command.parse_args(["--backend", "memory", "--force"])

      command.backend.should eq("memory")
      command.force.should be_true
    end
  end

  describe "backend" do
    it "honours --backend over the initializer, and explains a cookie backend without asking" do
      in_tmp_project(files: {"src/initializers/session.cr" => "Session.use_store(Session::MemoryStore(UserSession))\n"}) do
        result, _ = run_command(AzuCLI::Commands::Session::Clear.new, ["--backend", "cookie"])
        result.success?.should be_false
        result.error.should contain("Cookie sessions")
        result.error.should contain("SESSION_SECRET")
      end
    end

    it "explains a memory backend without asking" do
      in_tmp_project(files: {"src/initializers/session.cr" => "Session.use_store(Session::MemoryStore(UserSession))\n"}) do
        result, _ = run_command(AzuCLI::Commands::Session::Clear.new, [] of String)
        result.success?.should be_false
        result.error.should contain("Memory sessions")
      end
    end

    it "reads the backend from the initializer" do
      in_tmp_project(files: {"src/initializers/session.cr" => "Session.use_store(Session::CookieStore(UserSession))\n"}) do
        result, _ = run_command(AzuCLI::Commands::Session::Clear.new, ["--force"])
        result.error.should contain("Cookie sessions")
      end
    end

    it "is a usage error (exit 2) for an unknown backend, a --backend without value or an unknown option" do
      in_tmp_project do
        [["--backend", "database", "--force"], ["--backend"], ["-b", "--force"], ["--bogus", "--force"]].each do |args|
          result, _ = run_command(AzuCLI::Commands::Session::Clear.new, args)
          result.success?.should be_false
          result.exit_code.should eq 2
        end
      end
    end

    it "refuses when it cannot tell the backend" do
      in_tmp_project do
        result, _ = run_command(AzuCLI::Commands::Session::Clear.new, ["--force"])
        result.success?.should be_false
        result.error.should contain("--backend")
      end
    end
  end

  describe "backend detection" do
    it "reads cookie from the initializer `azu generate auth` writes (its comment names Session::RedisStore)" do
      in_generated_project do
        File.write("src/blog.cr", "handlers = [\n  Azu::Handler::RequestId.new,\n]\n")
        AzuCLI::Generate::Auth.new.render(File.expand_path("."), force: true, interactive: false)
        File.read("src/initializers/session.cr").should contain("Session::RedisStore")

        AzuCLI::Commands::Session::Clear.store_backends(File.read("src/initializers/session.cr")).should eq ["cookie"]
        with_redis_url(NO_REDIS) do
          result, _ = run_command(AzuCLI::Commands::Session::Clear.new, [] of String)
          result.success?.should be_false
          result.error.should contain("Cookie sessions")
        end
      end
    end

    it "ignores a store named only in a comment" do
      source = "# switch to Session::RedisStore for revocation\n# config.store = Session::RedisStore(UserSession).new\n" \
               "Session.configure do |config|\n  config.store = Session::CookieStore(UserSession).new # not RedisStore\nend\n"
      AzuCLI::Commands::Session::Clear.store_backends(source).should eq ["cookie"]
      AzuCLI::Commands::Session::Clear.store_backends("# Session.use_store(Session::RedisStore(UserSession))\n").should be_empty
    end

    it "refuses an initializer whose RedisStore is only in a comment" do
      in_tmp_project(files: {"src/initializers/session.cr" => "# use Session::RedisStore\nrequire \"session\"\n"}) do
        with_redis_url(NO_REDIS) do
          result, _ = run_command(AzuCLI::Commands::Session::Clear.new, ["--force"])
          result.success?.should be_false
          result.exit_code.should eq 1
          result.error.should contain("--backend")
        end
      end
    end

    it "reads the multi-line forms the generators emit" do
      AzuCLI::Commands::Session::Clear.store_backends(
        "Session.use_store(\n  Session::RedisStore(UserSession)\n)\nSession.configure do |config|\n  config.store =\n    Session::RedisStore(UserSession).new(Redis.new(url: \"redis://x#y\"))\nend\n"
      ).should eq ["redis"]
    end

    it "reads the backend of every initializer session:setup writes" do
      AzuCLI::Generate::Session::BACKENDS.each do |backend|
        in_tmp_project do
          AzuCLI::Generate::Session.new(project: "blog", backend: backend).render(".", force: true, interactive: false)
          AzuCLI::Commands::Session::Clear.store_backends(File.read("src/initializers/session.cr")).should eq [backend]
        end
      end
    end

    it "refuses an initializer whose stores disagree or are not the shard's" do
      ["Session.use_store(Session::CookieStore(UserSession))\nconfig.store = Session::RedisStore(UserSession).new\n",
       "config.store = MyStore.new\n"].each do |source|
        in_tmp_project(files: {"src/initializers/session.cr" => source}) do
          with_redis_url(NO_REDIS) do
            result, _ = run_command(AzuCLI::Commands::Session::Clear.new, ["--force"])
            result.success?.should be_false
            result.exit_code.should eq 1
            result.error.should contain("--backend")
          end
        end
      end
    end
  end

  describe "usage" do
    it "shows the help for -h and --help without clearing anything" do
      in_tmp_project(files: {"src/initializers/session.cr" => "Session.use_store(Session::RedisStore(UserSession))\n"}) do
        with_redis_url(NO_REDIS) do
          ["-h", "--help"].each do |flag|
            result, output = run_command(AzuCLI::Commands::Session::Clear.new, [flag, "--force"])
            result.success?.should be_true
            output.should contain("Usage: azu session:clear")
          end
        end
      end
    end

    it "is a usage error (exit 2) for an argument" do
      in_tmp_project do
        result, _ = run_command(AzuCLI::Commands::Session::Clear.new, ["everything", "--backend", "redis", "--force"])
        result.exit_code.should eq 2
        result.error.should contain("everything")
      end
    end
  end

  describe "Redis target" do
    it "prints the target, password redacted, and what goes, even with --force" do
      with_redis_url("redis://app:s3cret@127.0.0.1:1/3") do
        result, output = run_command(AzuCLI::Commands::Session::Clear.new, ["--backend", "redis", "--force"])
        result.success?.should be_false # nothing listens there
        output.should contain("redis://app:***@127.0.0.1:1/3")
        output.should contain("session:*")
        output.should contain("database 3")
        output.should contain("other apps")
        output.should_not contain("s3cret")
        result.error.to_s.should_not contain("s3cret")
      end
    end

    it "redacts a password given without a user" do
      AzuCLI::Commands::Session::Clear.redacted_url(URI.parse("redis://:pw@host:6380")).should eq "redis://:***@host:6380"
      AzuCLI::Commands::Session::Clear.redacted_url(URI.parse("redis://host")).should eq "redis://host"
    end

    it "refuses a REDIS_URL that is not a redis URL (exit 1)" do
      ["notaurl", "http://host:6379", "redis://host:port"].each do |url|
        with_redis_url(url) do
          result, _ = run_command(AzuCLI::Commands::Session::Clear.new, ["--backend", "redis", "--force"])
          result.success?.should be_false
          result.exit_code.should eq 1
          result.error.should contain("REDIS_URL")
        end
      end
    end
  end

  describe "Redis keys" do
    it "matches the keys of the session shard's RedisStore (session:<id>)" do
      AzuCLI::Commands::Session::Clear::REDIS_KEY_PATTERN.should eq "session:*"
    end

    it "deletes the session keys with SCAN, and no other key (needs Redis at REDIS_URL, database 15)" do
      redis = begin
        Redis.new(url: "#{(ENV["REDIS_URL"]? || "redis://localhost:6379").rstrip('/')}/15")
      rescue Redis::CannotConnectError
        nil
      end
      pending!("no Redis server") unless redis

      redis.flushdb
      250.times { |i| redis.set("session:#{i}", "{}") }
      redis.set("blog:session:1", "{}")
      redis.set("other", "1")

      AzuCLI::Commands::Session::Clear.clear_redis(redis).should eq 250
      redis.keys("*").map(&.to_s).sort!.should eq ["blog:session:1", "other"]
      redis.flushdb
      redis.close
    end
  end
end
