require "json"

module AzuCLI
  module UI
    # One step of a command (write the files, install the shards). Its reporter draws it as it changes.
    class Task
      enum State
        Running
        Done
        Failed
        Skipped
      end

      getter name : String
      getter detail : String
      getter note : String?
      getter state = State::Running
      getter done : Int32?
      getter total : Int32?
      getter started_at = Time.instant
      @seconds : Float64?

      def initialize(@name : String, @detail : String, @reporter : Reporter)
      end

      def running? : Bool
        state.running?
      end

      def seconds : Float64
        @seconds || (Time.instant - started_at).total_seconds
      end

      def detail=(value : String) : Nil
        @detail = value
        @reporter.updated(self)
      end

      # A second, muted line under the task while it runs ("resolving cql").
      def note=(value : String?) : Nil
        @note = value
        @reporter.updated(self)
      end

      # `done` of `total` (nil total: a count with no known end).
      def progress(done : Int32, total : Int32? = nil) : Nil
        @done, @total = done, total
        @reporter.updated(self)
      end

      def fail(detail : String? = nil) : Nil
        finish(State::Failed, detail)
      end

      def skip(detail : String? = nil) : Nil
        finish(State::Skipped, detail)
      end

      def finish(state : State = State::Done, detail : String? = nil) : Nil
        return unless running?

        @state = state
        @detail = detail if detail
        @note = nil
        @seconds = (Time.instant - started_at).total_seconds
        @reporter.finished(self)
      end
    end

    # How a command shows its progress: `Rich` (a live card on a terminal), `Plain` (one line per finished step: pipes,
    # CI, NO_COLOR) or `Json` (NDJSON events for editors and CI). Commands talk to this, never to escape codes.
    abstract class Reporter
      abstract def started(task : Task) : Nil
      abstract def updated(task : Task) : Nil
      abstract def finished(task : Task) : Nil
      abstract def note(message : String) : Nil
      abstract def warn(message : String) : Nil
      # A card of lines: a summary, next steps.
      abstract def panel(title : String, lines : Array(Array(Seg)), badge : String? = nil, tone : Token = Token::Purple) : Nil

      MODES = {"rich", "plain", "json"}

      # The reporter for `mode` ("rich", "plain", "json"; nil or "auto" decides from the terminal and the environment).
      def self.build(mode : String? = nil, output : IO = STDOUT, terminal : Terminal? = nil, env = ENV) : Reporter
        mode = mode.presence || env["AZU_UI"]?.presence
        case mode
        when "json"  then Json.new(output)
        when "plain" then Plain.new(output)
        when "rich"  then Rich.new(terminal || Terminal.detect(output.as?(IO::FileDescriptor) || STDOUT, env))
        else
          terminal ||= output.as?(IO::FileDescriptor).try { |fd| Terminal.detect(fd, env) }
          terminal && rich?(terminal, env) ? Rich.new(terminal) : Plain.new(output)
        end
      end

      def self.rich?(terminal : Terminal, env = ENV) : Bool
        terminal.tty? && terminal.depth != ColorDepth::None && !env["CI"]?.presence && terminal.columns >= 40
      end

      def rich? : Bool
        false
      end

      # Runs the block as a named task: done when it returns (unless it finished the task itself), failed when it
      # raises (the exception goes on).
      def task(name : String, detail : String = "", &)
        task = Task.new(name, detail, self)
        started(task)
        begin
          result = yield task
        rescue ex
          task.fail(ex.message || ex.class.name)
          raise ex
        end
        task.finish if task.running?
        result
      end

      # Tasks drawn together under one title (Rich: one card).
      def group(title : String, &)
        yield
      end
    end

    # One line per finished task, no escape codes.
    class Plain < Reporter
      MARKS = {Task::State::Done => "[ok]", Task::State::Failed => "[!!]", Task::State::Skipped => "[--]", Task::State::Running => "[..]"}

      def initialize(@output : IO = STDOUT)
      end

      def started(task : Task) : Nil
      end

      def updated(task : Task) : Nil
      end

      def finished(task : Task) : Nil
        line = "#{MARKS[task.state]} #{task.name.ljust(12)} #{task.detail}".rstrip
        @output.puts "#{line.ljust(48)} #{Widgets.duration(task.seconds)}"
      end

      def note(message : String) : Nil
        @output.puts message
      end

      def warn(message : String) : Nil
        @output.puts "warning: #{message}"
      end

      def panel(title : String, lines : Array(Array(Seg)), badge : String? = nil, tone : Token = Token::Purple) : Nil
        @output.puts [title, badge].compact.join(" · ")
        lines.each { |segs| @output.puts "  #{segs.join(&.text)}".rstrip }
      end
    end

    # NDJSON events, version 1.
    class Json < Reporter
      def initialize(@output : IO = STDOUT)
      end

      def started(task : Task) : Nil
        emit({v: 1, event: "task.start", task: task.name, detail: task.detail})
      end

      def updated(task : Task) : Nil
        emit({v: 1, event: "task.progress", task: task.name, detail: task.detail, done: task.done, total: task.total}) if task.done
      end

      def finished(task : Task) : Nil
        emit({v: 1, event: "task.done", task: task.name, detail: task.detail, ok: !task.state.failed?, state: task.state.to_s.downcase, seconds: task.seconds.round(3)})
      end

      def note(message : String) : Nil
        emit({v: 1, event: "note", message: message})
      end

      def warn(message : String) : Nil
        emit({v: 1, event: "warning", message: message})
      end

      def panel(title : String, lines : Array(Array(Seg)), badge : String? = nil, tone : Token = Token::Purple) : Nil
        emit({v: 1, event: "panel", title: title, badge: badge, lines: lines.map(&.join(&.text).rstrip)})
      end

      private def emit(payload) : Nil
        @output.puts payload.to_json
        @output.flush
      end
    end

    # A live card on the terminal: running tasks spin, finished ones get ✔/✖ and their time. The card stays in the
    # scrollback when the group ends.
    class Rich < Reporter
      MAX_WIDTH    = 96
      MIN_INTERVAL = 50.milliseconds

      getter terminal : Terminal
      @tasks = [] of Task
      @title = "azu"
      @ticking = false
      @last_draw : Time::Instant?

      def initialize(@terminal : Terminal)
        @styles = StyleTable.new(terminal.theme)
        @renderer = InlineRenderer.new(terminal.output, terminal.theme.color?)
      end

      def rich? : Bool
        true
      end

      def group(title : String, &)
        @title = title
        @tasks = [] of Task
        begin
          yield
        ensure
          draw
          @renderer.commit
          @tasks = [] of Task
          @title = "azu"
        end
      end

      def started(task : Task) : Nil
        @tasks << task
        draw
        start_ticker
      end

      def updated(task : Task) : Nil
        last = @last_draw
        draw if last.nil? || Time.instant - last >= MIN_INTERVAL
      end

      def finished(task : Task) : Nil
        draw
      end

      def note(message : String) : Nil
        above { |output| output.puts colored(message, Token::Muted) }
      end

      def warn(message : String) : Nil
        above { |output| output.puts colored("#{terminal.glyphs.warn} #{message}", Token::Amber) }
      end

      def panel(title : String, lines : Array(Array(Seg)), badge : String? = nil, tone : Token = Token::Purple) : Nil
        @renderer.commit
        width = card_width
        frame = Frame.new(width, lines.size + 4, @styles)
        inner = frame.card(frame.area, title, badge, border: tone == Token::Purple ? Token::Faint : tone, title_color: tone, badge_color: tone)
        lines.each_with_index { |segs, index| frame.line(inner.x, inner.y + 1 + index, segs, inner.w) }
        @renderer.flush(frame)
        @renderer.commit
      end

      # Prints something above the live card, then draws the card again below it.
      private def above(&) : Nil
        @renderer.clear
        yield terminal.output
        draw unless @tasks.empty?
      end

      private def colored(text : String, token : Token) : String
        return text unless terminal.theme.color?
        "#{@styles.sgr(@styles.id(Style.new(token)))}#{text}\e[0m"
      end

      private def card_width : Int32
        Math.min(terminal.columns - 1, MAX_WIDTH)
      end

      private def draw : Nil
        return if @tasks.empty?

        @last_draw = Time.instant
        rows = @tasks.sum { |task| task.running? && task.note ? 2 : 1 }
        frame = Frame.new(card_width, rows + 2, @styles)
        inner = frame.card(frame.area, @title, badge: running? ? nil : summary)
        y = inner.y
        @tasks.each do |task|
          draw_task(frame, task, inner, y)
          y += 1
          if task.running? && (note = task.note)
            frame.text(inner.x + 18, y, note, Token::Muted, max: inner.w - 18)
            y += 1
          end
        end
        @renderer.flush(frame)
      end

      private def draw_task(frame : Frame, task : Task, inner : Rect, y : Int32) : Nil
        g = terminal.glyphs
        mark, tone = case task.state
                     in .running? then {Widgets.spinner(g, reduced_motion: terminal.reduced_motion?), Token::Cyan}
                     in .done?    then {g.ok, Token::Green}
                     in .failed?  then {g.fail, Token::Red}
                     in .skipped? then {g.off, Token::Muted}
                     end
        frame.text(inner.x, y, mark, tone)
        frame.text(inner.x + 2, y, task.name, task.running? ? Token::Cyan : Token::Text, max: 15)
        time = Widgets.duration(task.seconds)
        time_x = inner.right - Width.of(time)
        x = inner.x + 18
        room = time_x - 2 - x
        if task.running? && (done = task.done)
          if total = task.total
            full, empty = Widgets.meter(total > 0 ? done / total : 0.0, 20, g.bar_full, g.bar_empty)
            x = frame.gradient(x, y, full)
            x = frame.text(x, y, empty, Token::Faint)
            x = frame.text(x + 2, y, done.to_s, Token::Cyan)
            x = frame.text(x, y, "/#{total}", Token::Muted)
          else
            x = frame.text(x, y, "#{done} ", Token::Cyan)
          end
          x += 1
          room = time_x - 2 - x
        end
        frame.text(x, y, task.detail, task.state.failed? ? Token::Red : Token::Text, max: room) if room > 0
        frame.text(time_x, y, time, task.running? ? Token::Cyan : Token::Muted)
      end

      private def running? : Bool
        @tasks.any?(&.running?)
      end

      private def summary : String
        failed = @tasks.count(&.state.failed?)
        total = @tasks.sum(&.seconds)
        failed > 0 ? "#{terminal.glyphs.fail} #{failed} failed" : "#{terminal.glyphs.ok} #{Widgets.duration(total)}"
      end

      private def start_ticker : Nil
        return if @ticking || terminal.reduced_motion?

        @ticking = true
        spawn do
          while running?
            sleep 80.milliseconds
            draw if running?
          end
          @ticking = false
        end
      end
    end
  end
end
