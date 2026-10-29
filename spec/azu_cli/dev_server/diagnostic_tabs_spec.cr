require "../../spec_helper"

private alias DUI = AzuCLI::UI

private def diagnostic_frame(screen, width, height)
  frame = DUI::Frame.new(width, height, DUI::StyleTable.new(DUI::Theme.new(DUI::ColorDepth::None)))
  screen.view(frame)
  frame.to_text
end

describe "diagnostic tabs" do
  it "shows exception details and keeps every frame within a resized terminal" do
    screen = AzuCLI::DevServer::Hud.new("app", "4000", "development", "watching")
    screen.update(AzuCLI::DevServer::Events::Telemetry.new(JSON.parse({v: 1, errors: [
      {id: "e1", at: "12:00", route: "/login", class: "ArgumentError", message: "bad request",
       problem: {status: 400, title: "Bad Request"}, params: {password: "[FILTERED]"}, frames: Array.new(80) { |i| "file.cr:#{i} " + "trace" * 50 }},
    ]}.to_json)))
    screen.update(DUI::Key.new(DUI::KeyCode::Char, '9'))
    diagnostic_frame(screen, 120, 30).should contain "RFC 7807"
    { {120, 30}, {60, 16}, {20, 5}, {1, 1} }.each do |width, height|
      text = diagnostic_frame(screen, width, height)
      text.split('\n').size.should eq height
      text.lines.each { |line| line.size.should be <= width }
    end
    screen.update(DUI::Key.new(DUI::KeyCode::Tab))
    screen.update(DUI::Key.new(DUI::KeyCode::End))
    diagnostic_frame(screen, 120, 30).should contain "trace"
  end

  it "accepts old and malformed optional diagnostics fields" do
    errors = AzuCLI::DevServer::ErrorsTab.new
    sql = AzuCLI::DevServer::SQLTab.new
    ["{}", %({"errors":3,"sql":[]}), %({"errors":[null,4],"sql":{"recent":[null]}})].each do |json|
      errors.update(JSON.parse(json))
      sql.update(JSON.parse(json))
      frame = DUI::Frame.new(80, 20, DUI::StyleTable.new(DUI::Theme.new(DUI::ColorDepth::None)))
      sql.draw(frame, frame.area)
      errors.draw(frame, frame.area)
    end
  end

  it "displays query origin, latency, pool checkouts and N+1 details" do
    tab = AzuCLI::DevServer::SQLTab.new
    tab.update(JSON.parse({sql: {total: 2, avg_ms: 1.5, pool: {in_flight: 2, max: 10, idle: 1},
                                 recent: [{id: 1, sql: "SELECT ?", ms: 1.5, caller: "post.cr:4"}],
                                 n_plus_one: [{sql: "SELECT ?", count: 5, suggestion: "Preload posts"}],
                                 histogram: [{label: "1–5", count: 2, bar: 12}]}}.to_json))
    frame = DUI::Frame.new(120, 30, DUI::StyleTable.new(DUI::Theme.new(DUI::ColorDepth::None)))
    tab.draw(frame, frame.area)
    frame.to_text.should contain "checkouts 2/10"
    frame.to_text.should contain "post.cr:4"
    frame.to_text.should contain "N+1"
    tab.inspector.items.size.should eq 2
    tab.draw(frame, frame.area)
    tab.inspector.items.size.should eq 2
  end
end

describe AzuCLI::DevServer::TelemetryServer do
  it "rejects malformed legacy overview shapes before rendering" do
    [%(null), %({"v":1,"sql":4}), %({"v":1,"requests":{"recent":[1]}}), %({"v":1,"sql":{"pool":[]}})].each do |json|
      AzuCLI::DevServer::TelemetryServer.valid_snapshot?(JSON.parse(json)).should be_false
    end
    AzuCLI::DevServer::TelemetryServer.valid_snapshot?(JSON.parse(%({"v":1,"requests":null,"sql":{"recent":[],"pool":null}}))).should be_true
  end
end
