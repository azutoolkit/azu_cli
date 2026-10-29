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
    mission_frame(screen).to_text.should contain "adapter needed"
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
