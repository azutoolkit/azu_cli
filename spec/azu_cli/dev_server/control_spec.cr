require "../../spec_helper"

private alias TUI = AzuCLI::UI
private alias Ev = AzuCLI::DevServer::Events
private alias Control = AzuCLI::DevServer::Control

private class Clock
  property now = Time.instant
end

private def control_hud(requested : Array(String), clock = Clock.new)
  AzuCLI::DevServer::Hud.new("blog", "4000", "development", "watching src", clock: -> { clock.now }, directory: "/work/blog",
    commands: Control.catalog("zsh", jobs: false), on_control: ->(command : Control::Command) { requested << command.id; nil })
end

private def key(char : Char)
  TUI::Key.new(TUI::KeyCode::Char, char)
end

private def press(screen, code : TUI::KeyCode, times = 1)
  times.times { screen.update(TUI::Key.new(code)) }
end

# Moves the Commands panel's selection to `id`.
private def select_command(screen, id : String)
  until screen.commands[screen.selected].id == id
    press(screen, TUI::KeyCode::Down)
  end
end

private def render(screen, width = 120, height = 32) : String
  frame = TUI::Frame.new(width, height, TUI::StyleTable.new(TUI::Theme.new(TUI::ColorDepth::None)))
  screen.view(frame)
  frame.to_text
end

describe AzuCLI::DevServer::Control do
  it "reads a one-line outcome from each command's plain output" do
    Control.outcome("doctor", 0, "ok    crystal  x\n\n8 ok, 1 warnings, 0 failures\n").should eq({Control::Status::Warn, "8 ok · 1 warn · 0 fail"})
    Control.outcome("doctor", 1, "9 ok, 0 warnings, 1 failures").should eq({Control::Status::Fail, "9 ok · 0 warn · 1 fail"})
    Control.outcome("routes", 0, "GET /  A\n\n9 routes\n").should eq({Control::Status::Ok, "9 routes"})
    Control.outcome("db:status", 0, "Total: 3 migrations (2 applied, 1 pending)").should eq({Control::Status::Warn, "2 applied · 1 pending"})
    Control.outcome("test", 1, "Finished in 2s\n12 examples, 1 failures, 0 errors, 2 pending\n").should eq({Control::Status::Fail, "12 examples · 1 failed · 2 pending"})
    Control.outcome("test", 0, "12 examples, 0 failures, 0 errors, 0 pending").should eq({Control::Status::Ok, "12 examples · 0 failed · 0 pending"})
    Control.outcome("config", 0, "SERVER\n  port         4000\n  host         127.0.0.1\n\nSECRETS\n  csrf_secret  not set\n").should eq({Control::Status::Ok, "3 settings · 1 not set"})
    Control.outcome("config", 1, "ERROR: ./src/blog.cr not found: run 'azu config' in the root of an Azu project\n").should eq({Control::Status::Fail, "./src/blog.cr not found: run 'azu config' in the root of an Azu project"})
  end

  it "says why a run failed with its error line, without the log prefix" do
    Control.outcome("db:migrate", 1, "[19:00:00] [INFO ] Validating\nERROR: Database 'blog' does not exist.\n").should eq({Control::Status::Fail, "Database 'blog' does not exist."})
    Control.outcome("version", 0, "[19:08:51] [INFO ] Azu CLI v0.1.49\n").should eq({Control::Status::Ok, "Azu CLI v0.1.49"})
  end

  it "prints the completion script of the login shell, bash when it is another" do
    Control.shell({"SHELL" => "/bin/zsh"}).should eq "zsh"
    Control.shell({"SHELL" => "/usr/bin/tcsh"}).should eq "bash"
    Control.catalog("fish").find!(&.id.==("completion")).args.should eq ["completion", "fish"]
  end

  it "lists every registered command but the ones it leaves out on purpose" do
    registered = File.read("src/azu_cli/cli.cr").scan(/register_command\("([^"]+)", (Commands::[\w:]+)\)/)
    aliases = registered.group_by(&.[2]).values.flat_map { |names| names[1..].map(&.[1]) } # g, server, s, t
    listed = Control.catalog("bash", jobs: true).map(&.id)
    (registered.map(&.[1]) - aliases - Control::LEFT_OUT.to_a).sort.should eq listed.sort
  end

  it "lists the jobs commands only in a JoobQ project" do
    Control.catalog("bash", jobs: false).map(&.id).select(&.starts_with?("jobs:")).should be_empty
    Control.catalog("bash", jobs: true).map(&.id).select(&.starts_with?("jobs:")).should eq ["jobs:status", "jobs:retry", "jobs:clear"]
  end

  it "asks before every command that changes something, and runs it without a prompt of its own" do
    catalog = Control.catalog("bash", jobs: true)
    changing = %w[db:migrate db:rollback db:seed db:data:migrate db:create db:setup db:schema:load db:reset db:drop jobs:retry jobs:clear session:clear]
    catalog.select(&.confirm).map(&.id).sort.should eq changing.sort
    # these ask "are you sure?" on their own: the panel has no terminal to answer, its y is the answer
    %w[db:rollback db:reset db:drop jobs:clear session:clear].each { |id| catalog.find!(&.id.==(id)).args.should contain "--force" }
    # verify would roll back and re-apply the newest migration without it
    catalog.find!(&.id.==("db:migrations:verify")).args.should eq ["db:migrations:verify", "--no-rollback"]
    catalog.find!(&.id.==("db:drop")).effect.should eq "the database"
    catalog.find!(&.id.==("jobs:clear")).effect.should eq "the job queues"
    catalog.find!(&.id.==("session:clear")).effect.should eq "the session store"
  end
