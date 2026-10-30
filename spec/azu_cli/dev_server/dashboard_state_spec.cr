require "../../spec_helper"

private alias DS = AzuCLI::DevServer::DashboardState
private alias DU = AzuCLI::UI

describe DS do
  it "deduplicates samples, bounds histories and resets on process restart" do
    state = DS.new
    snapshot = JSON.parse(File.read("spec/fixtures/telemetry/azu-dashboard-v1.json"))
    state.update(snapshot).should be_true
    state.update(snapshot).should be_false
    state.histories["memory"].size.should eq 8
    fresh = JSON.parse({v: 1, at: "next", dashboard: {process: {pid: 2}, series: {memory: Array.new(300, 1.0)}}}.to_json)
    state.update(fresh).should be_true
    state.histories["memory"].size.should eq 120
    state.histories["latency"].should be_empty
  end

  it "keeps disabled modules distinct from modules without samples" do
    state = DS.new
    state.update(JSON.parse(%({"dashboard":{"features":{"cache":"disabled"}}})))
    state.cards.map(&.title).should_not contain "Cache"
    state.cards.find { |card| card.title == "Database" }.should_not be_nil
    state.status("database").should eq "unavailable"
  end

  it "pages cards and renders every destination at the supported sizes" do
    workspace = AzuCLI::DevServer::Hud.new("blog", "4000", "development", "watching")
    screen = AzuCLI::DevServer::MissionControl.new(workspace, "blog", true)
    screen.update(AzuCLI::DevServer::Events::Telemetry.new(JSON.parse(File.read("spec/fixtures/telemetry/azu-dashboard-v1.json"))))
    [{200, 60}, {140, 45}, {100, 30}, {80, 24}].each do |width, height|
      {"Overview", "Errors", "Tracing", "Logs", "Profiler", "Sessions", "Database", "Cache", "JoobQ", "Queues & Activity", "Components", "Mailers"}.each do |name|
        screen.update(DU::Key.new(DU::KeyCode::CtrlP))
        name.each_char { |char| screen.update(DU::Key.new(DU::KeyCode::Char, char)) }
        screen.update(DU::Key.new(DU::KeyCode::Enter))
        frame = DU::Frame.new(width, height, DU::StyleTable.new(DU::Theme.new(DU::ColorDepth::TrueColor)))
        screen.view(frame)
        frame.to_text.lines.size.should eq height
        frame.to_text.should_not contain '\e'
      end
    end
  end
end
