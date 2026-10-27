require "./base"
require "../generate_plan"
require "../ui"

module AzuCLI
  module Commands
    # Reverts the last `azu generate` that wrote through the preview: deletes the files it created and restores the
    # files it changed, except those edited since.
    class Undo < Base
      OPTIONS = ["dry-run", "list", "ui"]

      def initialize
        super("undo", "Revert the files of the last azu generate")
      end

      def execute : Result
        return show_help_result if has_option?("help")
        if option = unknown_option(OPTIONS)
          return usage_error("Unknown option #{option}. Run 'azu undo --help'")
        end

        records = AzuCLI::Undo.records(Dir.current)
        return list(records) if has_option?("list")
        return Result.error("Nothing to undo: no azu generate wrote here through its preview") if records.empty?

        ui = UI::Reporter.build(has_option?("ui") ? get_option("ui") : nil, stdout)
        record = records.first
        manifest = AzuCLI::Undo.manifest(record)
        steps = has_option?("dry-run") ? AzuCLI::Undo.steps(record, Dir.current) : AzuCLI::Undo.apply(record, Dir.current)
        lines = steps.map do |step|
          if step.ok
            [UI::Seg["✔ ", UI::Token::Green], UI::Seg["#{step.action} ", UI::Token::Muted], UI::Seg[step.path]]
          else
            [UI::Seg["▲ ", UI::Token::Amber], UI::Seg["#{step.path}: ", UI::Token::Text], UI::Seg[step.reason.to_s, UI::Token::Muted]]
          end
        end
        verb = has_option?("dry-run") ? "Would undo" : "Undid"
        ui.panel("#{verb}: #{manifest.command}", lines, badge: manifest.at, tone: steps.all?(&.ok) ? UI::Token::Green : UI::Token::Amber)
        success
      end

      private def list(records : Array(String)) : Result
        if records.empty?
          stdout.puts "No undo records for this project"
        else
          records.each do |record|
            manifest = AzuCLI::Undo.manifest(record)
            stdout.puts "#{manifest.at}  #{manifest.files.size.to_s.rjust(3)} files  #{manifest.command}"
          end
        end
        success
      end

      private def show_help_result : Result
        show_help
        success
      end

      def show_help
        stdout.puts <<-HELP
          Usage: azu undo [options]

          Reverts the last `azu generate` that wrote its files through the preview (on a terminal, or with --yes):
          deletes the files it created and puts back the files it changed. A file you edited since it was generated
          is left as it is and listed. The records live outside the project, in $XDG_STATE_HOME/azu (default
          ~/.local/state/azu).

          Options:
            --dry-run   Show what it would do
            --list      List the records, newest first
            --ui MODE   rich or plain output
            --help      Show this help
          HELP
      end
    end
  end
end
