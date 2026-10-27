require "../../spec_helper"
require "../../support/generator_helpers"

include GeneratorHelpers

describe AzuCLI::Generate::Session do
  render = ->(backend : String) do
    AzuCLI::Generate::Session.new("blog", backend).render(File.expand_path("."), force: true, interactive: false)
    File.read("src/initializers/session.cr")
  end

  it "stores sessions in an encrypted cookie by default, with the session shard" do
    in_generated_project do
      AzuCLI::Generate::Session.new("blog").backend.should eq "cookie"
      initializer = render.call("cookie")

      initializer.should contain(%(require "session"))
      initializer.should contain("Session.use_store(Session::CookieStore(UserSession))")
      initializer.should contain("config.store = Session::CookieStore(UserSession).new")
      initializer.should_not contain("Session::Session.new")
    end
  end

  it "reads the secret from SESSION_SECRET and never writes one into the source" do
    in_generated_project do
      initializer = render.call("cookie")

      initializer.should contain(%(config.secret = Azu::Env.secret("SESSION_SECRET")))
      initializer.should_not match(/[0-9a-f]{32}/)
      File.read(".env").should match(/^SESSION_SECRET=[0-9a-f]{64}$/m)
      (File.info(".env").permissions.value & 0o077).should eq 0
    end
  end

  it "uses the Redis and memory stores the shard has" do
    in_generated_project do
      render.call("redis").should contain(%(Session::RedisStore(UserSession).new(Redis.new(url: ENV["REDIS_URL"]? || "redis://localhost:6379"))))
      render.call("memory").should contain("Session::MemoryStore(UserSession).new")
    end
  end

  it "mounts the session handler after the request id in the app file" do
    in_generated_project do
      File.write("src/blog.cr", "handlers = [\n  Azu::Handler::RequestId.new,\n  Azu::Handler::Rescuer.new,\n]\n")
      render.call("cookie")

      File.read("src/blog.cr").should contain("  Azu::Handler::RequestId.new,\n  Session::SessionHandler(UserSession).new(Session.session),\n")
    end
  end

  it "refuses a database backend: the session shard has no database store" do
    expect_raises(ArgumentError, /no database store/) { AzuCLI::Generate::Session.new("blog", "database") }
  end
end
