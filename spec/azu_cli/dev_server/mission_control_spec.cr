require "../../spec_helper"

private alias MC = AzuCLI::DevServer::MissionControl
private alias MCUI = AzuCLI::UI
private alias MCE = AzuCLI::DevServer::Events

private def mission
  MC.new(AzuCLI::DevServer::Hud.new("store", "4000", "development", "watching src"), "store", true)
end

private def mission_frame(screen, width = 136, height = 40)
  frame = MCUI::Frame.new(width, height, MCUI::StyleTable.new(MCUI::Theme.new(MCUI::ColorDepth::TrueColor)))
  screen.view(frame)
  frame
end

describe MC do
  it "uses unique shortcuts in sidebar order and cycles sections without stealing search text" do
    screen = mission
    MC::SHORTCUTS.values.uniq.size.should eq MC::SHORTCUTS.size
    expected = {MC::Tab::Dashboard, MC::Tab::Errors, MC::Tab::Tracing, MC::Tab::Logs,
                MC::Tab::Profiler, MC::Tab::Auth, MC::Tab::Database, MC::Tab::Cache,
                MC::Tab::JoobQ, MC::Tab::Jobs, MC::Tab::Components, MC::Tab::Mailers}
    "1234567890cm".each_char.with_index do |char, index|
      screen.update(MCUI::Key.new(MCUI::KeyCode::Char, char))
      screen.tab.should eq expected[index]
    end
    screen.update(MCUI::Key.new(MCUI::KeyCode::AltRight))
    screen.tab.should eq MC::Tab::Dashboard
    screen.update(MCUI::Key.new(MCUI::KeyCode::AltLeft))
    screen.tab.should eq MC::Tab::Mailers
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '/'))
    "123?cm".each_char { |char| screen.update(MCUI::Key.new(MCUI::KeyCode::Char, char)) }
    screen.query.should eq "123?cm"
    screen.tab.should eq MC::Tab::Mailers
    screen.update(MCUI::Key.new(MCUI::KeyCode::Esc))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 'n'))
    screen.tab.should eq MC::Tab::SQL
    screen.query.should eq "N+1"
  end

  it "keeps embedded job navigation separate from global numbers and makes help dismissible" do
    screen = mission
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '9'))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, ']'))
    mission_frame(screen).to_text.should contain "[ / ] Workflows"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '?'))
    mission_frame(screen).to_text.should contain "Keyboard hints"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Esc))
    mission_frame(screen).to_text.should_not contain "Keyboard hints"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, ']'))
    mission_frame(screen).to_text.should contain "[ / ] DLQ"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '1'))
    screen.tab.should eq MC::Tab::Dashboard
  end

  it "lists Develop tools in order and reaches every screen on compact and wide terminals" do
    screen = mission
    expected = {MC::Tab::Commands, MC::Tab::Console, MC::Tab::Build, MC::Tab::Config,
                MC::Tab::Generators, MC::Tab::Serve, MC::Tab::Server, MC::Tab::Doctor,
                MC::Tab::Components, MC::Tab::Mailers}
    MC::NAVIGATION.to_a.last(10).should eq expected.to_a
    [{200, 60}, {140, 45}, {100, 30}, {80, 24}].each do |width, height|
      screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 'x'))
      expected.each_with_index do |section, index|
        screen.tab.should eq section
        frame = mission_frame(screen, width, height)
        frame.to_text.should contain "Develop"
        frame.to_text.lines.size.should eq height
        screen.update(MCUI::Key.new(MCUI::KeyCode::AltRight))
      end
      screen.tab.should eq MC::Tab::Dashboard
    end
  end

  it "runs dedicated diagnostics and routes through the control runner and reuses the server lifecycle" do
    called = [] of String
    commands = [AzuCLI::DevServer::Control::Command.new("doctor", "Health", ["doctor"]),
                AzuCLI::DevServer::Control::Command.new("routes", "App", ["routes"])]
    workspace = AzuCLI::DevServer::Hud.new("store", "4000", "development", "", commands: commands,
      on_rebuild: -> { called << "restart"; nil }, on_control: ->(command : AzuCLI::DevServer::Control::Command) { called << command.id; nil })
    screen = MC.new(workspace, "store")
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 'D'))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    called.should eq ["doctor"]
    screen.update(MCE::ControlFinished.new("doctor", 0, "9 ok, 0 warnings, 0 failures", 0.1))
    mission_frame(screen).to_text.should contain "9 ok, 0 warnings, 0 failures"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 'a'))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    screen.update(MCE::ControlFinished.new("routes", 0, "GET /products Products::Index", 0.1))
    mission_frame(screen).to_text.should contain "GET /products Products::Index"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 'S'))
    mission_frame(screen).to_text.should contain "Server output"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    called.should eq ["doctor", "routes", "restart"]
    60.times { |i| screen.update(MCE::LogLine.new("serve line #{i}")) }
    mission_frame(screen, 80, 24).to_text.should contain "serve line 59"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Home))
    mission_frame(screen, 80, 24).to_text.should contain "serve line 0"
  end

  it "opens the generator editor from Develop and executes only after review" do
    submitted = [] of Array(String)
    screen = MC.new(AzuCLI::DevServer::Hud.new("store", "4000", "development", ""), "store",
      on_command: ->(command : AzuCLI::DevServer::Control::Command) { submitted << command.args; true })
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 'g'))
    screen.tab.should eq MC::Tab::Generators
    mission_frame(screen).to_text.should contain "Generators"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    "model Product name:string".each_char { |char| screen.update(MCUI::Key.new(MCUI::KeyCode::Char, char)) }
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    submitted.should be_empty
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 'y'))
    submitted.should eq [["generate", "model", "Product", "name:string"]]
  end

  it "renders the web dashboard hierarchy and opens a focused card" do
    screen = mission
    screen.update(MCE::Telemetry.new(JSON.parse(File.read("spec/fixtures/telemetry/azu-dashboard-v1.json"))))
    text = mission_frame(screen, 200, 60).to_text
    ["Overview", "System health", "All systems nominal", "Uptime", "Memory (RSS)", "Latency", "Active routes", "Traffic", "Errors", "Cache", "Database", "Components", "Runtime"].each { |label| text.should contain label }
    screen.update(MCUI::Key.new(MCUI::KeyCode::Tab))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Tab))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    screen.tab.should eq MC::Tab::Tracing
  end

  it "aligns five cards on each row above highlighted log and query feeds" do
    screen = mission
    screen.update(MCE::Telemetry.new(JSON.parse(File.read("spec/fixtures/telemetry/azu-dashboard-v1.json"))))
    screen.update(MCE::LogLine.new("INFO newest overview event"))
    [{200, 60}, {140, 45}].each do |width, height|
      rows = mission_frame(screen, width, height).to_text.lines.map { |line| line.chars.skip(22).join }
      first = rows.find { |line| line.includes?("Memory (RSS)") }.not_nil!
      second = rows.find { |line| line.includes?("Cache") && line.includes?("Runtime") }.not_nil!
      {"Uptime", "Memory (RSS)", "Latency", "Active routes", "Traffic"}.zip({"Errors", "Cache", "Database", "Components", "Runtime"}).each do |top, bottom|
        first.index(top).should eq second.index(bottom)
      end
      feeds = rows.index { |line| line.includes?("Latest logs") && line.includes?("Latest queries") }.not_nil!
      feeds.should be > rows.index(second).not_nil!
      rows.join.should contain "newest overview event"
      rows.join.should contain "SELECT"
    end
    10.times { screen.update(MCUI::Key.new(MCUI::KeyCode::Tab)) }
    screen.update(MCUI::Key.new(MCUI::KeyCode::Tab))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    screen.tab.should eq MC::Tab::SQL
  end

  it "pages to both feeds on a compact terminal and scrolls or filters recent logs" do
    screen = mission
    screen.update(MCE::Telemetry.new(JSON.parse(File.read("spec/fixtures/telemetry/azu-dashboard-v1.json"))))
    30.times { |i| screen.update(MCE::LogLine.new("INFO overview event #{i}")) }
    10.times do
      break if mission_frame(screen, 80, 24).to_text.includes?("Latest logs")
      screen.update(MCUI::Key.new(MCUI::KeyCode::Char, ']'))
    end
    text = mission_frame(screen, 80, 24).to_text
    text.should contain "Latest logs"
    text.should contain "Latest queries"
    text.should contain "overview event 29"
    screen.update(MCUI::Key.new(MCUI::KeyCode::End))
    mission_frame(screen, 80, 24).to_text.should contain "overview event 0"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 'f'))
    mission_frame(screen, 80, 24).to_text.should contain "overview event 29"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '/'))
    "missing".each_char { |char| screen.update(MCUI::Key.new(MCUI::KeyCode::Char, char)) }
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    mission_frame(screen, 80, 24).to_text.should contain "No matching entries"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Esc))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    screen.tab.should eq MC::Tab::Logs
  end

  it "offers a bottom-right launcher for SQL, N+1 and schema without a second screen" do
    screen = mission
    screen.update(MCUI::Key.new(MCUI::KeyCode::CtrlP))
    "sql".each_char { |char| screen.update(MCUI::Key.new(MCUI::KeyCode::Char, char)) }
    frame = mission_frame(screen, 156, 46)
    rows = frame.to_text.lines
    row = rows.index { |line| line.includes?("Navigate") && line.includes?("╭") }.not_nil!
    row.should be > 23
    rows[row].index("Navigate").not_nil!.should be > 78
    frame.to_text.should contain "Inspect N+1 SQL queries"
    frame.to_text.should contain "Open SQL schema explorer"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Down))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    screen.tab.should eq MC::Tab::SQL
    screen.query.should eq "N+1"
  end

  it "keeps the overview, launcher and every section bounded at small and large sizes" do
    screen = mission
    screen.update(MCE::LogLine.new("\e[2JINFO " + "long log " * 100))
    [{48, 14}, {80, 24}, {104, 32}, {156, 46}].each do |(width, height)|
      {'1', 's', '6', 'i'}.each do |tab|
        screen.update(MCUI::Key.new(MCUI::KeyCode::Char, tab))
        2.times do
          text = mission_frame(screen, width, height).to_text
          text.should_not contain '\e'
          text.lines.size.should eq height
          text.lines.each { |line| line.size.should be <= width }
          screen.update(MCUI::Key.new(MCUI::KeyCode::CtrlP))
        end
      end
    end
  end

  it "keeps console input and all development panels inside the new workspace" do
    workspace = AzuCLI::DevServer::Hud.new("store", "4000", "development", "watching src")
    screen = MC.new(workspace, "store", true)
    {'d', '2', 'x', '`', 'v'}.each do |shortcut|
      screen.update(MCUI::Key.new(MCUI::KeyCode::CtrlP))
      # Select through the palette so console text cannot intercept navigation.
      label = {'d' => "Build", '2' => "Errors", 'x' => "Commands", '`' => "Console", 'v' => "Config"}[shortcut]
      label.each_char { |char| screen.update(MCUI::Key.new(MCUI::KeyCode::Char, char)) }
      screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
      screen.tab.to_s.should eq label
      text = mission_frame(screen).to_text
      text.should contain "OBSERVE"
      text.should contain "store / #{label == "Errors" ? "Observe" : "Develop"} / #{label}"
      text.should_not contain "[1] Overview"
      text.should_not contain "Esc mission control"
    end
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '`'))
    "1 + 2".each_char { |char| screen.update(MCUI::Key.new(MCUI::KeyCode::Char, char)) }
    workspace.editor.text.should eq "1 + 2"
    screen.update(MCUI::Key.new(MCUI::KeyCode::CtrlP))
    "SQL".each_char { |char| screen.update(MCUI::Key.new(MCUI::KeyCode::Char, char)) }
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    screen.tab.should eq MC::Tab::SQL
    workspace.editor.text.should eq "1 + 2"
  end

  it "continues to ingest telemetry while console is visible" do
    screen = mission
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '`'))
    screen.update(MCE::Telemetry.new(JSON.parse(%({"v":1,"sql":{"slowest":[{"sql":"SELECT arrived_in_console","ms":1.0}]}}))))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Esc))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 's'))
    mission_frame(screen).to_text.should contain "arrived_in_console"
  end

  it "does not carry command confirmation to a different panel" do
    requested = [] of String
    workspace = AzuCLI::DevServer::Hud.new("store", "4000", "development", "", commands: [AzuCLI::DevServer::Control::Command.new("db:migrate", "Database", ["db:migrate"], confirm: true)],
      on_control: ->(command : AzuCLI::DevServer::Control::Command) { requested << command.id; nil })
    screen = MC.new(workspace, "store")
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 'x'))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    workspace.confirming.should_not be_nil
    screen.update(MCUI::Key.new(MCUI::KeyCode::CtrlP))
    "Console".each_char { |char| screen.update(MCUI::Key.new(MCUI::KeyCode::Char, char)) }
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 'y'))
    workspace.editor.text.should eq "y"
    workspace.confirming.should be_nil
    requested.should be_empty
  end

  it "renders the older Azu SQL payload over the telemetry socket in the new tab and overview" do
    # Azu v1's original Telemetry.sql emits slowest, pool and n_plus_one,
    # without recent, ids, timestamps or caller information on query rows.
    payload = JSON.parse(%({"v":1,"sql":{"total":1,"avg_ms":2.5,"slow":0,"pool":null,
      "n_plus_one":[],"slowest":[{"sql":"SELECT name FROM products","ms":2.5}]}}))
    screen = mission
    received = Channel(JSON::Any).new(1)
    server = AzuCLI::DevServer::TelemetryServer.new
    begin
      server.start { |data| received.send(data) }
      UNIXSocket.open(server.path) { |socket| socket.puts(payload.to_json); socket.flush }
      data = select
      when snapshot = received.receive
        snapshot
      when timeout(2.seconds)
        fail "SQL snapshot did not reach the HUD"
      end
      screen.update(MCE::Telemetry.new(data))
      mission_frame(screen).to_text.should contain "Dashboard telemetry unavailable"
      screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 's'))
      text = mission_frame(screen).to_text
      text.should contain "SELECT name FROM products"
      text.should contain "slowest sample"
      text.should contain "2.5 ms"
    ensure
      server.stop
    end
  end

  it "prefers recent SQL, preserves origin and N+1 details, and clears obsolete samples" do
    screen = mission
    screen.update(MCE::Telemetry.new(JSON.parse(%({"v":1,"sql":{
      "recent":[{"id":7,"sql":"SELECT current_name FROM products","ms":1.2,"caller":"product.cr:8"}],
      "slowest":[{"sql":"SELECT obsolete_name FROM products","ms":9}],
      "n_plus_one":[{"sql":"SELECT related FROM products","count":5,"suggestion":"Preload products"}]}}))))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 's'))
    text = mission_frame(screen).to_text
    text.should contain "SELECT current_name"
    text.should contain "product.cr:8"
    text.should contain "N+1 ×5"
    text.should_not contain "obsolete_name"
    screen.update(MCUI::Key.new(MCUI::KeyCode::End))
    mission_frame(screen).to_text.should contain "Preload products"
    screen.update(MCE::Telemetry.new(JSON.parse(%({"v":1,"sql":{"recent":[],"slowest":[],"n_plus_one":[]}}))))
    mission_frame(screen).to_text.should contain "No SQL samples"
    mission_frame(screen).to_text.should_not contain "current_name"
  end

  it "searches navigation and opens SQL without treating typed q as quit" do
    screen = mission
    screen.update(MCUI::Input.parse("\u0010").first)
    screen.menu_open?.should be_true
    "sql".each_char { |char| screen.update(MCUI::Key.new(MCUI::KeyCode::Char, char)).should eq MCUI::Action::Redraw }
    mission_frame(screen).to_text.should contain "Open SQL"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    screen.tab.should eq MC::Tab::SQL
    screen.menu_open?.should be_false
  end

  it "keeps Unicode and control bytes inside a bounded frame at every breakpoint" do
    screen = mission
    screen.update(MCE::LogLine.new("\e[2J14:32:08 INFO GET /products 200 4.8ms 漢字"))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '4'))
    [{20, 8}, {48, 14}, {80, 24}, {104, 32}, {136, 40}].each do |(width, height)|
      frame = mission_frame(screen, width, height)
      text = frame.to_text
      text.should_not contain '\e'
      text.split('\n').size.should eq height
      text.lines.each { |line| line.size.should be <= width }
    end
  end

  it "caps log retention and restores the mission shell after opening console" do
    screen = mission
    220.times { |i| screen.update(MCE::LogLine.new("INFO request-#{i}")) }
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '4'))
    text = mission_frame(screen).to_text
    text.should contain "request-219"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '`'))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Esc))
    screen.tab.should eq MC::Tab::Logs
    mission_frame(screen).to_text.should contain "request-219"
  end

  it "degrades missing or malformed optional telemetry without inventing metrics" do
    screen = mission
    screen.update(MCE::Telemetry.new(JSON.parse(%({"requests":null,"sql":false,"auth":null,"database":1}))))
    mission_frame(screen).to_text.should contain "Dashboard telemetry unavailable"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 'u'))
    mission_frame(screen).to_text.should contain "No adapter data"
  end

  it "matches subsequences without evaluating regular expressions" do
    MC.matches?("GET /products", "gprd").should be_true
    MC.matches?("GET /products", "[.*").should be_false
  end
end

describe MCUI::Highlight do
  it "preserves SQL text while distinguishing keywords, escaped strings and parameters" do
    source = "SELECT name FROM users WHERE label = 'it''s fine' AND id = $1 -- note"
    tokens = MCUI::Highlight.sql(source)
    tokens.map(&.text).join.should eq source
    tokens.find(&.text.==("SELECT")).not_nil!.style.fg.should eq MCUI::Token::Pink
    tokens.find(&.text.==("'it''s fine'")).not_nil!.style.fg.should eq MCUI::Token::Green
    tokens.find(&.text.==("$1")).not_nil!.style.fg.should eq MCUI::Token::Amber
  end

  it "preserves log whitespace and colors status, severity and latency separately" do
    source = "14:32:08  WARN GET /products 200 4.8ms"
    tokens = MCUI::Highlight.log(source)
    tokens.map(&.text).join.should eq source
    tokens.find(&.text.==("WARN")).not_nil!.style.fg.should eq MCUI::Token::Amber
    tokens.find(&.text.==("200")).not_nil!.style.fg.should eq MCUI::Token::Green
    tokens.find(&.text.==("4.8ms")).not_nil!.style.fg.should eq MCUI::Token::Cyan
  end
end
