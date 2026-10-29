require "../../spec_helper"

private class DatabaseProbe < AzuCLI::Commands::DB::Create
  def server_url
    server_connection_url
  end

  def app_url(name : String)
    database_connection_url(name)
  end

  def identifier(name : String)
    quote_database_name(name)
  end
end

describe "database administrative connection safety" do
  it "preserves TLS and deadlines, encoded credentials, and IPv6 when changing databases" do
    TestHelpers::TestSetup.with_env({"DATABASE_URL" => "postgres://ops%40team:p%3A%2F%40%2540@[::1]:5433/app%20db?sslmode=verify-full&connect_timeout=3"}) do
      command = DatabaseProbe.new
      command.username.should eq("ops@team")
      command.password.should eq("p:/@%40")
      command.database_name.should eq("app db")
      uri = URI.parse(command.server_url)
      uri.hostname.should eq("::1")
      uri.port.should eq(5433)
      uri.user.should eq("ops@team")
      uri.password.should eq("p:/@%40")
      uri.path.should eq("/postgres")
      uri.query.should eq("sslmode=verify-full&connect_timeout=3")
      app = URI.parse(command.app_url("tenant/a b"))
      app.path.should eq("/tenant%2Fa%20b")
      app.query.should eq(uri.query)
    end
  end

  it "quotes identifiers for each server dialect and rejects NUL" do
    command = DatabaseProbe.new
    command.adapter = "postgres"
    command.identifier("a\"; DROP DATABASE other;--").should eq("\"a\"\"; DROP DATABASE other;--\"")
    command.adapter = "mysql"
    command.identifier("a`-b").should eq("`a``-b`")
    expect_raises(Exception, "NUL") { command.identifier("a\0b") }
  end

  it "encodes credentials supplied as individual MySQL settings" do
    TestHelpers::TestSetup.with_env({"DATABASE_URL" => nil, "AZU_DATABASE_URL" => nil,
                                     "AZU_DB_ADAPTER" => "mysql", "AZU_DB_PORT" => "3306",
                                     "AZU_DB_USER" => "a@b", "AZU_DB_PASSWORD" => "p:/?#"}) do
      uri = URI.parse(DatabaseProbe.new.server_url)
      uri.scheme.should eq("mysql")
      uri.path.should eq("/mysql")
      uri.user.should eq("a@b")
      uri.password.should eq("p:/?#")
    end
  end
end

private def with_fake_worker(&)
  TestHelpers::TestSetup.with_temp_project("job_launcher") do
    Dir.mkdir_p("bin")
    Dir.mkdir_p("src")
    File.write("src/worker.cr", "")
    File.write("bin/crystal", "#!/bin/sh\nprintf 'child compile failure\\n' >&2\nexit 23\n")
    File.chmod("bin/crystal", 0o700)
    TestHelpers::TestSetup.with_env({"PATH" => "#{Dir.current}/bin:#{ENV["PATH"]}"}) { yield }
  end
end

describe "job subprocess failures" do
  it "returns failure when the worker compiler exits unsuccessfully" do
    with_fake_worker do
      result = AzuCLI::Commands::Jobs::Worker.new.execute
      result.success?.should be_false
    end
  end

  it "returns failure when the UI compiler exits unsuccessfully" do
    with_fake_worker do
      Dir.mkdir_p("lib/joobqui")
      AzuCLI::Commands::Jobs::UI.new.execute.success?.should be_false
    end
  end

  it "returns failure when JoobQUI is missing" do
    with_fake_worker do
      AzuCLI::Commands::Jobs::UI.new.execute.success?.should be_false
    end
  end

  it "rejects unsupported daemon mode" do
    command = AzuCLI::Commands::Jobs::Worker.new
    command.parse_args(["--daemon"])
    command.execute.success?.should be_false
  end
end

describe "connection URL redaction" do
  it "hides Redis passwords with and without an ACL username" do
    AzuCLI::Utils.sanitize_database_url("redis://:secret@localhost:6379/0").should eq("redis://:REDACTED@localhost:6379/0")
    AzuCLI::Utils.sanitize_database_url("redis://worker:p%40ss@localhost:6379").should eq("redis://worker:REDACTED@localhost:6379")
  end
end
