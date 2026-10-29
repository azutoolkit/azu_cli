require "../generate_preview"

module AzuCLI
  module Commands
    # `azu generate` with a preview: the generator runs in a copy of the project first, and what it would write is
    # shown (a menu and a file browser on a terminal, a list with --dry-run) before the same files are copied in.
    class Generate < Base
      @dry_run = false
      @yes = false
      @check = false
      @ui_mode : String? = nil

      # {type, what it makes, an example of the rest of the command line}
      MENU = [
        {"scaffold", "model, endpoints, requests, pages", "post title:string body:text"},
        {"model", "CQL model + its migration", "post title:string body:text"},
        {"endpoint", "Endpoint(Request, Response)", "posts index show"},
        {"service", "business logic", "post_publisher publish:Bool"},
        {"page", "page response + template", "post_card title:string"},
        {"request", "request contract", "post_search query:string"},
        {"component", "Static HTML component", "user_card name:string"},
        {"spark", "Spark live component", "counter count:int32 --page"},
        {"spark:scaffold", "Live database CRUD", "product name:string price_cents:int32"},
        {"channel", "WebSocket channel", "chat"},
        {"job", "JoobQ job", "publish_post post_id:int64"},
        {"migration", "schema change", "add_slug_to_posts slug:string"},
        {"mailer", "mailer", "welcome"},
        {"middleware", "HTTP handler", "request_timer"},
        {"auth", "session authentication", ""},
        {"joobq", "JoobQ setup", ""},
      ]

      PREVIEW_FLAGS = {"--dry-run", "--yes", "--check"}

      # Takes --ui out of the arguments (its value would otherwise read as an attribute).
      private def without_ui_flags(args : Array(String)) : Array(String)
        result = [] of String
        skip = false
        args.each_with_index do |arg, index|
          if skip
            skip = false
          elsif arg == "--ui"
            @ui_mode = args[index + 1]?
            skip = true
          elsif arg.starts_with?("--ui=")
            @ui_mode = arg.lchop("--ui=")
          else
            result << arg
          end
        end
        result
      end

      # The result when the preview handled the command; nil to generate directly (a pipe, CI, --ui plain without
      # --dry-run or --check, `validate`, or the shadow run itself).
      private def preview_flow : Result?
        return nil if ENV[GeneratePlan::SHADOW_ENV]?
        if (mode = @ui_mode) && !{"rich", "plain"}.includes?(mode)
          return usage_error("--ui must be rich or plain")
        end

        ui = UI::Reporter.build(@ui_mode, stdout)
        interactive = interactive?(ui)
        args = @all_args.reject { |arg| PREVIEW_FLAGS.includes?(arg) }
        type = args.find { |arg| !arg.starts_with?("-") } || ""
        if type.empty?
          return nil unless interactive
          chosen = run_menu(ui)
          return Result.error("Cancelled: nothing was written") unless chosen
          args = chosen + args
          type = chosen.first
        end
        return nil if type == "validate"
        return nil unless @dry_run || @check || interactive

        run_plan(args, ui, interactive)
      end

      # Whether `azu generate` without arguments can show its menu: a person at a terminal.
      def self.menu_available? : Bool
        return false if ENV["AZU_UI"]? == "plain" || ENV["CI"]?.presence
        STDIN.tty? && STDOUT.tty? && File.exists?("/dev/tty") && UI::Reporter.rich?(UI::Terminal.detect)
      end

      private def interactive?(ui : UI::Reporter) : Bool
        ui.rich? && STDIN.tty? && ui.as(UI::Rich).terminal.interactive?
      end

      private def run_plan(args : Array(String), ui : UI::Reporter, interactive : Bool) : Result
        built = GeneratePlan.build(args)
        if built.is_a?(String)
          built.lines.map(&.gsub(/\e\[[0-9;]*m/, "")).reject(&.blank?).last(12).each { |line| ui.note(line) }
          return Result.error("The generator stopped: nothing was written")
        end

        plan = built
        begin
          if plan.empty?
            ui.note("Nothing to write: every file it generates is already there and the same")
            return success("Nothing to write")
          end
          title = args.reject(&.starts_with?("-")).first(2).join(' ')
          if interactive && !@dry_run && !@yes
            return Result.error("Cancelled: nothing was written") unless browse(plan, title, ui)
          else
            failure = @check ? check(plan, ui) : nil
            show_plan(plan, ui, diffs: @dry_run)
            return success("Dry run: nothing was written") if @dry_run
            return Result.error("The project does not compile with these files: nothing was written") if failure
          end
          plan.apply("azu generate #{args.join(' ')}")
          written(plan, ui)
          success("Generated #{title}")
        ensure
          plan.cleanup
        end
      end

      # The file browser; true when the person chose to write. The type-check runs while they look.
      private def browse(plan : GeneratePlan, title : String, ui : UI::Reporter) : Bool
        terminal = ui.as(UI::Rich).terminal
        screen = GeneratePreview.new(plan, title, checking: true)
        renderer = UI::InlineRenderer.new(terminal.output, terminal.theme.color?)
        program = UI::Program.new(screen, terminal, renderer)
        spawn { program.send(GeneratePreview::TypeChecked.new(plan.type_check)) }
        program.run
        renderer.clear
        screen.confirmed?
      end

      private def check(plan : GeneratePlan, ui : UI::Reporter) : String?
        ui.task("Type-check", "crystal build --no-codegen") do |task|
          error = plan.type_check
          if error
            task.fail(error.lines.find(&.starts_with?("Error:")) || "does not compile")
          else
            task.finish(detail: "compiles with the generated files")
          end
          error
        end
      end

      private def show_plan(plan : GeneratePlan, ui : UI::Reporter, diffs : Bool) : Nil
        lines = [] of Array(UI::Seg)
        plan.entries.each do |entry|
          lines << file_line(entry)
          next unless diffs && entry.kind.changed?
          entry.diff.first(16).each do |line|
            tone = line.op == '+' ? UI::Token::Green : (line.op == '-' ? UI::Token::Red : UI::Token::Muted)
            lines << [UI::Seg["    #{line.op} ", tone], UI::Seg[line.text, tone]]
          end
        end
        ui.panel("Plan · #{plan.new_files.size} new · #{plan.changed_files.size} changed", lines)
      end

      private def written(plan : GeneratePlan, ui : UI::Reporter) : Nil
        lines = plan.entries.map { |entry| file_line(entry) }
        lines << [] of UI::Seg
        lines << [UI::Seg["▸ ", UI::Token::Purple], UI::Seg["azu undo", UI::Token::Text], UI::Seg[" reverts these files (those you have not edited since)", UI::Token::Muted]]
        ui.panel("Wrote #{plan.entries.size} file#{plan.entries.size == 1 ? "" : "s"}", lines, badge: "✔", tone: UI::Token::Green)
      end

      private def file_line(entry : GeneratePlan::Entry) : Array(UI::Seg)
        if entry.kind.new?
          [UI::Seg["+ ", UI::Token::Green], UI::Seg[entry.path], UI::Seg["  #{entry.lines} lines", UI::Token::Muted]]
        else
          [UI::Seg["~ ", UI::Token::Amber], UI::Seg[entry.path], UI::Seg["  changed", UI::Token::Muted]]
        end
      end

      # The generator menu: a generator, then its name and fields. nil when cancelled.
      private def run_menu(ui : UI::Reporter) : Array(String)?
        type_step = UI::ChoiceStep.new("Generator", "What are we building?",
          MENU.map { |(type, description, example)| UI::Option.new(type, type, description, example.empty? ? "No name needed." : "e.g. #{example}") })
        nameless = -> { NAMELESS_GENERATORS.includes?(type_step.value) }
        text_step = UI::TextStep.new("Name", "Name, then fields or actions (name:type …)",
          validate: ->(value : String) { value.strip.empty? ? "Give it a name, e.g. post title:string" : nil }, skip: nameless)
        command = -> { (["azu", "generate", type_step.value] + (nameless.call ? [] of String : text_step.value.split)).join(' ') }
        plan = -> {
          example = MENU.find { |entry| entry[0] == type_step.value }.try(&.[2]) || ""
          [[UI::Seg["You will see every file it writes,", UI::Token::Muted]],
           [UI::Seg["and the diff of every file it changes,", UI::Token::Muted]],
           [UI::Seg["before anything is written.", UI::Token::Muted]],
           [] of UI::Seg,
           [UI::Seg["e.g.  ", UI::Token::Muted], UI::Seg["azu g #{type_step.value} #{example}".strip]]]
        }
        project = File.basename(Dir.current)
        wizard = UI::Wizard.new("generate", project, [type_step, text_step] of UI::Step, plan: plan, command: command)
        terminal = ui.as(UI::Rich).terminal
        renderer = UI::InlineRenderer.new(terminal.output, terminal.theme.color?)
        UI::Program.new(wizard, terminal, renderer).run
        renderer.clear
        return nil unless wizard.outcome.confirmed?

        [type_step.value] + (nameless.call ? [] of String : text_step.value.split)
      end
    end
  end
end
