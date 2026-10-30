require "../../spec_helper"

private alias RemoteUI = AzuCLI::UI
private alias RemoteTarget = AzuCLI::Remote::Target

describe RemoteTarget do
  it "pins the noninteractive SSH policy and a fixed file-read command" do
    args = RemoteTarget.new("monitor@production", "/run/azu/monitor.json").arguments
    %w(BatchMode=yes StrictHostKeyChecking=yes ForwardAgent=no ForwardX11=no ClearAllForwardings=yes PermitLocalCommand=no ControlPath=none).each do |option|
      args.should contain option
    end
    args.last(3).should eq ["--", "monitor@production", "cat -- /run/azu/monitor.json"]
  end

  it "rejects option and remote shell injection" do
    ["-oProxyCommand=id", "user@host;id", "user@host\n", "user@host extra"].each do |host|
      expect_raises(ArgumentError) { RemoteTarget.new(host, "/run/azu.json").arguments }
    end
    ["/tmp/a;id", "/tmp/$(id)", "/tmp/../etc/passwd", "relative.json", "/tmp/a\n"].each do |file|
      expect_raises(ArgumentError) { RemoteTarget.new("prod", file).arguments }
    end
  end
end

describe AzuMonitor::Snapshot do
  it "accepts older slowest SQL samples without disclosing statements in production" do
    safe = AzuMonitor::Snapshot.filter(JSON.parse(%({"v":1,"sql":{"slowest":[{"sql":"SELECT 'SECRET'","ms":2.5}]}})), require_fresh: false)
    safe["sql"]["recent"][0]["ms"].as_f.should eq 2.5
    safe["sql"]["recent"][0]["sql"].as_s.should eq "[statement redacted]"
    safe.to_json.should_not contain "SECRET"
  end

  it "allowlists metrics and redacts application data before transport/display" do
    data = JSON.parse(%({"v":1,"captured_at":"#{Time.utc.to_rfc3339}","secret":"NEVER_RENDER",
      "requests":{"rps":12,"recent":[{"method":"GET","path":"/users/SECRET?token=SECRET","ms":2,"status":200}]},
      "sql":{"pool":{"max":20,"password":"SECRET"},"recent":[{"sql":"SELECT 'SECRET'","ms":1,"caller":"SECRET"}]},
      "auth":{"token":"SECRET"},"queues":[{"name":"default","pending":3,"processing":2,"failed":0}]}))
    safe = AzuMonitor::Snapshot.filter(data)
    safe.to_json.should_not contain "SECRET"
    safe.to_json.should_not contain "NEVER_RENDER"
    safe["requests"]["rps"].as_i.should eq 12
    safe["sql"]["recent"][0]["sql"].as_s.should eq "[statement redacted]"
    safe["queues"][0]["pending"].as_i.should eq 3
  end

  it "rejects stale, future, missing-version and oversized snapshots" do
    now = Time.utc
    [now - 31.seconds, now + 6.seconds].each do |time|
      expect_raises(ArgumentError) { AzuMonitor::Snapshot.parse(%({"v":1,"captured_at":"#{time.to_rfc3339}"}), now) }
    end
    expect_raises(ArgumentError) { AzuMonitor::Snapshot.parse(%({"v":2})) }
    expect_raises(ArgumentError) { AzuMonitor::Snapshot.parse(" " * (AzuMonitor::MAX_BYTES + 1)) }
  end

  it "ignores malformed optional data and negative metrics" do
    safe = AzuMonitor::Snapshot.filter(JSON.parse(%({"v":1,"requests":false,"sql":{"rps":-1,"pool":5},"queues":[false]})), require_fresh: false)
    safe["requests"]["recent"].as_a.should be_empty
    safe["sql"]["rps"]?.should be_nil
    safe["queues"].as_a.should be_empty
  end

  it "publishes a private, complete snapshot and preserves the old file on validation failure" do
    project = TestHelpers::TempProject.new("monitor_publish")
    begin
      path = File.join(project.path, "monitor.json")
      AzuMonitor::Snapshot.publish(path, JSON.parse(%({"v":1,"requests":{"rps":1}})))
      File.info(path).permissions.value.to_i.should eq 0o600
      before = File.read(path)
      expect_raises(ArgumentError) { AzuMonitor::Snapshot.publish(path, JSON.parse(%({"v":2}))) }
      File.read(path).should eq before
      Dir.glob("#{path}.*.tmp").should be_empty
      AzuMonitor::Snapshot.parse(before)["requests"]["rps"].as_i.should eq 1
    ensure
      project.cleanup
    end
  end
end

describe "production HUD boundary" do
  it "cannot invoke local commands, console, rebuild or automatic checks" do
    called = [] of String
    classic = AzuCLI::DevServer::Hud.new("prod", "", "production", "", on_rebuild: -> { called << "rebuild"; nil },
      on_control: ->(command : AzuCLI::DevServer::Control::Command) { called << command.id; nil })
    screen = AzuCLI::DevServer::MissionControl.new(classic, "prod", read_only: true,
      on_command: ->(_command : AzuCLI::DevServer::Control::Command) { called << "command"; true })
    "c?erg:dv".each_char { |char| screen.update(RemoteUI::Key.new(RemoteUI::KeyCode::Char, char)) }
    screen.update(RemoteUI::Tick.new(Time.instant))
    screen.handoff.should be_nil
    called.should be_empty
    screen.update(RemoteUI::Key.new(RemoteUI::KeyCode::CtrlP))
    frame = RemoteUI::Frame.new(136, 40, RemoteUI::StyleTable.new(RemoteUI::Theme.new(RemoteUI::ColorDepth::None)))
    screen.view(frame)
    frame.to_text.should contain "READ ONLY"
    frame.to_text.should_not contain "Generate code"
    %w(Console Build Config Commands).each { |name| frame.to_text.should_not contain "Open #{name}" }
  end

  it "does not load a working directory's .env for connect" do
    AzuCLI.load_project_env(%w(connect --ssh prod --snapshot /run/azu.json), "/not-a-project").should be_empty
  end
end
