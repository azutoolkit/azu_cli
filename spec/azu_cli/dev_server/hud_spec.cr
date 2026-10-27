require "../../spec_helper"

private alias TUI = AzuCLI::UI
private alias Ev = AzuCLI::DevServer::Events

private class FakeClock
  property now = Time.instant

  def advance(span : Time::Span) : Nil
    @now += span
  end
end

private def hud(clock = FakeClock.new, rebuild = -> { })
  AzuCLI::DevServer::Hud.new("blog", "4000", "development", "watching src", on_rebuild: rebuild, clock: -> { clock.now }, directory: "/work/blog")
end

private def render(screen, width = 100, height = 32) : String
  frame = TUI::Frame.new(width, height, TUI::StyleTable.new(TUI::Theme.new(TUI::ColorDepth::None)))
  screen.view(frame)
  frame.to_text
end

private def snapshot : JSON::Any
  JSON.parse({
    v:        1,
    requests: {total: 2184, rps: 18.4, p50_ms: 2.1, p95_ms: 9.8, errors_4xx: 1, errors_5xx: 0,
               recent: [{at: "14:32:05", method: "POST", path: "/posts", status: 303, ms: 8.9, endpoint: "Blog::Posts::CreateEndpoint"}]},
    sql: {total: 212, avg_ms: 0.8, slow: 2, pool: {open: 3, idle: 0, in_flight: 3, max: 10},
          n_plus_one: [{sql: "SELECT * FROM comments WHERE post_id = ?", count: 20, endpoint: "Posts::IndexEndpoint", caller: "index_page.cr:14"}],
          slowest: [{sql: "SELECT * FROM posts ORDER BY created_at", ms: 9.1}]},
    runtime: {heap_bytes: 31_000_000},
  }.to_json)
end

describe AzuCLI::DevServer::Hud do
  it "follows a build from start to a running app" do
    clock = FakeClock.new
    screen = hud(clock)
    screen.update(Ev::BuildStarted.new(["src/models/post.cr"]))
    screen.state.building?.should be_true
    screen.update(Ev::BuildLine.new("[13/14] [120/385] Codegen (bc+obj)"))
    render(screen).should contain "Codegen (bc+obj)"
    screen.update(Ev::BuildFinished.new(true, 6.24, ""))
    screen.update(Ev::AppStarted.new(48213_i64))
    screen.state.running?.should be_true
    text = render(screen)
    text.should contain "● running"
    text.should contain "pid 48213"
    text.should contain "✔ built in 6.2s"
    text.should contain "src/models/post.cr"
  end

  it "shows a failed build over the dashboard while the previous app keeps serving, until Esc" do
    screen = hud
    screen.update(Ev::AppStarted.new(7_i64))
    output = "Showing last frame. Use --error-trace for full trace.\n\nIn src/endpoints/posts/create_endpoint.cr:18:30\n\n 18 | redirect to: \"/posts/\#{post.idd}\"\n                              ^--\nError: undefined method 'idd' for Post\n"
    screen.update(Ev::BuildFinished.new(false, 2.4, output))
    text = render(screen)
    text.should contain "Build failed · the app keeps running the previous build (pid 7)"
    text.should contain "src/endpoints/posts/create_endpoint.cr:18:30"
    text.should contain "Error: undefined method 'idd' for Post"
    screen.update(TUI::Key.new(TUI::KeyCode::Esc)).should eq TUI::Action::Redraw
    render(screen).should_not contain "Build failed ·"
  end

  it "draws the app's telemetry: requests, the N+1 alert, the pool" do
    screen = hud
    screen.update(Ev::Telemetry.new(snapshot))
    text = render(screen)
    text.should contain "18.4 req/s"
    text.should contain "p95 9.8 ms"
    text.should contain "POST   /posts"
    text.should contain "Blog::Posts::CreateEndpoint"
    text.should contain "▲ N+1 ×20"
    text.should contain "index_page.cr:14"
    text.should contain "pool 3/10"
    screen.summary.should contain "2184 requests"
  end

  it "says what the panels need while no telemetry arrives" do
    render(hud).should contain "Waiting for telemetry from the app"
  end

  it "switches tabs with the number keys, rebuilds with r and quits with q" do
    rebuilt = false
    screen = hud(rebuild: -> { rebuilt = true; nil })
    screen.update(TUI::Key.new(TUI::KeyCode::Char, '5'))
    screen.tab.log?.should be_true
    screen.update(Ev::LogLine.new("listening on :4000"))
    render(screen).should contain "listening on :4000"
    screen.update(TUI::Key.new(TUI::KeyCode::Char, 'r'))
    rebuilt.should be_true
    screen.update(TUI::Key.new(TUI::KeyCode::Char, 'q')).should eq TUI::Action::Quit
  end

  it "counts crashes and keeps a bounded log" do
    screen = hud
    screen.update(Ev::AppStarted.new(1_i64))
    screen.update(Ev::AppExited.new("exited with code 1"))
    screen.crashes.should eq 1
    render(screen).should contain "The app exited with code 1"
    600.times { |index| screen.update(Ev::LogLine.new("line #{index}")) }
    screen.log.size.should eq AzuCLI::DevServer::Hud::LOG_LINES
  end

  it "never lets a long status run into the clock" do
    screen = hud
    screen.update(Ev::AppStarted.new(32676_i64))
    screen.update(Ev::BuildFinished.new(false, 1.0, "Error: boom"))
    title = render(screen, 90).lines.first
    title.should match(/… +\d\d:\d\d:\d\d/)
  end

  it "fits a narrow terminal" do
    text = render(hud, 62, 24)
    text.should contain "Build · App"
    text.lines.all? { |line| AzuCLI::UI::Width.of(line) <= 62 }.should be_true
  end
