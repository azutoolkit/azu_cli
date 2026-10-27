require "../../../spec_helper"
require "../../../support/command_helpers"

include CommandHelpers

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
