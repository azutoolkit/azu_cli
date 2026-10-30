require "../../spec_helper"

private alias SharedUI = AzuCLI::UI
private alias SharedEvents = AzuCLI::DevServer::Events

private def shared_screen
  AzuCLI::DevServer::MissionControl.new(AzuCLI::DevServer::Hud.new("store", "4000", "development", ""), "store", true)
end

private def shared_text(screen, width = 156, height = 46)
  frame = SharedUI::Frame.new(width, height, SharedUI::StyleTable.new(SharedUI::Theme.new(SharedUI::ColorDepth::TrueColor)))
  screen.view(frame)
  frame.to_text
end

describe "workspace keyboard hints" do
  it "shows shortcut labels and a scrollable help panel without stealing text input" do
    screen = shared_screen
    shared_text(screen).should contain "[D]"
    shared_text(screen).should contain "h help"
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::Char, 'h'))
    shared_text(screen).should contain "Keyboard hints"
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::End))
    shared_text(screen).should contain "LOCAL COMMANDS"
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::Esc))
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::Char, '/'))
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::Char, 'h'))
    screen.query.should eq "h"
    shared_text(screen).should_not contain "Keyboard hints"
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::Esc))
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::Char, 'c'))
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::Char, 'h'))
    shared_text(screen).should_not contain "Keyboard hints"
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::CtrlP))
    "hints".each_char { |char| screen.update(SharedUI::Key.new(SharedUI::KeyCode::Char, char)) }
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::Enter))
    shared_text(screen).should contain "Keyboard hints"
    shared_text(screen, 48, 14).lines.size.should eq 14
  end

  it "omits local mutations from production hints" do
    screen = AzuCLI::DevServer::MissionControl.new(AzuCLI::DevServer::Hud.new("prod", "", "production", ""), "prod", read_only: true)
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::Char, 'h'))
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::End))
    text = shared_text(screen)
    text.should_not contain "LOCAL COMMANDS"
    text.should_not contain "generator"
    text.should_not contain "Rebuild application"
  end
end

describe AzuCLI::DevServer::SharedTelemetry do
  it "renders SQL captured by the real azu/cql bridge, including unbounded crystal-db pools" do
    payload = File.read(ENV["AZU_CQL_SNAPSHOT"]? || File.join(__DIR__, "../../fixtures/telemetry/azu-cql-v1.json"))
    payload.should_not contain "private-bound-value"
    data = JSON.parse(payload)
    AzuCLI::DevServer::TelemetryServer.valid_snapshot?(data).should be_true
    data["sql"]["total"].as_i.should eq 6
    data["sql"]["n_plus_one"].as_a.size.should eq 1
    screen = shared_screen
    screen.update(SharedEvents::Telemetry.new(data))
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::Char, '5'))
    text = shared_text(screen)
    text.should contain "export_azu_cql_telemetry.cr"
    text.should contain "N+1"
    text.should contain "unlimited" if data["sql"]["pool"]["max"].as_i == 0
    AzuCLI::DevServer::SQLTab.pool_capacity(JSON.parse(%({"max":0}))).should eq "unlimited"
    AzuCLI::DevServer::SQLTab.pool_capacity(JSON.parse(%({"max":20}))).should eq "20"
    AzuCLI::DevServer::SQLTab.pool_capacity(nil).should eq "—"
  end

  it "uses shared requests without stdout, permits source switching, and exposes supplied runtime metrics" do
    screen = shared_screen
    screen.update(SharedEvents::Telemetry.new(JSON.parse(%({"v":1,"requests":{"recent":[{"at":"12:00:00","method":"GET","path":"/shared-request","status":500,"ms":2.5}]},"runtime":{"heap_bytes":1048576,"free_bytes":1024}}))))
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::Char, '7'))
    text = shared_text(screen)
    text.should contain "Logs · azu/dev requests"
    text.should contain "ERROR HTTP GET /shared-request 500 2.5ms"
    text.should contain "heap 1.0 MB"
    screen.update(SharedEvents::LogLine.new("INFO application-output"))
    shared_text(screen).should contain "application-output"
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::Char, 't'))
    shared_text(screen).should contain "/shared-request"
    shared_text(screen).should_not contain "application-output"
    screen.update(SharedEvents::Telemetry.new(JSON.parse(%({"v":1,"stream":"auth","auth":{"recent":[]}}))))
    shared_text(screen).should contain "/shared-request"
    screen.update(SharedUI::Key.new(SharedUI::KeyCode::Char, 't'))
    shared_text(screen).should contain "application-output"
  end

  it "consumes the real Azu master exporter through the private telemetry socket" do
    file = ENV["AZU_SHARED_SNAPSHOT"]? || File.join(__DIR__, "../../fixtures/telemetry/azu-dev-v1.json")
    payload = File.read(file)
    payload.should_not contain "private-request-value"
    payload.should_not contain "private-bound-value"
    payload.should_not contain "private-error-value"
    received = Channel(JSON::Any).new(1)
    server = AzuCLI::DevServer::TelemetryServer.new
    screen = shared_screen
    begin
      server.start { |data| received.send(data) }
      UNIXSocket.open(server.path) { |socket| socket.puts payload; socket.flush }
      select
      when data = received.receive
        screen.update(SharedEvents::Telemetry.new(data))
      when timeout(2.seconds)
        fail "Azu::Dev::Telemetry v1 snapshot did not reach the HUD"
      end
      shared_text(screen).should contain "azu/dev v1"
      shared_text(screen).should contain "heap"
      screen.update(SharedUI::Key.new(SharedUI::KeyCode::Char, '7'))
      shared_text(screen).should contain "POST /login"
      screen.update(SharedUI::Key.new(SharedUI::KeyCode::Char, '5'))
      text = shared_text(screen)
      text.should contain "product_repository.cr:41"
      text.should contain "Latency histogram"
      text.should contain "N+1"
      screen.update(SharedUI::Key.new(SharedUI::KeyCode::Char, 'e'))
      screen.update(SharedUI::Key.new(SharedUI::KeyCode::Tab))
      text = shared_text(screen)
      text.should contain "shared telemetry integration failure"
      text.should contain "RFC 7807"
    ensure
      server.stop
    end
  end
end
