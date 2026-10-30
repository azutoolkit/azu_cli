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
  it "renders the reference overview and navigates its log, SQL and queue panes" do
    screen = mission
    screen.update(MCE::LogLine.new("14:32:08 INFO GET /products 200 4.8ms"))
    screen.update(MCE::Telemetry.new(JSON.parse(%({"v":1,"requests":{"rps":12},"sql":{"recent":[
      {"id":"q1","sql":"SELECT 'FROM safe literal' AS value FROM products","ms":2.3},
      {"id":"q2","sql":"SELECT second_query FROM products","ms":1.1}]}}))))
    screen.update(MCE::JobsSample.new([MCE::Queue.new("default", 24_i64, 8_i64, 0_i64)]))
    text = mission_frame(screen, 156, 46).to_text
    ["Overview", "Live logs", "SQL · selected query", "CQL pool", "Queues & activity", "Share of waiting jobs", "FROM safe literal"].each do |label|
      text.should contain label
    end
    text.should_not contain "SAMPLE DATA"
    text.should_not contain "sessions"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Tab))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Down))
    mission_frame(screen, 156, 46).to_text.should contain "SELECT second_query"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
    screen.tab.should eq MC::Tab::SQL
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
      {'1', '5', '6', 'm'}.each do |tab|
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
    {'d', 'e', '?', 'c', 'v'}.each do |shortcut|
      screen.update(MCUI::Key.new(MCUI::KeyCode::CtrlP))
      # Select through the palette so console text cannot intercept navigation.
      label = {'d' => "Build", 'e' => "Errors", '?' => "Commands", 'c' => "Console", 'v' => "Config"}[shortcut]
      label.each_char { |char| screen.update(MCUI::Key.new(MCUI::KeyCode::Char, char)) }
      screen.update(MCUI::Key.new(MCUI::KeyCode::Enter))
      screen.tab.to_s.should eq label
      text = mission_frame(screen).to_text
      text.should contain "OBSERVE"
      text.should contain "store / Develop / #{label}"
      text.should_not contain "[1] Overview"
      text.should_not contain "Esc mission control"
    end
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 'c'))
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
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 'c'))
    screen.update(MCE::Telemetry.new(JSON.parse(%({"v":1,"sql":{"slowest":[{"sql":"SELECT arrived_in_console","ms":1.0}]}}))))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Esc))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '5'))
    mission_frame(screen).to_text.should contain "arrived_in_console"
  end

  it "does not carry command confirmation to a different panel" do
    requested = [] of String
    workspace = AzuCLI::DevServer::Hud.new("store", "4000", "development", "", commands: [AzuCLI::DevServer::Control::Command.new("db:migrate", "Database", ["db:migrate"], confirm: true)],
      on_control: ->(command : AzuCLI::DevServer::Control::Command) { requested << command.id; nil })
    screen = MC.new(workspace, "store")
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '?'))
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
      mission_frame(screen).to_text.should contain "SELECT name"
      screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '5'))
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
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '5'))
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
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '7'))
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
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '7'))
    text = mission_frame(screen).to_text
    text.should contain "request-219"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, 'c'))
    screen.update(MCUI::Key.new(MCUI::KeyCode::Esc))
    screen.tab.should eq MC::Tab::Logs
    mission_frame(screen).to_text.should contain "request-219"
  end

  it "degrades missing or malformed optional telemetry without inventing metrics" do
    screen = mission
    screen.update(MCE::Telemetry.new(JSON.parse(%({"requests":null,"sql":false,"auth":null,"database":1}))))
    mission_frame(screen).to_text.should contain "HTTP only"
    screen.update(MCUI::Key.new(MCUI::KeyCode::Char, '4'))
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
