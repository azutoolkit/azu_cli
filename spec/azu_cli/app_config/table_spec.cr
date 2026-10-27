require "../../spec_helper"

private SETTINGS = [
  AzuCLI::AppConfig::Setting.new("server", "port", "4000"),
  AzuCLI::AppConfig::Setting.new("database", "url", "sqlite3://./db/blog.db"),
  AzuCLI::AppConfig::Setting.new("server", "host", "127.0.0.1"),
]

describe AzuCLI::AppConfig::Table do
  it "lists the sections in the order they were reported" do
    AzuCLI::AppConfig::Table.new(SETTINGS).sections.should eq ["server", "database"]
  end

  it "filters by section, in any case, and keeps all of them without a section" do
    table = AzuCLI::AppConfig::Table.new(SETTINGS)

    table.filter("Server").settings.map(&.key).should eq ["port", "host"]
    table.filter(nil).settings.size.should eq 3
  end

  it "renders text with a heading per section and the keys aligned" do
    text = AzuCLI::AppConfig::Table.new(SETTINGS).to_text

    text.should eq <<-TEXT
      SERVER
        port  4000
        host  127.0.0.1

      DATABASE
        url   sqlite3://./db/blog.db

      TEXT
  end

  it "renders JSON as an object of sections" do
    json = JSON.parse(AzuCLI::AppConfig::Table.new(SETTINGS).to_json)

    json["server"]["host"].as_s.should eq "127.0.0.1"
    json["database"]["url"].as_s.should eq "sqlite3://./db/blog.db"
  end

  it "says so when nothing matches" do
    AzuCLI::AppConfig::Table.new([] of AzuCLI::AppConfig::Setting).to_text.should eq "No settings match.\n"
  end
end
