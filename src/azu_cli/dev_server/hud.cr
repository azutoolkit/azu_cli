require "../ui"
require "./telemetry"
require "./control"

module AzuCLI
  module DevServer
    # The `azu dev` dashboard: build, app, the CLI's commands (the control plane), requests, SQL, jobs and the app's
    # log, updated as events arrive.
    class Hud < UI::Screen
      include UI

      enum Tab
        Overview
        Commands
        Requests
        SQL
        Jobs
        Log
      end

      enum State
        Starting
        Building
        Running
        Failed
        Stopped
      end

      LOG_LINES     = 500
      HISTORY_SIZE  =  60
      TELEMETRY_TTL = 5.seconds

      getter tab = Tab::Overview
      getter state = State::Starting
      getter rebuilds = 0
      getter crashes = 0
      getter restarts = 0
      getter log = Deque(Events::LogLine).new
      getter error : CompilerError?
      @progress : CompilerProgress?
      @build_started : Time::Instant?
      @last_build_seconds : Float64?
      @build_history = [] of Float64
      @changed = [] of String
      @pid : Int64?
      @app_started : Time::Instant?
      @session_started = Time.instant
      @rss : Int64?
      @cli_rss : Int64?
      @rss_history = [] of Float64
      @telemetry : JSON::Any?
      @telemetry_at : Time::Instant?
      @rps_history = [] of Float64
      @jobs : Events::JobsSample?
      @error_dismissed = false
      @exit_note : String?
      # The control plane: what each command last did, and which one the Commands panel shows
      getter runs = {} of String => Control::Run
      getter statuses = {} of String => Control::Status
      getter selected = 0
      getter confirming : Control::Command?
      getter? test_watch = false
      @kicked_off = false

      def initialize(@project : String, @port : String, @environment : String, @watching : String, @on_rebuild : Proc(Nil) = -> { }, @clock : Proc(Time::Instant) = -> { Time.instant }, @directory : String = Dir.current, @branch : String? = nil,
                     @commands : Array(Control::Command) = Control.catalog, @on_control : Proc(Control::Command, Nil) = ->(_command : Control::Command) { })
      end

      def animating? : Bool
        state.building? || state.starting? || statuses.values.any?(&.busy?)
      end

      def commands : Array(Control::Command)
        @commands
      end

      def status(id : String) : Control::Status
        statuses[id]? || Control::Status::Idle
      end

      # Runs the commands that `trigger` concerns (one already queued or running is left as it is).
      def trigger(trigger : Control::Trigger) : Nil
        @commands.each { |command| run(command) if command.triggers.includes?(trigger) }
        @commands.find(&.id.==("test")).try { |command| run(command) } if trigger.build? && test_watch?
      end

      private def run(command : Control::Command) : Nil
        return if status(command.id).busy?
        statuses[command.id] = Control::Status::Queued
        @on_control.call(command)
      end

      def requests_served : Int64
        @telemetry.try(&.dig?("requests", "total")).try(&.as_i64?) || 0_i64
      end

      # azu dev · 12m41s · 7 rebuilds · 0 crashes · 2,184 requests
      def summary : String
        elapsed = Widgets.clock(@clock.call - @session_started)
        "azu dev · #{elapsed} · #{rebuilds} rebuild#{rebuilds == 1 ? "" : "s"} · #{crashes} crash#{crashes == 1 ? "" : "es"} · #{requests_served} requests"
      end

      def update(event : Event) : UI::Action
        unless @kicked_off
          @kicked_off = true
          trigger(Control::Trigger::Start)
        end
        case event
        when Key     then key(event)
        when Resize  then UI::Action::Redraw
        when Tick    then UI::Action::Redraw
        when Message then message(event)
        else              UI::Action::Continue
        end
      end

      private def key(key : Key) : UI::Action
        return UI::Action::Quit if key.code.ctrl_c? || key.char?('q')

        if key.code.esc?
          return UI::Action::Continue unless failed_card?
          @error_dismissed = true
          return UI::Action::Redraw
        end
        return confirm(key) if @confirming
        if (char = key.char) && ('1'..'6').includes?(char)
          @tab = Tab.from_value(char.to_i - 1)
          return UI::Action::Redraw
        end
        return commands_key(key) if tab.commands? && commands_key?(key)
        case key.char
        when 'r'
          @on_rebuild.call
          UI::Action::Continue
        when 'l'
          @tab = Tab::Log
          UI::Action::Redraw
        when 'c'
          @log.clear
          UI::Action::Redraw
        else
          UI::Action::Continue
        end
      end

      private def commands_key?(key : Key) : Bool
        key.code.up? || key.code.down? || key.code.enter? || {'j', 'k', 'a', 'w'}.includes?(key.char)
      end

      # The Commands panel: move, run the selected command (after `y` when it changes something), run every check,
      # or re-run the tests after each build.
      private def commands_key(key : Key) : UI::Action
        if key.code.up? || key.char?('k')
          @selected = (@selected - 1) % @commands.size
        elsif key.code.down? || key.char?('j')
          @selected = (@selected + 1) % @commands.size
        elsif key.code.enter?
          command = @commands[@selected]
          command.confirm ? (@confirming = command) : run(command)
        elsif key.char?('a')
          @commands.each { |command| run(command) unless command.confirm || command.id.in?("test", "completion") }
        elsif key.char?('w')
          @test_watch = !@test_watch
        end
        UI::Action::Redraw
      end

      private def confirm(key : Key) : UI::Action
        command = @confirming.not_nil!
        @confirming = nil
        run(command) if key.char?('y') || key.char?('Y')
        UI::Action::Redraw
      end

      private def message(event : Message) : UI::Action
        case event
        when Events::ControlQueued
          statuses[event.id] = Control::Status::Queued unless status(event.id).running?
        when Events::ControlStarted
          statuses[event.id] = Control::Status::Running
        when Events::ControlFinished
          outcome, summary = Control.outcome(event.id, event.exit_code, event.output)
          statuses[event.id] = outcome
          runs[event.id] = Control::Run.new(outcome, summary, event.output.lines.map(&.rstrip), event.seconds, @clock.call)
          @commands.find(&.id.==("db:status")).try { |status_command| run(status_command) } if event.id == "db:migrate"
        when Events::BuildStarted
          @state = State::Building
          @build_started = @clock.call
          @progress = nil
          @changed = event.files unless event.files.empty?
        when Events::BuildLine
          if progress = CompilerProgress.parse(event.line)
            @progress = progress
          end
        when Events::BuildFinished
          @rebuilds += 1
          @last_build_seconds = event.seconds
          @progress = nil
          if event.success
            trigger(Control::Trigger::Build)
            @build_history = (@build_history << event.seconds).last(10)
            @error = nil
            @state = @pid ? State::Running : State::Starting
          else
            @error = CompilerError.parse(event.output)
            @error_dismissed = false
            @state = State::Failed
          end
        when Events::AppStarted
          @restarts += 1 if @pid || @app_started
          @pid = event.pid
          @app_started = @clock.call
          @exit_note = nil
          @state = State::Running unless state.failed?
        when Events::AppExited
          @crashes += 1
          @pid = nil
          @exit_note = event.description
          @state = State::Stopped unless state.failed?
        when Events::Changed
          @changed = event.files
          trigger(Control::Trigger::Migrations) if event.files.any?(&.includes?("db/migrations/"))
          trigger(Control::Trigger::Config) if event.files.any? { |file| Hud.config_file?(file) }
        when Events::LogLine
          @log << event
          @log.shift if @log.size > LOG_LINES
        when Events::RssSample
          @rss = event.app
          @cli_rss = event.cli
          event.app.try { |bytes| @rss_history = (@rss_history << bytes.to_f).last(HISTORY_SIZE) }
        when Events::JobsSample
          @jobs = event
        when Events::Telemetry
          @telemetry = event.data
          @telemetry_at = @clock.call
          rps = event.data.dig?("requests", "rps").try { |value| value.as_f? || value.as_i?.try(&.to_f) } || 0.0
          @rps_history = (@rps_history << rps).last(HISTORY_SIZE)
        end
        UI::Action::Redraw
      end

      # A file the configuration commands read: .env*, shard.yml/shard.lock, the CLI configuration.
      def self.config_file?(path : String) : Bool
        name = File.basename(path)
        name.starts_with?(".env") || name.in?("shard.yml", "shard.lock") || path.includes?("config/azu") || name.starts_with?(".azu")
      end

      private def failed_card? : Bool
        state.failed? && !@error_dismissed && !@error.nil?
      end

      # ---- drawing

      def view(frame : Frame) : Nil
        width, height = frame.width, frame.height
        title_bar(frame, width)
        tabs(frame, width)
        body = Rect.new(0, 2, width, height - 4)
        if failed_card?
          draw_error(frame, body)
        else
          case tab
          in .overview? then overview(frame, body)
          in .commands? then commands_panel(frame, body)
          in .requests? then requests(frame, body, full: true)
          in .sql?      then sql(frame, body, full: true)
          in .jobs?     then jobs(frame, body)
          in .log?      then log_card(frame, body, "Log")
          end
        end
        keys = if failed_card?
                 [{"Esc", "Back to the dashboard"}, {"r", "Retry build"}, {"q", "Quit"}]
               elsif command = @confirming
                 [{"y", "Run #{command.line}"}, {"any key", "Cancel"}]
               elsif tab.commands?
                 [{"↑/↓", "Select"}, {"Enter", "Run"}, {"a", "Run all checks"}, {"w", "Tests after builds: #{test_watch? ? "on" : "off"}"}, {"1-6", "Panels"}, {"q", "Quit"}]
               else
                 [{"1-6", "Panels"}, {"r", "Rebuild"}, {"l", "Log"}, {"c", "Clear log"}, {"q", "Quit"}]
               end
        Widgets.key_bar(frame, 1, height - 2, keys, width - 2)
        status_line(frame, width, height - 1)
      end

      private def title_bar(frame : Frame, width : Int32) : Nil
        g = frame.glyphs
        spinner = animating? ? Widgets.spinner(g, @clock.call) : " "
        clock = "#{Time.local.to_s("%H:%M:%S")}  "
        clock_x = width - 2 - Width.of(clock)
        frame.text(clock_x, 0, clock, Token::Muted)
        frame.text(width - 2, 0, spinner, Token::Cyan)

        x = frame.gradient(1, 0, g.brand, Attr::Bold)
        mark, label, tone = case state
                            in .starting? then {g.busy, "starting", Token::Cyan}
                            in .building? then {g.busy, "building", Token::Cyan}
                            in .running?  then {g.on, "running", Token::Green}
                            in .failed?   then {g.fail, @pid ? "build failed · serving the previous build" : "build failed", Token::Red}
                            in .stopped?  then {g.off, "stopped", Token::Amber}
                            end
        segs = [Seg["  dev #{g.dot} ", Token::Muted], Seg[@project], Seg["    #{mark} #{label}", tone]]
        @pid.try { |pid| segs << Seg["   pid #{pid}", Token::Muted] }
        segs << Seg["   :#{@port}", Token::Blue]
        segs << Seg["   #{@environment}", Token::Muted]
        frame.line(x, 0, segs, clock_x - x - 2)
      end

      private def tabs(frame : Frame, width : Int32) : Nil
        x = 1
        Tab.values.each_with_index do |entry, index|
          on = entry == tab
          label = "[#{index + 1}] #{entry.to_s == "SQL" ? "SQL" : entry.to_s}"
          x = frame.text(x, 1, label, on ? frame.style(Token::Cyan, Attr::Bold) : frame.style(Token::Muted))
          x += 3
        end
      end

      private def overview(frame : Frame, body : Rect) : Nil
        wide = body.w >= 90
        top, rest = body.split_top(5)
        if wide
          left, right = top.columns(2, 1)
          build_card(frame, left)
          app_card(frame, right)
        else
          top, rest = body.split_top(4)
          compact_card(frame, top)
        end
        if rest.h >= 12
          strip, rest = rest.split_top(3)
          commands_strip(frame, strip)
        end
        request_rows = Math.max(1, Math.min(5, (rest.h - 12) // 1))
        reqs, rest = rest.split_top(request_rows + 3)
        requests(frame, reqs)
        lower, rest = rest.split_top(Math.min(6, rest.h))
        if wide && !lower.empty?
          left, right = lower.columns(2, 1)
          sql(frame, left)
          jobs(frame, right)
        elsif !lower.empty?
          sql(frame, lower)
        end
        log_card(frame, rest, "Log") if rest.h >= 3
      end

      # ---- the control plane

      private def mark(frame : Frame, status : Control::Status) : {String, Token}
        g = frame.glyphs
        case status
        in .idle?    then {g.off, Token::Faint}
        in .queued?  then {g.dot, Token::Muted}
        in .running? then {Widgets.spinner(g, @clock.call), Token::Cyan}
        in .ok?      then {g.ok, Token::Green}
        in .warn?    then {g.warn, Token::Amber}
        in .fail?    then {g.fail, Token::Red}
        end
      end

      # One line on the overview: every command that has run, with its mark; what needs a look first.
      private def commands_strip(frame : Frame, rect : Rect) : Nil
        attention = @commands.count { |command| status(command.id).warn? || status(command.id).fail? }
        inner = frame.card(rect, "Commands", attention > 0 ? "#{attention} need a look · [2]" : "[2] details")
        return if inner.empty?

        segs = [] of Seg
        @commands.each do |command|
          next if status(command.id).idle?
          glyph, tone = mark(frame, status(command.id))
          segs << Seg[glyph, tone] << Seg[" #{command.id}", status(command.id).ok? ? Token::Muted : tone] << Seg["   "]
        end
        segs << Seg["starting the checks", Token::Muted] if segs.empty?
        frame.line(inner.x, inner.y, segs, inner.w)
      end

      private def commands_panel(frame : Frame, body : Rect) : Nil
        list_width = Math.min(60, Math.max(36, body.w * 9 // 20))
        list, detail = body.w >= 90 ? {Rect.new(body.x, body.y, list_width, body.h), Rect.new(body.x + list_width + 1, body.y, body.w - list_width - 1, body.h)} : body.split_top(@commands.size + 8)
        command_list(frame, list)
        command_detail(frame, detail) unless detail.h < 3
      end

      private def command_list(frame : Frame, rect : Rect) : Nil
        counts = {Control::Status::Ok, Control::Status::Warn, Control::Status::Fail}.map { |wanted| @commands.count { |command| status(command.id) == wanted } }
        g = frame.glyphs
        inner = frame.card(rect, "Commands", "#{counts[0]} #{g.ok}  #{counts[1]} #{g.warn}  #{counts[2]} #{g.fail}")
        return if inner.empty?

        y = inner.y
        group = nil
        @commands.each_with_index do |command, index|
          break if y >= inner.bottom
          if command.group != group
            group = command.group
            frame.text(inner.x, y, group.upcase, Token::Faint)
            y += 1
            break if y >= inner.bottom
          end
          selected = index == @selected
          glyph, tone = mark(frame, status(command.id))
          frame.text(inner.x, y, selected ? g.pointer : " ", Token::Cyan)
          frame.text(inner.x + 2, y, glyph, tone)
          frame.text(inner.x + 4, y, command.id, selected ? frame.style(Token::Cyan, Attr::Bold) : frame.style(Token::Text), max: 16)
          age = runs[command.id]?.try { |run| ago(run.at) } || ""
          age_x = inner.right - Width.of(age)
          summary = runs[command.id]?.try(&.summary) || (command.confirm ? "Enter, then y" : (command.triggers.none? ? "Enter runs it" : ""))
          summary = "queued" if status(command.id).queued?
          summary = "running" if status(command.id).running?
          frame.text(inner.x + 21, y, summary, status(command.id).ok? || status(command.id).idle? ? Token::Muted : tone, max: age_x - inner.x - 22)
          frame.text(age_x, y, age, Token::Faint)
          y += 1
        end
      end

      private def command_detail(frame : Frame, rect : Rect) : Nil
        command = @commands[@selected]
        run = runs[command.id]?
        badge = run.try { |done| "#{Widgets.duration(done.seconds)} · #{ago(done.at)} ago" }
        inner = frame.card(rect, command.line, badge)
        return if inner.empty?

        y = inner.y
        if pending = @confirming
          frame.text(inner.x, y, "#{frame.glyphs.warn} #{pending.line} changes #{pending.id.starts_with?("db") ? "the database" : "the session store"}: press y to run it", Token::Amber, max: inner.w)
          y += 2
        end
        when_line = Hud.when_runs(command, test_watch?)
        frame.text(inner.x, y, when_line, Token::Faint, max: inner.w)
        y += 1
        if status(command.id).running?
          frame.text(inner.x, y, "#{Widgets.spinner(frame.glyphs, @clock.call)} running", Token::Cyan)
          y += 1
        end
        return unless run
        y += 1
        lines = run.output.reject(&.blank?)
        room = inner.bottom - y
        return if room <= 0
        lines.last(room).each_with_index do |line, index|
          tone = line.matches?(/\A(ok|✔)\b/) ? Token::Text : (line.matches?(/\A(warn|WARNING)/) ? Token::Amber : (line.matches?(/\A(fail|ERROR|FATAL)|error/i) ? Token::Red : Token::Text))
          frame.text(inner.x, y + index, line, tone, max: inner.w)
        end
      end

      # "runs at start and on config changes", for the detail card.
      def self.when_runs(command : Control::Command, test_watch : Bool) : String
        return "changes things: runs on Enter, after y" if command.confirm
        return "runs on Enter#{test_watch ? " and after each build (w)" : "; w runs it after each build"}" if command.id == "test"
        events = [] of String
        events << "at start" if command.triggers.start?
        events << "after each build" if command.triggers.build?
        events << "when src/db/migrations changes" if command.triggers.migrations?
        events << "when .env, shard.yml or the CLI config changes" if command.triggers.config?
        events.empty? ? "runs on Enter" : "runs #{events.join(", ")} and on Enter"
      end

      private def ago(at : Time::Instant) : String
        seconds = (@clock.call - at).total_seconds
        seconds < 60 ? "#{seconds.to_i}s" : (seconds < 3600 ? "#{(seconds / 60).to_i}m" : "#{(seconds / 3600).to_i}h")
      end

      private def build_card(frame : Frame, rect : Rect) : Nil
        g = frame.glyphs
        forecast = @build_history.empty? ? nil : "next ~#{Widgets.duration(@build_history.sum / @build_history.size)}"
        inner = frame.card(rect, "Build", forecast)
        return if inner.empty?

        case state
        when .building?
          elapsed = Widgets.duration((@clock.call - (@build_started || @clock.call)).total_seconds)
          x = frame.text(inner.x, inner.y, "#{Widgets.spinner(g, @clock.call)} building", Token::Cyan)
          frame.text(x, inner.y, " · #{elapsed}", Token::Muted)
          if progress = @progress
            full, empty = Widgets.meter(progress.fraction, Math.min(30, inner.w - 22), g.bar_full, g.bar_empty)
            x = frame.gradient(inner.x, inner.y + 1, full)
            x = frame.text(x, inner.y + 1, empty, Token::Faint)
            frame.text(x + 1, inner.y + 1, progress.stage, Token::Muted, max: inner.right - x - 1)
          else
            frame.text(inner.x, inner.y + 1, "shards build", Token::Muted)
          end
        when .failed?
          seconds = @last_build_seconds.try { |value| " after #{Widgets.duration(value)}" } || ""
          frame.text(inner.x, inner.y, "#{g.fail} failed#{seconds}", Token::Red)
          @error.try { |error| frame.text(inner.x, inner.y + 1, error.message, Token::Muted, max: inner.w) }
        else
          if seconds = @last_build_seconds
            x = frame.text(inner.x, inner.y, "#{g.ok} built in ", Token::Green)
            frame.text(x, inner.y, Widgets.duration(seconds), Token::Cyan)
          else
            frame.text(inner.x, inner.y, "#{g.busy} first build", Token::Muted)
          end
          unless @build_history.empty?
            x = frame.text(inner.x, inner.y + 1, "history ", Token::Muted)
            frame.gradient(x, inner.y + 1, Widgets.sparkline(@build_history, 10, g))
          end
        end
        unless @changed.empty?
          names = @changed.first(2).join(", ") + (@changed.size > 2 ? " +#{@changed.size - 2}" : "")
          frame.text(inner.x, inner.y + 2, names, Token::Blue, max: inner.w)
        end
      end

      private def app_card(frame : Frame, rect : Rect) : Nil
        inner = frame.card(rect, "App")
        return if inner.empty?

        uptime = @app_started.try { |started| @pid ? Widgets.clock(@clock.call - started) : nil } || "--:--:--"
        frame.line(inner.x, inner.y, [Seg["uptime ", Token::Muted], Seg[uptime], Seg["  restarts ", Token::Muted], Seg[restarts.to_s],
                                      Seg["  crashes ", Token::Muted], Seg[crashes.to_s, crashes > 0 ? Token::Red : Token::Green]], inner.w)
        if rss = @rss
          x = frame.line(inner.x, inner.y + 1, [Seg["RSS ", Token::Muted], Seg[Widgets.bytes(rss), Token::Cyan], Seg["  "]], inner.w)
          frame.gradient(x, inner.y + 1, Widgets.sparkline(@rss_history, Math.max(0, inner.right - x), frame.glyphs))
        else
          frame.text(inner.x, inner.y + 1, "RSS —", Token::Muted)
        end
        if note = @exit_note
          frame.text(inner.x, inner.y + 2, "The app #{note}; save a change to start it again", Token::Amber, max: inner.w)
        else
          heap = @telemetry.try(&.dig?("runtime", "heap_bytes")).try(&.as_i64?)
          frame.line(inner.x, inner.y + 2, [Seg["templates ", Token::Muted], Seg["hot reload"], Seg[heap ? "  GC heap " : "", Token::Muted], Seg[heap ? Widgets.bytes(heap) : ""]], inner.w)
        end
      end

      # Build and App in one card, for narrow terminals.
      private def compact_card(frame : Frame, rect : Rect) : Nil
        inner = frame.card(rect, "Build · App")
        return if inner.empty?
        g = frame.glyphs
        build = case state
                when .building? then Seg["#{Widgets.spinner(g, @clock.call)} building", Token::Cyan]
                when .failed?   then Seg["#{g.fail} build failed", Token::Red]
                else                 Seg["#{g.ok} #{@last_build_seconds.try { |value| Widgets.duration(value) } || "built"}", Token::Green]
                end
        frame.line(inner.x, inner.y, [build, Seg["   RSS ", Token::Muted], Seg[@rss.try { |rss| Widgets.bytes(rss) } || "—", Token::Cyan]], inner.w)
        frame.line(inner.x, inner.y + 1, [Seg["restarts ", Token::Muted], Seg[restarts.to_s], Seg["   crashes ", Token::Muted], Seg[crashes.to_s, crashes > 0 ? Token::Red : Token::Green]], inner.w)
      end

      private def telemetry_fresh? : Bool
        at = @telemetry_at
        !at.nil? && @clock.call - at < TELEMETRY_TTL
      end

      private def waiting_for_telemetry(frame : Frame, inner : Rect) : Nil
        message = @telemetry_at ? "No telemetry for #{TELEMETRY_TTL.total_seconds.to_i}s: is the app running?" : "Waiting for telemetry from the app"
        frame.text(inner.x, inner.y, message, Token::Muted, max: inner.w)
        frame.text(inner.x, inner.y + 1, "needs azu with AZU_TELEMETRY_SOCKET support, require \"azu/dev\" and PERFORMANCE_MONITORING=true", Token::Faint, max: inner.w) if inner.h > 1
      end

      private def requests(frame : Frame, rect : Rect, full : Bool = false) : Nil
        data = @telemetry.try(&.["requests"]?)
        badge = data.try(&.["total"]?).try { |total| "#{total} total" }
        inner = frame.card(rect, "Requests", badge)
        return if inner.empty?
        return waiting_for_telemetry(frame, inner) unless data && @telemetry_at

        stats = [Seg[number(data["rps"]?, 1), Token::Cyan], Seg[" req/s   ", Token::Muted],
                 Seg["p50 ", Token::Muted], Seg["#{number(data["p50_ms"]?, 1)} ms   "],
                 Seg["p95 ", Token::Muted], Seg["#{number(data["p95_ms"]?, 1)} ms   "],
                 Seg["4xx ", Token::Muted], Seg[number(data["errors_4xx"]?, 0), Token::Amber],
                 Seg["   5xx ", Token::Muted], Seg[number(data["errors_5xx"]?, 0), positive?(data["errors_5xx"]?) ? Token::Red : Token::Green]]
        x = frame.line(inner.x, inner.y, stats, inner.w)
        spark = Widgets.sparkline(@rps_history, Math.max(0, inner.right - x - 3), frame.glyphs)
        frame.gradient(inner.right - Width.of(spark), inner.y, spark) unless spark.empty?
        rows = data["recent"]?.try(&.as_a?) || [] of JSON::Any
        rows.first(inner.h - 1).each_with_index do |row, index|
          y = inner.y + 1 + index
          method = row["method"]?.try(&.as_s?) || "?"
          status = row["status"]?.try(&.as_i?) || 0
          frame.line(inner.x, y, [Seg[(row["at"]?.try(&.as_s?) || "").ljust(10), Token::Muted],
                                  Seg[method.ljust(7), method_color(method)],
                                  Seg[Width.pad(row["path"]?.try(&.as_s?) || "", full ? 36 : 24) + " "],
                                  Seg[status.to_s.ljust(5), status_color(status)],
                                  Seg["#{number(row["ms"]?, 1)} ms".ljust(10)],
                                  Seg[row["endpoint"]?.try(&.as_s?) || "", Token::Muted]], inner.w)
        end
      end

      private def sql(frame : Frame, rect : Rect, full : Bool = false) : Nil
        data = @telemetry.try(&.["sql"]?)
        pool = data.try(&.["pool"]?)
        badge = pool.try { |value| value.raw.nil? ? nil : "pool #{number(value["in_flight"]?, 0)}/#{number(value["max"]?, 0)}" }
        inner = frame.card(rect, "SQL", badge)
        return if inner.empty?
        return waiting_for_telemetry(frame, inner) unless data && @telemetry_at

        g = frame.glyphs
        frame.line(inner.x, inner.y, [Seg[number(data["total"]?, 0), Token::Cyan], Seg[" q   avg ", Token::Muted], Seg["#{number(data["avg_ms"]?, 1)} ms"],
                                      Seg["   slow ", Token::Muted], Seg[number(data["slow"]?, 0), positive?(data["slow"]?) ? Token::Amber : Token::Text]], inner.w)
        y = inner.y + 1
        alerts = data["n_plus_one"]?.try(&.as_a?) || [] of JSON::Any
        alerts.each do |alert|
          break if y >= inner.bottom
          frame.line(inner.x, y, [Seg["#{g.warn} N+1 ×#{number(alert["count"]?, 0)}  ", Token::Amber], Seg[alert["sql"]?.try(&.as_s?) || "", Token::Amber]], inner.w)
          y += 1
          where = [alert["endpoint"]?.try(&.as_s?), alert["caller"]?.try(&.as_s?)].compact.join("  ")
          if !where.empty? && y < inner.bottom
            frame.text(inner.x + 2, y, where, Token::Blue, max: inner.w - 2)
            y += 1
          end
          if full && (suggestion = alert["suggestion"]?.try(&.as_s?)) && y < inner.bottom
            frame.text(inner.x + 2, y, suggestion, Token::Muted, max: inner.w - 2)
            y += 1
          end
        end
        slowest = data["slowest"]?.try(&.as_a?) || [] of JSON::Any
        slowest.each do |query|
          break if y >= inner.bottom
          ms = query["ms"]?
          frame.line(inner.x, y, [Seg["#{number(ms, 1)} ms".rjust(9) + "  ", (ms.try(&.as_f?) || 0.0) >= 100 ? Token::Amber : Token::Muted],
                                  Seg[query["sql"]?.try(&.as_s?) || ""]], inner.w)
          y += 1
        end
      end

      private def jobs(frame : Frame, rect : Rect) : Nil
        sample = @jobs
        inner = frame.card(rect, "Workers · JoobQ")
        return if inner.empty?
        unless sample
          frame.text(inner.x, inner.y, "No config/jobs.yml in this project", Token::Muted, max: inner.w)
          return
        end
        if error = sample.error
          frame.text(inner.x, inner.y, "#{frame.glyphs.warn} #{error}", Token::Amber, max: inner.w)
          return
        end
        g = frame.glyphs
        sample.queues.first(inner.h).each_with_index do |queue, index|
          y = inner.y + index
          load = queue.pending + queue.processing
          fraction = load == 0 ? 0.0 : Math.min(1.0, Math.log10(load + 1) / 3)
          full, empty = Widgets.meter(fraction, 10, g.meter_full, g.meter_empty)
          frame.line(inner.x, y, [Seg[queue.name.ljust(12)], Seg[full, Token::Cyan], Seg[empty, Token::Faint],
                                  Seg["  pending ", Token::Muted], Seg[queue.pending.to_s],
                                  Seg["  busy ", Token::Muted], Seg[queue.processing.to_s, Token::Cyan],
                                  Seg["  failed ", Token::Muted], Seg[queue.failed.to_s, queue.failed > 0 ? Token::Red : Token::Green]], inner.w)
        end
      end

      private def log_card(frame : Frame, rect : Rect, title : String) : Nil
        return if rect.h < 3

        inner = frame.card(rect, title, "#{Math.min(log.size, rect.h - 2)} of #{log.size}")
        lines = log.to_a.last(inner.h)
        lines.each_with_index do |entry, index|
          tone = entry.error ? Token::Amber : Token::Text
          tone = Token::Red if entry.line.includes?("ERROR") || entry.line.includes?("Error")
          frame.text(inner.x, inner.y + index, entry.line.gsub(/\e\[[0-9;]*[A-Za-z]/, ""), tone, max: inner.w)
        end
        frame.text(inner.x, inner.y, "The app's output appears here", Token::Muted) if lines.empty?
      end

      private def draw_error(frame : Frame, body : Rect) : Nil
        error = @error.not_nil!
        g = frame.glyphs
        serving = @pid ? "the app keeps running the previous build (pid #{@pid})" : "the app is not running"
        badge = @last_build_seconds.try { |seconds| Widgets.duration(seconds) }
        inner = frame.card(body, "Build failed · #{serving}", badge, border: Token::Red, title_color: Token::Red)
        y = inner.y + 1
        if location = error.location
          frame.line(inner.x, y, [Seg["#{g.fail} ", Token::Red], Seg[location, Token::Blue]], inner.w)
          y += 2
        end
        error.excerpt.each do |line|
          break if y >= inner.bottom - 2
          next if line.starts_with?("In ") && error.location
          tone = if line.starts_with?("Error:")
                   Token::Red
                 elsif line.matches?(/^\s*\d+ \|/)
                   Token::Text
                 elsif line.includes?('^')
                   Token::Red
                 else
                   Token::Muted
                 end
          frame.text(inner.x + 1, y, line, tone, max: inner.w - 1)
          y += 1
        end
        frame.text(inner.x, inner.bottom - 1, "#{g.pointer} Save a fix and azu dev builds again; this card closes on the next good build.", Token::Muted, max: inner.w)
      end

      private def status_line(frame : Frame, width : Int32, y : Int32) : Nil
        home = ENV["HOME"]?
        directory = home && @directory.starts_with?(home) ? "~#{@directory.lchop(home)}" : @directory
        left = [Seg["cli #{@cli_rss.try { |bytes| Widgets.bytes(bytes) } || "—"}", Token::Muted], Seg[" · #{directory}", Token::Muted]]
        @branch.try { |branch| left << Seg[" · #{branch}", Token::Muted] }
        right = "#{@watching} "
        frame.line(1, y, left, width - Width.of(right) - 3)
        frame.text(width - Width.of(right) - 1, y, right, Token::Muted)
      end

      private def number(value : JSON::Any?, digits : Int32) : String
        return "—" unless value
        if int = value.as_i64?
          int.to_s
        elsif float = value.as_f?
          digits == 0 ? float.round.to_i64.to_s : float.round(digits).to_s
        else
          "—"
        end
      end

      private def positive?(value : JSON::Any?) : Bool
        (value.try(&.as_i64?) || value.try(&.as_f?) || 0) > 0
      end

      private def method_color(method : String) : Token
        case method
        when "GET", "HEAD"  then Token::Blue
        when "POST"         then Token::Cyan
        when "PATCH", "PUT" then Token::Purple
        when "DELETE"       then Token::Red
        else                     Token::Muted
        end
      end

      private def status_color(status : Int32) : Token
        return Token::Red if status >= 500
        return Token::Amber if status >= 400
        Token::Green
      end
    end
  end
end
