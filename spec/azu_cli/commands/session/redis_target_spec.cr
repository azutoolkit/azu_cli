require "../../../spec_helper"

private alias Target = AzuCLI::Commands::Session::RedisTarget

private def target(url : String) : Target
  Target.parse(url).as(Target)
end

describe AzuCLI::Commands::Session::RedisTarget do
  it "reads host, port, password and database" do
    t = target("redis://app:s%40cret@cache.internal:6380/3")
    {t.host, t.port, t.password, t.database, t.ssl?}.should eq({"cache.internal", 6380, "s@cret", 3, false})
    t.to_s.should eq "redis://cache.internal:6380/3"
  end

  it "defaults the port to 6379 and the database to 0, and keeps rediss" do
    target("rediss://host").to_s.should eq "rediss://host:6379/0"
    target("rediss://host").ssl?.should be_true
    target("redis://host/").to_s.should eq "redis://host:6379/0"
  end

  it "never prints userinfo, whatever its shape" do
    {
      "redis://u:sek:rit@localhost:6379/0" => "redis://localhost:6379/0",
      "redis://sekrit@host"                => "redis://host:6379/0",
      "redis://:sekrit@host:1/2"           => "redis://host:1/2",
      "redis://app:sekrit@127.0.0.1:1/3"   => "redis://127.0.0.1:1/3",
    }.each do |url, printed|
      target(url).to_s.should eq printed
    end
    target("redis://u:sek:rit@localhost").password.should eq "sek:rit"
  end

  it "reads a bracketed IPv6 host and prints it bracketed" do
    t = target("redis://:pw@[::1]:6379/0")
    {t.host, t.port, t.password}.should eq({"::1", 6379, "pw"})
    t.to_s.should eq "redis://[::1]:6379/0"
    target("redis://[2001:db8::7]").to_s.should eq "redis://[2001:db8::7]:6379/0"
  end

  it "refuses what it cannot read, without echoing any of the URL" do
    ["notaurl", "http://host:6379", "redis://host:port", "redis://u:p@sekrit@localhost:6379/0", "redis://sekrit@",
     "redis://sekrit@:6379", "redis://host:0", "redis://host:65536", "redis://host:6379/x", "redis://host:6379/-1",
     "redis://host:6379/99999999999", "redis://[sekrit]:1", "redis://[::1", "redis://[::1]x", "redis://ho st",
     "redis://host/0/1", "redis://host:6379#sekrit"].each do |url|
      problem = Target.parse(url)
      problem.should be_a(String)
      problem.as(String).should_not contain("sekrit")
      problem.as(String).should_not contain(url)
    end
  end

  it "masks the password in a server or socket error" do
    target("redis://:hunter2@host").scrub("AUTH hunter2 failed").should eq "AUTH *** failed"
    target("redis://host").scrub("refused").should eq "refused"
  end

  it "takes a database index up to the Int32 range (the server decides how many it has)" do
    target("redis://host/16").database.should eq 16
  end
end
