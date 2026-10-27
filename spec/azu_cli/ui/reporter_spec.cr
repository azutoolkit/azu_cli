require "../../spec_helper"

private alias TUI = AzuCLI::UI

describe AzuCLI::UI::Reporter do
  it "chooses plain on a pipe, json and plain on request, and never rich without a terminal" do
    TUI::Reporter.build(nil, IO::Memory.new).should be_a TUI::Plain
    TUI::Reporter.build("json", IO::Memory.new).should be_a TUI::Json
    TUI::Reporter.build(nil, IO::Memory.new, env: {"AZU_UI" => "json"}).should be_a TUI::Json
    TUI::Reporter.build(nil, IO::Memory.new, TUI::Terminal.fake(depth: TUI::ColorDepth::Basic16)).should be_a TUI::Rich
    TUI::Reporter.build(nil, IO::Memory.new, TUI::Terminal.fake(depth: TUI::ColorDepth::Basic16), env: {"CI" => "true"}).should be_a TUI::Plain
    TUI::Reporter.build(nil, IO::Memory.new, TUI::Terminal.fake(depth: TUI::ColorDepth::None)).should be_a TUI::Plain
  end

  it "plain: one line per finished task, failures marked, no escape codes" do
    io = IO::Memory.new
    reporter = TUI::Plain.new(io)
    reporter.task("files") { |task| task.detail = "41 written" }
    expect_raises(Exception, "boom") { reporter.task("shards") { raise "boom" } }
    reporter.task("git") { |task| task.skip("--no-git") }
    lines = io.to_s.lines
    lines[0].should start_with "[ok] files        41 written"
    lines[1].should start_with "[!!] shards       boom"
    lines[2].should start_with "[--] git          --no-git"
    io.to_s.should_not contain "\e"
  end

  it "json: start, progress and done events" do
    io = IO::Memory.new
    reporter = TUI::Json.new(io)
    reporter.task("shards", "install") { |task| task.progress(3, 19) }
    events = io.to_s.lines.map { |line| JSON.parse(line) }
    events.map(&.["event"].as_s).should eq ["task.start", "task.progress", "task.done"]
    events[1]["done"].as_i.should eq 3
    events[2]["ok"].as_bool.should be_true
    events.all? { |event| event["v"].as_i == 1 }.should be_true
  end

  it "rich: draws the group as a card that ends with every task's mark and time" do
    io = IO::Memory.new
    reporter = TUI::Rich.new(TUI::Terminal.fake(io, columns: 60))
    reporter.group("Compilation Progress") do
      reporter.task("Files") { |task| task.detail = "41 written" }
      reporter.task("Git") { |task| task.fail("not a repository") }
    end
    final = io.to_s.split("\e[J").last
    final.should contain "╭─ Compilation Progress"
    final.should contain "│ ✔ Files"
    final.should contain "41 written"
    final.should contain "│ ✖ Git"
    final.should contain "✖ 1 failed"
  end

  it "plain and json show panels as text" do
    io = IO::Memory.new
    TUI::Plain.new(io).panel("blog is ready", [[TUI::Seg["cd blog"]]], "✔")
    io.to_s.should eq "blog is ready · ✔\n  cd blog\n"
  end
end

describe "AzuCLI.json_output?" do
  it "is on for --ui json in either spelling" do
    AzuCLI.json_output?(["new", "blog", "--ui", "json"]).should be_true
    AzuCLI.json_output?(["new", "blog", "--ui=json"]).should be_true
    AzuCLI.json_output?(["new", "blog", "--ui", "plain"]).should be_false
    AzuCLI.json_output?(["new", "json"]).should be_false
  end
end