end

describe "AzuCLI::DevServer::Hud.window" do
  it "keeps a window of rows inside them, from the top or back from the end" do
    rows = (1..10).to_a
    AzuCLI::DevServer::Hud.window(rows, 4, 0).should eq({[1, 2, 3, 4], 0, "1-4 of 10"})
    AzuCLI::DevServer::Hud.window(rows, 4, 99).should eq({[7, 8, 9, 10], 6, "7-10 of 10"})
    AzuCLI::DevServer::Hud.window(rows, 4, 0, tail: true).should eq({[7, 8, 9, 10], 0, "7-10 of 10"})
    AzuCLI::DevServer::Hud.window(rows, 4, 2, tail: true).should eq({[5, 6, 7, 8], 2, "5-8 of 10"})
    AzuCLI::DevServer::Hud.window(rows, 20, 3).should eq({rows, 0, nil})
  end
end

describe "AzuCLI::DevServer::Hud control plane" do
  it "runs the start commands on the first event, and each command again when what it reads changes" do
    requested = [] of String
    screen = control_hud(requested)
    screen.update(TUI::Tick.new(Time.instant))
    requested.should eq ["doctor", "db:status", "version"]

    requested.clear
    screen.update(Ev::BuildStarted.new)
    screen.update(Ev::BuildFinished.new(true, 4.0, ""))
    requested.should eq ["routes", "config"]

    requested.clear
    %w[doctor db:status version routes config].each do |id|
      screen.update(Ev::ControlFinished.new(id, 0, "", 0.5))
    end
    screen.update(Ev::Changed.new(["src/db/migrations/20261027_create_posts.cr"], AzuCLI::DevServer::Action::Rebuild))
    requested.should eq ["db:status"]
    requested.clear
    screen.update(Ev::Changed.new([".env.local"], AzuCLI::DevServer::Action::Restart))
    requested.should eq ["doctor", "config"]
  end

  it "does not queue a command that is already queued or running" do
    requested = [] of String
    screen = control_hud(requested)
    screen.update(TUI::Tick.new(Time.instant))
    requested.clear
    screen.update(Ev::Changed.new([".env"], AzuCLI::DevServer::Action::Restart))
    requested.should eq ["config"] # doctor is still queued from the start; config was not
    requested.clear
    screen.update(Ev::Changed.new([".env.local"], AzuCLI::DevServer::Action::Restart))
    requested.should be_empty
  end

  it "runs the selected command on Enter, and a command that changes things only after y" do
    requested = [] of String
    screen = control_hud(requested)
    screen.update(key('2'))
    screen.tab.commands?.should be_true
    screen.update(Ev::ControlFinished.new("db:status", 0, "Total: 1 migrations (0 applied, 1 pending)", 1.0))
    requested.clear
    select_command(screen, "db:migrate")
    screen.update(TUI::Key.new(TUI::KeyCode::Enter))
    requested.should be_empty
    render(screen).should contain "press y to run it"
    screen.update(key('n'))
    requested.should be_empty
    screen.update(TUI::Key.new(TUI::KeyCode::Enter))
    screen.update(key('y'))
    requested.should eq ["db:migrate"]

    screen.update(Ev::ControlFinished.new("db:migrate", 0, "done", 20.0))
    requested.should eq ["db:migrate", "db:status"] # what the migration changed
  end

  it "runs every check on a, nothing that changes things" do
    requested = [] of String
    screen = control_hud(requested)
    screen.update(key('2'))
    %w[doctor db:status version].each { |id| screen.update(Ev::ControlFinished.new(id, 0, "", 1.0)) } # the start runs
    requested.clear
    screen.update(key('a'))
    requested.sort.should eq %w[config db:migrations:verify db:status db:validate doctor routes version]
  end

  it "reads the database again after any command that changed it" do
    requested = [] of String
    screen = control_hud(requested)
    screen.update(key('2'))
    screen.update(Ev::ControlFinished.new("db:status", 0, "", 1.0))
    select_command(screen, "db:rollback")
    screen.update(TUI::Key.new(TUI::KeyCode::Enter))
    text = render(screen)
    text.should contain "azu db:rollback --force changes the database"
    text.should contain "press y to run it, any other key cancels"
    screen.update(key('y'))
    requested.clear
    screen.update(Ev::ControlFinished.new("db:rollback", 0, "done", 2.0))
    requested.should eq ["db:status"]
    screen.update(Ev::ControlFinished.new("openapi:export", 0, "done", 2.0))
    requested.should eq ["db:status"] # it changed no database
  end

  it "scrolls the list to keep the selected command in view on a short terminal" do
    screen = control_hud([] of String)
    screen.update(key('2'))
    render(screen, 120, 14).should contain "doctor"
    select_command(screen, "completion")
    text = render(screen, 120, 14)
    text.should contain "▸ ○ completion"
    text.should_not contain "HEALTH"
    select_command(screen, "doctor") # wraps around to the top
    render(screen, 120, 14).should match /▸ . doctor/
  end

  it "scrolls the selected command's output with PgUp and PgDn" do
    screen = control_hud([] of String)
    screen.update(key('2'))
    screen.update(Ev::ControlFinished.new("doctor", 0, (1..60).map { |n| "line #{n}" }.join("\n"), 1.0))
    text = render(screen, 120, 20)
    text.should contain "│ line 60 "
    text.should contain "of 60"
    press(screen, TUI::KeyCode::PageUp)
    text = render(screen, 120, 20)
    text.should_not contain "│ line 60 "
    text.should contain "│ line 4"
    press(screen, TUI::KeyCode::PageDown, 20)
    render(screen, 120, 20).should contain "│ line 60 "
  end

  it "scrolls the Log back, keeps it there as lines arrive, and End follows the newest again" do
    screen = control_hud([] of String)
    50.times { |n| screen.update(Ev::LogLine.new("app line #{n + 1}")) }
    screen.update(key('7'))
    render(screen, 100, 16).should contain "app line 50"
    press(screen, TUI::KeyCode::Up, 10)
    text = render(screen, 100, 16)
    text.should_not contain "app line 50"
    text.should contain "app line 40"
    screen.update(Ev::LogLine.new("app line 51"))
    render(screen, 100, 16).should contain "app line 40" # stays where it was scrolled to
    press(screen, TUI::KeyCode::End)
    render(screen, 100, 16).should contain "app line 51"
  end

  it "scrolls the Requests tab through the recent requests" do
    screen = control_hud([] of String)
    recent = (1..40).map { |n| {"at" => "12:00:#{n}", "method" => "GET", "path" => "/posts/#{n}", "status" => 200, "ms" => 1.5, "endpoint" => "Show"} }
    screen.update(Ev::Telemetry.new(JSON.parse({"requests" => {"total" => 40, "rps" => 1.0, "recent" => recent}}.to_json)))
    screen.update(key('4'))
    text = render(screen, 120, 16)
    text.should contain "/posts/1 "
    text.should contain "1-9 of 40"
    press(screen, TUI::KeyCode::PageDown)
    text = render(screen, 120, 16)
    text.should_not contain "/posts/1 "
    press(screen, TUI::KeyCode::End)
    render(screen, 120, 16).should contain "/posts/40"
    press(screen, TUI::KeyCode::Home)
    render(screen, 120, 16).should contain "/posts/1 "
  end

  it "shows azu config's last reading on the Config tab, a section under the other" do
    requested = [] of String
    screen = control_hud(requested)
    screen.update(key('8'))
    screen.tab.config?.should be_true
    render(screen).should contain "azu config runs after the first build; Enter runs it now"

    requested.clear
    screen.update(TUI::Key.new(TUI::KeyCode::Enter))
    requested.should eq ["config"]
    screen.update(Ev::ControlStarted.new("config"))
    render(screen).should contain "compiling the app to read its configuration"

    output = "SERVER\n  environment     development\n  port            4000\n  loopback only   true\n\n" \
             "SECRETS\n  CSRF_SECRET     set\n  SESSION_SECRET  not set\n\n" \
             "DATABASE\n  url             postgres://admin:***@db.internal:5432/app\n"
    screen.update(Ev::ControlFinished.new("config", 0, output, 3.0))
    text = render(screen)
    text.should contain "╭─ Config · development "
    text.should contain "read 0s ago"
    text.should contain "SERVER"
    text.should contain "  loopback only   true"
    text.should contain "  SESSION_SECRET  not set"
    text.should contain "  url             postgres://admin:***@db.internal:5432/app"
    text.should contain "[Enter] Read it again"
  end

  it "reads azu config's plain output back into sections, keys with spaces included" do
    sections = AzuCLI::DevServer::Hud.config_sections("SERVER\n  loopback only    true\n  port            4000\n\nTLS\n  enabled         false\n")
    sections.should eq [{"SERVER", [{"loopback only", "true"}, {"port", "4000"}]}, {"TLS", [{"enabled", "false"}]}]
    AzuCLI::DevServer::Hud.config_tone("not set").should eq TUI::Token::Amber
    AzuCLI::DevServer::Hud.config_tone("true").should eq TUI::Token::Green
    AzuCLI::DevServer::Hud.config_tone("50.0ms").should eq TUI::Token::Cyan
    AzuCLI::DevServer::Hud.config_tone("sqlite3://./db/app.db").should eq TUI::Token::Blue
    AzuCLI::DevServer::Hud.config_tone("127.0.0.1").should eq TUI::Token::Blue
    AzuCLI::DevServer::Hud.config_tone("10000").should eq TUI::Token::Cyan
    AzuCLI::DevServer::Hud.config_tone("development").should eq TUI::Token::Text
  end

  it "fits every tab in the tab bar, narrowing the gaps" do
    screen = control_hud([] of String)
    render(screen, 100, 20).should contain "[7] Log  [8] Config"
    render(screen, 120, 20).should contain "[7] Log   [8] Config"
  end

  it "says why azu config failed on the Config tab" do
    screen = control_hud([] of String)
    screen.update(key('8'))
    screen.update(Ev::ControlFinished.new("config", 1, "In src/blog.cr:3:1\nError: undefined constant Blog::Oops\n", 9.0))
    text = render(screen)
    text.should contain "✖ Error: undefined constant Blog::Oops"
  end

  it "scrolls a long configuration" do
    screen = control_hud([] of String)
    screen.update(key('8'))
    output = (1..40).map { |n| "SECTION#{n}\n  key#{n}  value#{n}\n" }.join("\n")
    screen.update(Ev::ControlFinished.new("config", 0, output, 3.0))
    text = render(screen, 120, 20)
    text.should contain "│ SECTION1 "
    text.should contain "of 119"
    press(screen, TUI::KeyCode::End)
    text = render(screen, 120, 20)
    text.should contain "value40"
    text.should_not contain "value1 "
  end

  it "re-runs the tests after each build once w is on" do
    requested = [] of String
    screen = control_hud(requested)
    screen.update(key('2'))
    screen.update(key('w'))
    screen.test_watch?.should be_true
    requested.clear
    screen.update(Ev::BuildFinished.new(true, 4.0, ""))
    requested.should contain "test"
  end

  it "draws the list with each command's mark and outcome, and the selected command's output" do
    requested = [] of String
    screen = control_hud(requested)
    screen.update(key('2'))
    screen.update(Ev::ControlStarted.new("routes"))
    screen.update(Ev::ControlFinished.new("doctor", 0, "ok    crystal   Crystal 1.22.1\nwarn  database  missing\n\n8 ok, 1 warnings, 0 failures\n", 1.2))
    text = render(screen)
    text.should contain "╭─ Commands "
    text.should contain "HEALTH"
    text.should contain "▸ ▲ doctor"
    text.should contain "8 ok · 1 warn · 0 fail"
    text.should contain "running"
    text.should contain "╭─ azu doctor "
    text.should contain "warn  database  missing"
    text.should contain "runs at start, when .env or shard.yml changes"
    text.should contain "[Enter] Run"
  end

  it "sums up the commands on the overview" do
    requested = [] of String
    screen = control_hud(requested)
    screen.update(Ev::ControlFinished.new("doctor", 0, "9 ok, 0 warnings, 0 failures", 1.0))
    screen.update(Ev::ControlFinished.new("db:status", 0, "Total: 2 migrations (1 applied, 1 pending)", 1.0))
    text = render(screen)
    text.should contain "1 need a look · [2]"
    text.should contain "✔ doctor"
    text.should contain "▲ db:status"
  end
