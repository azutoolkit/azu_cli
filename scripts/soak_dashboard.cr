# Bounded synthetic pressure on the real reducer and renderer, no app/Redis writes.
require "cadmium_inflector"
require "../src/azu_cli/logger"
require "../src/azu_cli/utils"
require "../src/azu_cli/dev_server/changes"
require "../src/azu_cli/dev_server/mission_control"
alias UI = AzuCLI::UI
alias Dev = AzuCLI::DevServer
seconds = (ENV["SOAK_SECONDS"]? || "600").to_i
screen = Dev::MissionControl.new(Dev::Hud.new("soak", "4000", "development", "soak"), "soak", true)
styles = UI::StyleTable.new(UI::Theme.new(UI::ColorDepth::TrueColor), UI::Token::Backplate)
payload = JSON.parse(File.read("spec/fixtures/telemetry/azu-dashboard-v1.json"))
io = IO::Memory.new
renderer = UI::FullScreenRenderer.new(io)
started = Time.instant
iterations = 0
baseline = 0_u64
maximum_update = Time::Span.zero
while Time.instant - started < seconds.seconds
  began = Time.instant
  payload.as_h["at"] = JSON::Any.new(iterations.to_s)
  screen.update(Dev::Events::Telemetry.new(payload))
  25.times { |i| screen.update(Dev::Events::LogLine.new("INFO event #{iterations}-#{i}")) }
  screen.update(UI::Key.new(UI::KeyCode::Char, ']'))
  screen.update(UI::Key.new(UI::KeyCode::Char, '['))
  frame = UI::Frame.new(140, 45, styles)
  screen.view(frame)
  io.clear
  renderer.flush(frame)
  maximum_update = Math.max(maximum_update, Time.instant - began)
  iterations += 1
  if iterations % 200 == 0
    GC.collect
    baseline = GC.stats.heap_size if baseline == 0
    raise "Unbounded heap growth" if GC.stats.heap_size > baseline + 16_u64 * 1024 * 1024
  end
  sleep Math.max(Time::Span.zero, 50.milliseconds - (Time.instant - began))
end
puts({seconds: seconds, frames: iterations, log_events: iterations * 25, max_update_ms: maximum_update.total_milliseconds, heap_bytes: GC.stats.heap_size}.to_json)