end

describe AzuCLI::DevServer::CompilerProgress do
  it "reads the compiler's --progress lines" do
    progress = AzuCLI::DevServer::CompilerProgress.parse("[13/14] [120/385] Codegen (bc+obj)    ").not_nil!
    progress.stage.should eq "Codegen (bc+obj)"
    progress.phase.should eq "codegen"
    progress.fraction.should be_close(12.31 / 14, 0.01)
    AzuCLI::DevServer::CompilerProgress.parse("[2/14] Semantic (top level)").not_nil!.phase.should eq "semantic"
    AzuCLI::DevServer::CompilerProgress.parse("Dependencies are satisfied").should be_nil
  end
end

describe AzuCLI::DevServer::LineSink do
  it "splits on newlines and on the carriage returns of progress output" do
    lines = [] of String
    sink = AzuCLI::DevServer::LineSink.new { |line| lines << line }
    sink << "[1/14] Parse   \r[2/14] Semantic\nError: boom\n"
    lines.should eq ["[1/14] Parse   ", "[2/14] Semantic", "Error: boom"]
  end
end

describe AzuCLI::DevServer::TelemetryServer do
  it "receives the app's snapshots on a socket in a directory only this user can enter, and cleans up" do
    server = AzuCLI::DevServer::TelemetryServer.new
    received = Channel(JSON::Any).new(1)
    server.start { |data| received.send(data) }
    begin
      (File.info(File.dirname(server.path)).permissions.value & 0o077).should eq 0
      client = UNIXSocket.new(server.path)
      client.puts %({"v":2,"ignored":true})
      client.puts %({"v":1,"requests":{"total":3}})
      client.flush
      select
      when data = received.receive
        data.dig("requests", "total").as_i.should eq 3
      when timeout(2.seconds)
        fail "no snapshot arrived"
      end
      client.close
    ensure
      server.stop
    end
    File.exists?(server.path).should be_false
    Dir.exists?(File.dirname(server.path)).should be_false
  end
end
