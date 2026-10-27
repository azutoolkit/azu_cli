require "../../spec_helper"
require "../../support/command_helpers"

include CommandHelpers

private class StubSystem < AzuCLI::Diagnostics::System
  def initialize(@crystal : String = "Crystal 1.22.1 [abc] (2026-09-01)", @check_status : Int32 = 0)
  end

  def capture(command : String, args : Array(String), chdir : String) : {Int32, String}?
    case ([command] + args).join(" ")
    when "crystal --version"        then {0, @crystal}
    when "shards --version"         then {0, "Shards 0.19.1"}
    when "shards check"             then {@check_status, ""}
    when "docker --version"         then {0, "Docker"}
    when "git check-ignore -q .env" then {0, ""}
    end
  end

  def tcp_reachable?(host : String, port : Int32, timeout : Time::Span) : Bool
    true
  end

  def port_state(port : Int32) : AzuCLI::Diagnostics::PortState
    AzuCLI::Diagnostics::PortState::Free
  end
end

private def with_system(system, &)
  original_system = AzuCLI::Commands::Doctor.system
  original_environment = AzuCLI::Commands::Doctor.environment
  AzuCLI::Commands::Doctor.system = system
  AzuCLI::Commands::Doctor.environment = ->(name : String) { nil.as(String?) }
  yield
ensure
  AzuCLI::Commands::Doctor.system = original_system.not_nil!
  AzuCLI::Commands::Doctor.environment = original_environment.not_nil!
end

describe AzuCLI::Commands::Doctor do
  it "prints one line per check with hints and a summary, and exits 0 with warnings only" do
    in_tmp_project(files: {"shard.lock" => "version: 2.0\n"}) do
      with_system(StubSystem.new) do
        result, output = run_command(AzuCLI::Commands::Doctor.new, [] of String)

        result.success?.should be_true
        output.should contain("ok    crystal")
        output.should contain("warn  database")
        output.should contain("hint: set DATABASE_URL")
        output.lines.last.should eq "8 ok, 1 warnings, 0 failures"
      end
    end
  end

  it "exits 1 when a check fails" do
    in_tmp_project do
      with_system(StubSystem.new(crystal: "Crystal 1.10.0 [abc] (2024-01-01)")) do
        result, output = run_command(AzuCLI::Commands::Doctor.new, [] of String)

        result.success?.should be_false
        result.exit_code.should eq 1
        output.should contain("fail  crystal")
      end
    end
  end

  it "prints JSON with --json: id, status, message and hint per check, and a summary" do
    in_tmp_project do
      with_system(StubSystem.new(check_status: 1)) do
        result, output = run_command(AzuCLI::Commands::Doctor.new, ["--json"])
        json = JSON.parse(output)

        result.exit_code.should eq 1
        checks = json["checks"].as_a
        checks.map(&.["id"].as_s).should eq %w(crystal shards dependencies database env secrets port docker gitignore)
        checks.each { |check| %w(ok warn fail).should contain(check["status"].as_s) }
        dependencies = checks.find! { |check| check["id"] == "dependencies" }
        dependencies["status"].as_s.should eq "fail"
        dependencies["hint"].as_s.should eq "run 'shards install'"
        checks.first["hint"].raw.should be_nil
        json["summary"]["fail"].as_i.should eq 1
      end
    end
  end

  it "exits 2 for an unknown option and documents its options" do
    result, _ = run_command(AzuCLI::Commands::Doctor.new, ["--fix"])
    result.exit_code.should eq 2

    _, help = run_command(AzuCLI::Commands::Doctor.new, ["--help"])
    AzuCLI::Commands::Doctor::OPTIONS.each { |option| help.should contain("--#{option}") }
    %w(crystal shards dependencies database env secrets port docker gitignore).each { |id| help.should contain(id) }
  end

  it "keeps the CLI's own log lines off stdout" do
    AzuCLI::Commands::Doctor.new.machine_output?.should be_true
    AzuCLI::Commands::Routes.new.machine_output?.should be_true
  end

  it "is registered with the CLI" do
    AzuCLI::CLI.new.command_names.should contain("doctor")
  end
end

describe "AzuCLI::Commands::Doctor on a terminal" do
  it "draws the checks as a card, with a mark per check, the hints and the counts" do
    in_tmp_project(files: {"shard.lock" => "version: 2.0\n"}) do
      with_system(StubSystem.new) do
        card = IO::Memory.new
        command = AzuCLI::Commands::Doctor.new
        command.ui = AzuCLI::UI::Rich.new(AzuCLI::UI::Terminal.fake(card, columns: 100))
        result, output = run_command(command, [] of String)

        result.success?.should be_true
        output.should be_empty
        text = card.to_s
        text.should contain "╭─ Doctor"
        text.should contain "8 ok · 1 warn · 0 fail"
        text.should contain "│ ✔ crystal"
        text.should contain "│ ▲ database"
        text.should contain "▸ set DATABASE_URL"
      end
    end
  end
end
