require "./base"
require "../dev_server/mission_control"
require "../remote/monitor"

module AzuCLI::Commands
  class Connect < Base
    def initialize
      super("connect", "Monitor production over verified SSH with a read-only local HUD")
    end

    def execute : Result
      return show_help if has_option?("help")
      if option = unknown_option(%w(ssh snapshot))
        return usage_error("Unknown option #{option}")
      end
      target = Remote::Target.new(value_option("ssh") || "", value_option("snapshot") || "")
      target.validate!
      terminal = UI::Terminal.detect
      return error("azu connect needs an interactive terminal") unless terminal.interactive? && STDIN.tty?
      # No project boot, .env, catalog, compiler, interpreter or local runner.
      classic = DevServer::Hud.new(target.host, "", "production", "SSH snapshots", commands: [] of DevServer::Control::Command)
      screen = DevServer::MissionControl.new(classic, target.host, terminal.reduced_motion?, read_only: true)
      program = UI::Program.new(screen, terminal, UI::FullScreenRenderer.new(terminal.output))
      monitor = Remote::Monitor.new(Remote::Reader.new(target), ->(message : UI::Message) { program.send(message) })
      begin
        {Signal::INT, Signal::TERM, Signal::HUP}.each do |signal|
          signal.trap { program.events.send(UI::Key.new(UI::KeyCode::CtrlC)) rescue nil }
        end
        monitor.start
        program.run
      ensure
        monitor.stop
        {Signal::INT, Signal::TERM, Signal::HUP}.each(&.reset)
      end
      success
    rescue ex : ArgumentError
      usage_error(ex.message || "Invalid connection options")
    rescue ex : IO::Error
      error("Connection failed: #{ex.message}")
    end

    def show_help : Result
      stdout.puts "Usage: azu connect --ssh monitor@production --snapshot /run/azu/monitor.json"
      stdout.puts "Verified SSH host keys and key-based authentication are required. Read-only metrics; no remote commands."
      stdout.puts "Configure a restricted monitoring key and snapshot publisher; see docs/command-reference/azu-connect.md."
      success
    end
  end
end
