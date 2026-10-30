# Render actual frames with sample data; --interactive runs the native event loop.
# crystal run scripts/render_mission_control.cr [-- --interactive]
require "cadmium_inflector"
require "../src/azu_cli/logger"
require "../src/azu_cli/utils"
require "../src/azu_cli/dev_server/changes"
require "../src/azu_cli/dev_server/mission_control"

alias MissionUI = AzuCLI::UI
alias MissionDev = AzuCLI::DevServer

classic = MissionDev::Hud.new("storefront · SAMPLE DATA", "4000", "development", "illustrative telemetry",
  commands: [] of MissionDev::Control::Command)
program : MissionUI::Program? = nil
control : MissionDev::Control::Runner? = nil
if binary = ENV["AZU_PREVIEW_COMMAND_BINARY"]?
  control = MissionDev::Control::Runner.new(->(event : MissionUI::Message) { program.try(&.send(event)); nil }, executable: binary)
end
screen = MissionDev::MissionControl.new(classic, "storefront · SAMPLE DATA",
  on_command: ->(command : MissionDev::Control::Command) { control.try(&.enqueue(command)) || false })
screen.update(MissionDev::Events::AppStarted.new(48231_i64))
screen.update(MissionDev::Events::Telemetry.new(JSON.parse(<<-JSON
{"requests":{"rps":1284,"p95_ms":8.4,"recent":[
 {"at":"14:32:08","method":"GET","path":"/products","status":200,"ms":4.8,"endpoint":"Products::Index","id":"req_8f31"},
 {"at":"14:32:07","method":"POST","path":"/checkout","status":200,"ms":18.1,"endpoint":"Checkout::Create"}]},
 "sql":{"total":2,"avg_ms":1.55,"slow":0,"histogram":[{"label":"0–1","count":1,"bar":12},{"label":"1–5","count":1,"bar":12}],"pool":{"in_flight":6,"max":20,"idle":2},"recent":[
 {"id":"query-1","sql":"SELECT p.id, p.name FROM products AS p WHERE p.active = TRUE AND p.category_id = $1 ORDER BY p.created_at DESC LIMIT 20","ms":2.3,"caller":"product_repository.cr:41","model":"Product","pool_wait_ms":0.1},
 {"id":"query-2","sql":"SELECT * FROM carts WHERE id = $1","ms":0.8,"caller":"cart_repository.cr:28"}]},
 "auth":{"recent":[{"id":"event-1","at":"14:32:08","event":"sign-in","outcome":"accepted"},{"id":"event-2","at":"14:31:42","event":"rate-limit","outcome":"applied"}]},
 "database":{"migration_version":"202610291200","tables":[{"name":"products","columns":[{"name":"id","type":"bigint"},{"name":"name","type":"text"},{"name":"price_cents","type":"integer"}]}]}}
JSON
)))
screen.update(MissionDev::Events::JobsSample.new([
  MissionDev::Events::Queue.new("default", 24_i64, 8_i64, 0_i64),
  MissionDev::Events::Queue.new("mailers", 7_i64, 2_i64, 1_i64),
  MissionDev::Events::Queue.new("reports", 0_i64, 0_i64, 0_i64),
]))
[
  "14:32:08.104 INFO  Azu GET /products 200 4.8ms req_8f31",
  "14:32:08.106 DEBUG CQL query.complete 2.3ms req_8f31",
  "14:32:08.110 INFO  JoobQ mailer.completed 8.1ms",
  "14:32:08.203 WARN  CQL N+1 detected 12 queries",
  "14:32:08.318 ERROR JoobQ mailer.failed retry 2/5",
].reverse_each { |line| screen.update(MissionDev::Events::LogLine.new(line)) }

if ARGV.includes?("--interactive")
  terminal = MissionUI::Terminal.detect
  abort "Interactive preview needs a terminal" unless terminal.interactive?
  running = MissionUI::Program.new(screen, terminal, MissionUI::FullScreenRenderer.new(terminal.output))
  program = running
  begin
    control.try(&.start)
    running.run
  ensure
    control.try(&.stop)
  end
else
  directory = "docs/assets/terminal-ui/mission-control"
  Dir.mkdir_p(directory)
  [{"overview", '1', 136, 40}, {"sql", '5', 136, 40}, {"logs", '7', 136, 40}, {"compact", '1', 80, 24}].each do |(name, tab, width, height)|
    screen.update(MissionUI::Key.new(MissionUI::KeyCode::Char, tab))
    styles = MissionUI::StyleTable.new(MissionUI::Theme.new(MissionUI::ColorDepth::TrueColor), MissionUI::Token::Backplate)
    frame = MissionUI::Frame.new(width, height, styles)
    screen.view(frame)
    File.write("#{directory}/#{name}.txt", frame.to_text)
    File.write("#{directory}/#{name}.ansi", frame.ansi_lines.join("\r\n"))
  end
  screen.update(MissionUI::Key.new(MissionUI::KeyCode::CtrlP))
  frame = MissionUI::Frame.new(136, 40, MissionUI::StyleTable.new(MissionUI::Theme.new(MissionUI::ColorDepth::TrueColor), MissionUI::Token::Backplate))
  screen.view(frame)
  File.write("#{directory}/menu.txt", frame.to_text)
  File.write("#{directory}/menu.ansi", frame.ansi_lines.join("\r\n"))
  remote = MissionDev::MissionControl.new(classic, "production · SAMPLE DATA", read_only: true)
  remote.update(MissionDev::Events::Telemetry.new(JSON.parse(%({"v":1,"requests":{"rps":42,"p95_ms":8.4},"sql":{"pool":{"in_flight":3,"max":20}}}))))
  frame = MissionUI::Frame.new(136, 40, MissionUI::StyleTable.new(MissionUI::Theme.new(MissionUI::ColorDepth::TrueColor), MissionUI::Token::Backplate))
  remote.view(frame)
  File.write("#{directory}/production.txt", frame.to_text)
  File.write("#{directory}/production.ansi", frame.ansi_lines.join("\r\n"))
  puts "Rendered mission-control frames to #{directory} (sample data)"
end
