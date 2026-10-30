require "../../spec_helper"
require "../../../src/azu_cli/integrations/auth_telemetry"

private alias AuthUI = AzuCLI::UI
private alias AuthEvents = AzuCLI::DevServer::Events

private def auth_screen
  AzuCLI::DevServer::MissionControl.new(AzuCLI::DevServer::Hud.new("store", "4000", "development", ""), "store", true)
end

private def auth_frame(screen)
  frame = AuthUI::Frame.new(136, 40, AuthUI::StyleTable.new(AuthUI::Theme.new(AuthUI::ColorDepth::TrueColor)))
  screen.view(frame)
  frame.to_text
end

describe AzuCLI::DevServer::AuthTab do
  it "renders a real auth producer over the socket and keeps it across main snapshots" do
    screen = auth_screen
    store = AzuAuthTelemetry::Store.new
    store.record("sign-in", "accepted")
    snapshots = Channel(JSON::Any).new(2)
    server = AzuCLI::DevServer::TelemetryServer.new
    begin
      server.start { |data| snapshots.send(data) }
      UNIXSocket.open(server.path) do |socket|
        socket.puts store.snapshot
        socket.puts %({"v":1,"sql":{"recent":[{"sql":"SELECT retained_sql","ms":1}]},"requests":{"recent":[]}})
        socket.flush
      end
      2.times do
        select
        when data = snapshots.receive
          screen.update(AuthEvents::Telemetry.new(data))
        when timeout(2.seconds)
          fail "Auth snapshot did not reach HUD"
        end
      end
      screen.update(AuthUI::Key.new(AuthUI::KeyCode::Char, '6'))
      text = auth_frame(screen)
      text.should contain "application events"
      text.should contain "Event: sign-in"
      text.should contain "Outcome: accepted"

      # Auth rejection replaces auth state without erasing the SQL snapshot.
      store.record("sign-in", "rejected")
      screen.update(AuthEvents::Telemetry.new(JSON.parse(store.snapshot)))
      screen.update(AuthUI::Key.new(AuthUI::KeyCode::Home))
      auth_frame(screen).should contain "Outcome: rejected"
      screen.update(AuthUI::Key.new(AuthUI::KeyCode::Char, '5'))
      auth_frame(screen).should contain "retained_sql"

      screen.update(AuthEvents::AppStarted.new(123_i64))
      screen.update(AuthUI::Key.new(AuthUI::KeyCode::Char, '6'))
      auth_frame(screen).should_not contain "Outcome: rejected"
      auth_frame(screen).should contain "No auth activity"
    ensure
      server.stop
    end
  end

  it "shows older app HTTP auth activity without mistaking a redirect for a successful login" do
    screen = auth_screen
    screen.update(AuthEvents::Telemetry.new(JSON.parse(%({"v":1,"requests":{"recent":[
      {"at":"12:00:00","method":"POST","path":"/login?token=secret","status":303},
      {"method":"GET","path":"/login","status":200},
      {"method":"POST","path":"/orders","status":201}]}}))))
    screen.update(AuthUI::Key.new(AuthUI::KeyCode::Char, '6'))
    text = auth_frame(screen)
    text.should contain "POST /login"
    text.should contain "Authentication outcome: unknown"
    text.should_not contain "secret"
    text.should_not contain "GET /login"
    text.should_not contain "/orders"
    text.should_not contain "accepted"
  end

  it "distinguishes an empty connected adapter from a missing one and validates the socket contract" do
    screen = auth_screen
    screen.update(AuthEvents::Telemetry.new(JSON.parse(AzuAuthTelemetry::Store.new.snapshot)))
    screen.update(AuthUI::Key.new(AuthUI::KeyCode::Char, '6'))
    auth_frame(screen).should contain "No authentication events yet"
    AzuCLI::DevServer::TelemetryServer.valid_snapshot?(JSON.parse(%({"v":1,"stream":"auth","auth":{"recent":"bad"}}))).should be_false
    AzuCLI::DevServer::TelemetryServer.valid_snapshot?(JSON.parse(%({"v":1,"stream":"auth"}))).should be_false
  end

  it "does not let request traffic make a stale auth adapter appear connected" do
    now = Time.instant
    screen = AzuCLI::DevServer::MissionControl.new(AzuCLI::DevServer::Hud.new("store", "4000", "development", ""), "store", true, clock: -> { now })
    screen.update(AuthEvents::Telemetry.new(JSON.parse(AzuAuthTelemetry::Store.new.snapshot)))
    now += 6.seconds
    screen.update(AuthEvents::Telemetry.new(JSON.parse(%({"v":1,"requests":{"recent":[]}}))))
    screen.update(AuthUI::Key.new(AuthUI::KeyCode::Char, '6'))
    auth_frame(screen).should contain "stale · Sessions"
  end
end

describe AzuAuthTelemetry::Store do
  it "bounds retention, uses unique event ids, and rejects arbitrary payload strings" do
    store = AzuAuthTelemetry::Store.new
    250.times { store.record("sign-in", "accepted") }
    store.record("password=secret", "accepted")
    store.record("sign-in", "cookie=secret")
    data = JSON.parse(store.snapshot)["auth"]
    data["total"].as_i.should eq 250
    entries = data["recent"].as_a
    entries.size.should eq 200
    entries.map { |row| row["id"].as_s }.uniq.size.should eq 200
    data.to_json.should_not contain "secret"
    entries.first.as_h.keys.sort.should eq %w(at event id outcome)
  end
end
