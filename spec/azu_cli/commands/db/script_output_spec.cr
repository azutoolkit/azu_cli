require "../../../spec_helper"

private alias ScriptOutput = AzuCLI::Commands::Database::ScriptOutput

private MIGRATE_OUTPUT = <<-OUT.lines
  2026-10-27T17:59:41.010747Z   WARN - No JoobQ configuration file found, using default configuration
  2026-10-27T17:59:41.011460Z  DEBUG - CQL::Development: Creating table posts
  ┌────────┬──────────────────────┬────────────────┐
  │ Status │ Migration            │        Version │
  ├────────┼──────────────────────┼────────────────┤
  │   ✔    │ CreatePosts │ 20261027155725 │
  │   ✔    │ AddTags │ 20261027160000 │
  └────────┴──────────────────────┴────────────────┘
  Seeded 3 posts
  OUT

describe AzuCLI::Commands::Database::ScriptOutput do
  it "sorts a migration script's output into migrations, warnings and printed lines" do
    output = ScriptOutput.new(MIGRATE_OUTPUT)
    output.migrations.should eq [{true, "CreatePosts", "20261027155725"}, {true, "AddTags", "20261027160000"}]
    output.warnings.should eq ["No JoobQ configuration file found, using default configuration"]
    output.printed.should eq ["Seeded 3 posts"]
    output.summary.should eq "applied CreatePosts, AddTags"
  end

  it "says what was rolled back, and done when CQL listed nothing" do
    ScriptOutput.new(["│   ✗    │ CreatePosts │ 20261027155725 │"]).summary.should eq "rolled back CreatePosts"
    ScriptOutput.new(["hello"]).summary.should eq "done"
  end

  it "shows a log line's message without its time and level while the task runs" do
    ScriptOutput.note("2026-10-27T17:59:41.011460Z  DEBUG - Creating table posts").should eq "Creating table posts"
    ScriptOutput.note("  Compiling  ").should eq "Compiling"
  end
end
