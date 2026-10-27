require "../../spec_helper"

private alias TUI = AzuCLI::UI
private alias Ev = AzuCLI::DevServer::Events
private alias Control = AzuCLI::DevServer::Control

private class Clock
  property now = Time.instant
end

private def control_hud(requested : Array(String), clock = Clock.new)
  AzuCLI::DevServer::Hud.new("blog", "4000", "development", "watching src", clock: -> { clock.now }, directory: "/work/blog",
    commands: Control.catalog("zsh"), on_control: ->(command : Control::Command) { requested << command.id; nil })
end

private def key(char : Char)
  TUI::Key.new(TUI::KeyCode::Char, char)
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
    Control.outcome("config:validate", 0, "WARNING: Warnings (1):\n  - Templates path does not exist: ./x\n[19:08:51] [INFO ] Configuration validation completed with 1 warning(s)\n").should eq({Control::Status::Warn, "1 warning: Templates path does not exist: ./x"})
    Control.outcome("config:env", 0, "AZU_ENV                  Environment\nAZU_DEBUG                Debug mode\n\nUse --show to see current values\n").should eq({Control::Status::Ok, "2 variables"})
  end

  it "says why a run failed with its error line, without the log prefix" do
    Control.outcome("db:migrate", 1, "[19:00:00] [INFO ] Validating\nERROR: Database 'blog' does not exist.\n").should eq({Control::Status::Fail, "Database 'blog' does not exist."})
    Control.outcome("config:show", 0, "[19:08:51] [INFO ] Configuration displayed successfully\n").should eq({Control::Status::Ok, "Configuration displayed successfully"})
  end

  it "prints the completion script of the login shell, bash when it is another" do
    Control.shell({"SHELL" => "/bin/zsh"}).should eq "zsh"
    Control.shell({"SHELL" => "/usr/bin/tcsh"}).should eq "bash"
    Control.catalog("fish").find!(&.id.==("completion")).args.should eq ["completion", "fish"]
  end
end

describe "AzuCLI::DevServer::Hud control plane" do
  it "runs the start commands on the first event, and each command again when what it reads changes" do
    requested = [] of String
    screen = control_hud(requested)
    screen.update(TUI::Tick.new(Time.instant))
    requested.should eq ["doctor", "config:validate", "db:status", "config:show", "config:env", "version"]

    requested.clear
    screen.update(Ev::BuildStarted.new)
    screen.update(Ev::BuildFinished.new(true, 4.0, ""))
    requested.should eq ["routes"]

    requested.clear
    %w[doctor config:validate db:status config:show config:env version routes].each do |id|
      screen.update(Ev::ControlFinished.new(id, 0, "", 0.5))
    end
    screen.update(Ev::Changed.new(["src/db/migrations/20261027_create_posts.cr"], AzuCLI::DevServer::Action::Rebuild))
    requested.should eq ["db:status"]
    requested.clear
    screen.update(Ev::Changed.new([".env.local"], AzuCLI::DevServer::Action::Restart))
    requested.should eq ["doctor", "config:validate", "config:show", "config:env"]
  end

  it "does not queue a command that is already queued or running" do
    requested = [] of String
    screen = control_hud(requested)
    screen.update(TUI::Tick.new(Time.instant))
    requested.clear
    screen.update(Ev::Changed.new([".env"], AzuCLI::DevServer::Action::Restart))
    requested.should be_empty
  end

  it "runs the selected command on Enter, and a command that changes things only after y" do
    requested = [] of String
    screen = control_hud(requested)
    screen.update(key('2'))
    screen.tab.commands?.should be_true
    screen.update(Ev::ControlFinished.new("db:status", 0, "Total: 1 migrations (0 applied, 1 pending)", 1.0))
    requested.clear
    5.times { screen.update(TUI::Key.new(TUI::KeyCode::Down)) } # db:migrate
    screen.commands[screen.selected].id.should eq "db:migrate"
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
    text.should contain "runs at start, when .env, shard.yml or the CLI config changes"
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