end

describe AzuCLI::DevServer::Control::Runner do
  it "queues from the dashboard's fiber without blocking it, then runs the commands one at a time" do
    events = Channel(AzuCLI::UI::Message).new(64)
    runner = Control::Runner.new(->(message : AzuCLI::UI::Message) { events.send(message); nil }, executable: "/bin/echo")
    queued = Channel(Bool).new(1)
    spawn do
      3.times { |index| runner.enqueue(Control::Command.new("c#{index}", "G", ["hello"])) }
      runner.enqueue(Control::Command.new("c0", "G", ["again"])).should be_false
      queued.send(true)
    end
    select
    when queued.receive
    when timeout(2.seconds)
      fail "enqueue blocked"
    end

    runner.start
    finished = [] of Ev::ControlFinished
    until finished.size == 3
      select
      when message = events.receive
        finished << message if message.is_a?(Ev::ControlFinished)
      when timeout(5.seconds)
        fail "the runner did not run the queue"
      end
    end
    runner.stop
    finished.map(&.id).should eq ["c0", "c1", "c2"]
    finished.first.output.should eq "hello"
    finished.first.exit_code.should eq 0
  end
end

describe "AzuCLI::DevServer::Control::Runner while the console compiles" do
  it "holds the next command until it is no longer paused" do
    events = Channel(AzuCLI::UI::Message).new(64)
    runner = Control::Runner.new(->(message : AzuCLI::UI::Message) { events.send(message); nil }, executable: "/bin/echo")
    runner.paused = true
    runner.start
    runner.enqueue(Control::Command.new("c0", "G", ["hello"]))
    events.receive.should be_a Ev::ControlQueued
    select
    when message = events.receive
      fail "ran while paused: #{message}"
    when timeout(600.milliseconds)
    end
    runner.paused = false
    select
    when message = events.receive
      message.should be_a Ev::ControlStarted
    when timeout(3.seconds)
      fail "did not run once resumed"
    end
    runner.stop
  end
end
