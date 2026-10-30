# Render actual frames with sample data; --interactive runs the native event loop.
# crystal run scripts/render_mission_control.cr [-- --interactive]
require "cadmium_inflector"
require "../src/azu_cli/logger"
require "../src/azu_cli/utils"
require "../src/azu_cli/dev_server/changes"
require "../src/azu_cli/dev_server/mission_control"

alias MissionUI = AzuCLI::UI
alias MissionDev = AzuCLI::DevServer

classic = MissionDev::Hud.new("blog", "4000", "development", "illustrative telemetry",
  commands: [] of MissionDev::Control::Command)
program : MissionUI::Program? = nil
control : MissionDev::Control::Runner? = nil
if binary = ENV["AZU_PREVIEW_COMMAND_BINARY"]?
  control = MissionDev::Control::Runner.new(->(event : MissionUI::Message) { program.try(&.send(event)); nil }, executable: binary)
end
screen = MissionDev::MissionControl.new(classic, "blog", sample_data: true,
  on_command: ->(command : MissionDev::Control::Command) { control.try(&.enqueue(command)) || false })
screen.update(MissionDev::Events::AppStarted.new(53628_i64))
[144.0, 240.0, 390.0, 512.0, 640.0, 760.0, 820.0, 950.0, 1080.0, 1150.0, 1200.0].each do |rate|
  screen.update(MissionDev::Events::Telemetry.new(JSON.parse({v: 1, requests: {rps: rate}}.to_json)))
end
screen.update(MissionDev::Events::Telemetry.new(JSON.parse(<<-JSON
{"requests":{"rps":1284,"p95_ms":8.4,"recent":[
 {"at":"14:32:08","method":"GET","path":"/products","status":200,"ms":4.8,"endpoint":"Products::Index","id":"req_8f31"},
 {"at":"14:32:07","method":"POST","path":"/checkout","status":200,"ms":18.1,"endpoint":"Checkout::Create"}]},
 "sql":{"n_plus_one":[{"sql":"SELECT * FROM carts WHERE id = $1","count":12,"suggestion":"Preload cart items","caller":"product_repository.cr:41"}],"total":2,"avg_ms":1.55,"slow":0,"histogram":[{"label":"0–1","count":1,"bar":12},{"label":"1–5","count":1,"bar":12}],"pool":{"in_flight":6,"max":20,"idle":14},"recent":[
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
  "14:32:07.993 INFO  Azu    starting server                  pid=53628",
  "14:32:08.041 INFO  HTTP   GET /                 200 6.3ms req_8f2a",
  "14:32:08.104 INFO  HTTP   GET /products         200 4.8ms req_8f31",
  "14:32:08.106 DEBUG CQL query.complete 2.3ms req_8f31",
  "14:32:08.110 INFO  JoobQ mailer.completed 8.1ms",
  "14:32:08.203 WARN  CQL N+1 detected 12 queries",
  "14:32:08.318 ERROR JoobQ  mailer.failed         retry 2/5 job_4a1d",
  "               SMTP::Error: connection timeout",
  "                 app/jobs/welcome_mail.cr:28",
  "14:32:08.421 INFO  HTTP   POST /checkout        200 18.1ms req_8f41",
  "14:32:08.448 DEBUG DB     transaction commit             3.7ms",
  "14:32:08.512 INFO  HTTP   GET /orders           200 5.9ms req_8f42",
  "14:32:08.639 INFO  CQL    cache.hit                      0.4ms",
  "14:32:08.771 INFO  JoobQ  job.started                    mailer job_4a1e",
  "14:32:08.904 WARN  Auth   rate limit approaching         85/100",
  "14:32:09.112 INFO  HTTP   GET /customers/42     200 3.9ms req_8f43",
  "14:32:09.331 DEBUG CQL    query.complete                 1.1ms",
  "14:32:09.487 INFO  HTTP   GET /products/1       200 4.4ms req_8f44",
].each { |line| screen.update(MissionDev::Events::LogLine.new(line)) }

screen.update(MissionDev::Events::Telemetry.new(JSON.parse(File.read("spec/fixtures/telemetry/azu-dashboard-v1.json"))))

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
  directory = ENV["AZU_PREVIEW_DIR"]? || "/tmp/azu-cli-previews/mission-control"
  Dir.mkdir_p(directory)
  [{"overview", '1', 200, 60}, {"auth", '6', 156, 46}, {"sql", 's', 156, 46}, {"logs", '4', 156, 46}, {"tracing", '3', 156, 46}, {"cache", '8', 156, 46}, {"mailers", 'm', 156, 46}, {"compact", '1', 80, 24}].each do |(name, tab, width, height)|
    screen.update(MissionUI::Key.new(MissionUI::KeyCode::Char, tab))
    styles = MissionUI::StyleTable.new(MissionUI::Theme.new(MissionUI::ColorDepth::TrueColor), MissionUI::Token::Backplate)
    frame = MissionUI::Frame.new(width, height, styles)
    screen.view(frame)
    File.write("#{directory}/#{name}.txt", frame.to_text)
    File.write("#{directory}/#{name}.ansi", frame.ansi_lines.join("\r\n"))
  end
  screen.update(MissionUI::Key.new(MissionUI::KeyCode::Char, '1'))
  screen.update(MissionUI::Key.new(MissionUI::KeyCode::Char, 'h'))
  hints = MissionUI::Frame.new(156, 46, MissionUI::StyleTable.new(MissionUI::Theme.new(MissionUI::ColorDepth::TrueColor), MissionUI::Token::Backplate))
  screen.view(hints)
  File.write("#{directory}/hints.txt", hints.to_text)
  File.write("#{directory}/hints.ansi", hints.ansi_lines.join("\r\n"))
  screen.update(MissionUI::Key.new(MissionUI::KeyCode::Esc))
  screen.update(MissionUI::Key.new(MissionUI::KeyCode::CtrlP))
  "sql".each_char { |char| screen.update(MissionUI::Key.new(MissionUI::KeyCode::Char, char)) }
  frame = MissionUI::Frame.new(156, 46, MissionUI::StyleTable.new(MissionUI::Theme.new(MissionUI::ColorDepth::TrueColor), MissionUI::Token::Backplate))
  screen.view(frame)
  File.write("#{directory}/menu.txt", frame.to_text)
  File.write("#{directory}/menu.ansi", frame.ansi_lines.join("\r\n"))
  remote = MissionDev::MissionControl.new(classic, "production", read_only: true, sample_data: true)
  remote.update(MissionDev::Events::Telemetry.new(JSON.parse(%({"v":1,"requests":{"rps":42,"p95_ms":8.4},"sql":{"pool":{"in_flight":3,"max":20}}}))))
  frame = MissionUI::Frame.new(156, 46, MissionUI::StyleTable.new(MissionUI::Theme.new(MissionUI::ColorDepth::TrueColor), MissionUI::Token::Backplate))
  remote.view(frame)
  File.write("#{directory}/production.txt", frame.to_text)
  File.write("#{directory}/production.ansi", frame.ansi_lines.join("\r\n"))
  puts "Rendered mission-control frames to #{directory} (sample data)"
end
