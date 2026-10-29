require "./base"
require "../joobq/controller"

module AzuCLI::Commands
  class JoobQ < Base
    def initialize
      super("joobq", "Manage JoobQ queues, workflow executions and dead letters")
    end

    def execute : Result
      return show_help if has_option?("help")
      boot = value_option("boot").presence || "src/initializers/joobq.cr"
      return error("JoobQ boot file not found: #{boot}. Use --boot PATH (configure stores, do not start workers).") unless File.file?(boot)
      terminal = AzuCLI::UI::Terminal.detect
      unless terminal.tty? && STDIN.tty? && terminal.interactive?
        return error("azu joobq requires an interactive terminal")
      end
      AzuCLI::JoobQDashboard::ProcessSource.open(boot) do |source|
        controller : AzuCLI::JoobQDashboard::Controller? = nil
        screen = AzuCLI::JoobQDashboard::Screen.new(->(id : String) { controller.try(&.replay(id)); nil })
        program = AzuCLI::UI::Program.new(screen, terminal, AzuCLI::UI::FullScreenRenderer.new(terminal.output))
        running = AzuCLI::JoobQDashboard::Controller.new(source, ->(event : AzuCLI::UI::Message) { program.send(event) })
        controller = running
        begin
          {Signal::INT, Signal::TERM, Signal::HUP}.each do |signal|
            signal.trap do
              program.events.send(AzuCLI::UI::Key.new(AzuCLI::UI::KeyCode::CtrlC)) rescue nil
            end
          end
          running.start
          program.run
        ensure
          running.stop
        end
      end
      success
    rescue ex
      error("JoobQ dashboard failed: #{ex.message}")
    end

    def show_help : Result
      stdout.puts "Usage: azu joobq [--boot PATH]"
      stdout.puts "The boot file configures JoobQ and optional workflow/history adapters without starting workers."
      stdout.puts "1–3 tabs; Tab switches pane; arrows/PgUp/PgDn scroll; r then y replays a selected dead letter."
      success
    end
  end
end
