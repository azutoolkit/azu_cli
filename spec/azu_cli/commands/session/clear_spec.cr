require "../../../spec_helper"
require "../../../support/command_helpers"
require "../../../support/generator_helpers"
require "../../../support/fake_redis"

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

# Runs the block with the environment variable `name` set to `value` (unset when nil), then puts the old value back.
private def with_env(name : String, value : String?, &)
  old = ENV[name]?
  value ? (ENV[name] = value) : ENV.delete(name)
  yield
ensure
  old ? (ENV[name] = old) : ENV.delete(name)
end

# Writes the initializer `azu session:setup --backend <backend>` writes in the project in the current directory.
private def write_setup_initializer(backend : String) : Nil
  AzuCLI::Generate::Session.new(project: AzuCLI::Generate::Session.project_name, backend: backend)
    .render(".", force: true, interactive: false)
end

# Compilable initializer code the store tokenizer that session:clear used to have misread (from its review's
# oracle corpus): it took `redis` from each, while Crystal sets the cookie store or no store at all. Every one is
# an edit, so the command now refuses it before any connection.
private HAND_EDITED = {
  "and_guard"           => "false && config.store = Session::RedisStore(U).new\n",
  "and_guard_ml"        => "x = false &&\n  config.store = Session::RedisStore(U).new\n",
  "and_use_store"       => "false && Session.use_store(Session::RedisStore(U))\n",
  "or_guard"            => "true || Session.use_store(Session::RedisStore(U))\n",
  "bare_heredoc_op"     => "Session.use_store(Session::RedisStore(U))\nX = 1\nx = [] of Int32\nx <<X\nSession.use_store(Session::CookieStore(U))\nX\n",
  "squiggly"            => "Session.use_store(Session::RedisStore(U))\nx = [] of Int32\nX = 1\nx <<~X\nSession.use_store(Session::CookieStore(U))\nX\n",
  "div_regex"           => "a = 4\nb = 2\nconfig.store = Session::RedisStore(U).new\nx = a /b; config.store = Session::CookieStore(U).new #/\n",
  "div_regex2"          => "a = 4\nb = 2\nSession.use_store(Session::RedisStore(U))\nx = a /b; Session.use_store(Session::CookieStore(U)) # /\n",
  "heredoc_trailing_ws" => "x = <<-EOS\nEOS   \nconfig.store = Session::RedisStore(U).new\nEOS\n",
  "macro_expr"          => "Session.use_store(Session::RedisStore(U))\n{{ \"Session.use_store(Session::CookieStore(U))\".id }}\n",
  "proc_do"             => "f = -> do\n  Session.use_store(Session::RedisStore(U))\nend\n",
  "proc_new_do"         => "f = Proc(Nil).new do\n  Session.use_store(Session::RedisStore(U))\nend\n",
  "times0_do"           => "0.times do\n  Session.use_store(Session::RedisStore(U))\nend\n",
  "require"             => "Session.use_store(Session::RedisStore(U))\nrequire \"./other\"\n",
  "rescue_in_do"        => "Session.configure do |config|\n  1\nrescue\n  config.store = Session::RedisStore(U).new\nend\n",
  "ternary_if"          => "x = true ? nil : if false\n  Session.use_store(Session::RedisStore(U))\n  p if false\nend\n",
  "ternary_if_ret"      => "x = true ? nil : if false\n  Session.use_store(Session::RedisStore(U))\n  puts if false\nend\n",
  "ternary_q_if"        => "x = false ? if false\n  Session.use_store(Session::RedisStore(U))\n  p if false\nend : nil\n",
  "crlf"                => "Session.use_store(Session::RedisStore(U))\r\nx = 1\r\n",
  "end_marker"          => "__END__\nSession.use_store(Session::RedisStore(U))\n",
}

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
      in_tmp_project do
        write_setup_initializer("memory")
        result, _ = run_command(AzuCLI::Commands::Session::Clear.new, [] of String)
        result.success?.should be_false
        result.error.should contain("Memory sessions")
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

    it "refuses when there is no initializer and no SESSION_BACKEND" do
      in_tmp_project do
        with_env("SESSION_BACKEND", nil) do
          result, _ = run_command(AzuCLI::Commands::Session::Clear.new, ["--force"])
          result.success?.should be_false
          result.exit_code.should eq 1
          result.error.should contain("--backend")
        end
      end
    end

    it "takes SESSION_BACKEND when there is no initializer" do
      FakeRedis.open do |redis|
        in_tmp_project do
          with_env("SESSION_BACKEND", "redis") do
            with_redis_url(redis.url) do
              result, _ = run_command(AzuCLI::Commands::Session::Clear.new, ["--force"])
              result.success?.should be_true
              redis.commands.map(&.first).should contain("SCAN")
            end
          end
        end
      end
    end
  end

  describe "backend detection" do
    it "infers the backend of each file session:setup writes for the project, and deletes only session:* on redis" do
      FakeRedis.open do |redis|
        with_redis_url(redis.url("/4")) do
          {"cookie" => "Cookie sessions", "memory" => "Memory sessions"}.each do |backend, message|
            in_tmp_project do
              write_setup_initializer(backend)
              result, _ = run_command(AzuCLI::Commands::Session::Clear.new, ["--force"])
              result.exit_code.should eq 1
              result.error.should contain(message)
            end
          end
          redis.connections.should eq 0

          in_tmp_project do
            write_setup_initializer("redis")
            File.write("src/initializers/session.cr", File.read("src/initializers/session.cr").gsub("\n", "\r\n") + "\r\n")
            result, output = run_command(AzuCLI::Commands::Session::Clear.new, ["--force"])
            result.success?.should be_true
            output.should contain("database 4 of redis://127.0.0.1:#{redis.port}/4")
            output.should contain("other apps")
            redis.commands.should eq [["SELECT", "4"], ["SCAN", "0", "MATCH", "session:*", "COUNT", "100"]]
          end
        end
      end
    end

    it "reads the initializer of azu generate auth as cookie (its comment names Session::RedisStore)" do
      FakeRedis.open do |redis|
        in_generated_project do
          File.write("src/blog.cr", "handlers = [\n  Azu::Handler::RequestId.new,\n]\n")
          AzuCLI::Generate::Auth.new.render(File.expand_path("."), force: true, interactive: false)
          File.read("src/initializers/session.cr").should contain("Session::RedisStore")

          with_redis_url(redis.url) do
            with_env("SESSION_BACKEND", "redis") do
              [[] of String, ["--force"]].each do |args|
                result, _ = run_command(AzuCLI::Commands::Session::Clear.new, args)
                result.exit_code.should eq 1
                result.error.should contain("Cookie sessions")
              end
            end
          end
          redis.connections.should eq 0
        end
      end
    end

    it "refuses, with SESSION_BACKEND=redis too, every hand-edited initializer, and connects to nothing" do
      FakeRedis.open do |redis|
        with_redis_url(redis.url) do
          with_env("SESSION_BACKEND", "redis") do
            HAND_EDITED.each do |name, fragment|
              in_tmp_project do
                write_setup_initializer("redis")
                generated = File.read("src/initializers/session.cr")
                [fragment, generated + fragment, fragment + generated].each do |source|
                  File.write("src/initializers/session.cr", source)
                  result, output = run_command(AzuCLI::Commands::Session::Clear.new, ["--force"])
                  fail "#{name} was not refused" unless result.exit_code == 1
                  result.error.should contain("Pass --backend cookie|redis|memory")
                  result.error.should contain("edited")
                  output.should_not contain("deletes")
                end
              end
            end
          end
        end
        redis.connections.should eq 0
      end
    end

    it "still clears with an explicit --backend redis when the initializer was edited" do
      FakeRedis.open do |redis|
        in_tmp_project do
          write_setup_initializer("redis")
          File.write("src/initializers/session.cr", "# mine\n" + File.read("src/initializers/session.cr"))
          with_redis_url(redis.url) do
            result, output = run_command(AzuCLI::Commands::Session::Clear.new, ["--backend", "redis", "--force"])
            result.success?.should be_true
            output.should contain("other apps")
            redis.commands.map(&.first).should eq ["SELECT", "SCAN"]
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
    it "prints the target without any userinfo, and what goes, even with --force" do
      with_redis_url("redis://app:s3cret@127.0.0.1:1/3") do
        result, output = run_command(AzuCLI::Commands::Session::Clear.new, ["--backend", "redis", "--force"])
        result.success?.should be_false # nothing listens there
        output.should contain("redis://127.0.0.1:1/3")
        output.should contain("session:*")
        output.should contain("database 3")
        output.should contain("other apps")
        (output + result.error.to_s).should_not contain("s3cret")
        (output + result.error.to_s).should_not contain("app:")
      end
    end

    it "never prints a part of an odd userinfo, nor the raw URL, in the output or the error" do
      ["redis://u:sekq:ritq@127.0.0.1:1/0", "redis://u:p@sekritq@localhost:1/0", "redis://sekritq@127.0.0.1:1",
       "redis://sekritq@", "redis://:sekritq@[::1]:1/0"].each do |url|
        with_redis_url(url) do
          result, output = run_command(AzuCLI::Commands::Session::Clear.new, ["--backend", "redis", "--force"])
          result.success?.should be_false
          result.exit_code.should eq 1
          text = output + result.error.to_s
          {"sekq", "ritq", "sekritq", url}.each { |secret| text.should_not contain(secret) }
        end
      end
    end

    it "connects to a bracketed IPv6 host instead of calling the URL invalid" do
      with_redis_url("redis://:pw@[::1]:1/0") do
        result, output = run_command(AzuCLI::Commands::Session::Clear.new, ["--backend", "redis", "--force"])
        result.success?.should be_false # nothing listens there
        output.should contain("redis://[::1]:1/0")
        result.error.to_s.should_not contain("REDIS_URL")
      end
    end

    it "refuses a REDIS_URL that is not a redis URL (exit 1)" do
      ["notaurl", "http://host:6379", "redis://host:port", "redis://host:6379/x"].each do |url|
        with_redis_url(url) do
          result, _ = run_command(AzuCLI::Commands::Session::Clear.new, ["--backend", "redis", "--force"])
          result.success?.should be_false
          result.exit_code.should eq 1
          result.error.should contain("REDIS_URL")
        end
      end
    end
  end

  describe "Redis connection" do
    it "authenticates as the URL's user (AUTH user password), with the password only, or not at all" do
      {"alice:al%40icepw@" => ["AUTH", "alice", "al@icepw"], ":pw@" => ["AUTH", "pw"]}.each do |userinfo, auth|
        FakeRedis.open do |redis|
          with_redis_url(redis.url("/2", userinfo)) do
            result, _ = run_command(AzuCLI::Commands::Session::Clear.new, ["--backend", "redis", "--force"])
            result.success?.should be_true
            redis.commands.first(2).should eq [auth, ["SELECT", "2"]]
          end
        end
      end
      FakeRedis.open do |redis|
        with_redis_url(redis.url("/0", "alice@")) do
          run_command(AzuCLI::Commands::Session::Clear.new, ["--backend", "redis", "--force"])
          redis.commands.first.should eq ["SELECT", "0"]
        end
      end
    end

    it "says the server has no such database, and deletes nothing" do
      FakeRedis.open do |redis|
        with_redis_url(redis.url("/16", ":sekritpw@")) do
          result, _ = run_command(AzuCLI::Commands::Session::Clear.new, ["--backend", "redis", "--force"])
          result.exit_code.should eq 1
          result.error.should contain("has no database 16")
          result.error.should contain("Nothing was deleted")
          result.error.should_not contain("sekritpw")
          redis.commands.map(&.first).should_not contain("SCAN")
        end
      end
    end

    it "gives up on a server that does not answer, plain or TLS, with exit 1" do
      ["redis", "rediss"].each do |scheme|
        FakeRedis.open(silent: true) do |redis|
          with_redis_url(redis.url("/0", ":pw@", scheme)) do
            command = AzuCLI::Commands::Session::Clear.new
            command.connect_timeout = 300.milliseconds
            command.command_timeout = 300.milliseconds
            done = Channel({AzuCLI::Commands::Result, String}).new(1)
            spawn { done.send(run_command(command, ["--backend", "redis", "--force"])) }
            result = select
            when outcome = done.receive then outcome.first
            when timeout(5.seconds) then fail "#{scheme}:// still waiting after 5 seconds"
            end
            result.exit_code.should eq 1
            result.error.should contain("did not answer")
            result.error.should contain("Nothing was deleted")
          end
        end
      end
    end

    it "waits 5 seconds to connect and 10 for each command by default" do
      command = AzuCLI::Commands::Session::Clear.new
      {command.connect_timeout, command.command_timeout}.should eq({5.seconds, 10.seconds})
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
