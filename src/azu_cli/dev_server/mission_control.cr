require "./hud"
require "./command_composer"

module AzuCLI::DevServer
  # An opt-in shell around the existing HUD. The existing console, compiler,
  # command runner and error inspector retain their lifecycle and callbacks.
  class MissionControl < UI::Screen
    include UI

    enum Tab
      Dashboard
      Server
      Jobs
      DB
      SQL
      Auth
      Logs
    end

    getter tab = Tab::Dashboard
    getter query = ""
    getter? searching = false
    getter? menu_open = false
    @menu_query = ""
    @menu_selected = 0
    @menu_viewport = Viewport.new
    @sidebar = true
    @log_sequence = 0
    @follow_logs = true
    SQL_COLOR = ->(line : String) { Highlight.sql(line) }
    LOG_COLOR = ->(line : String) { Highlight.log(line) }
    @legacy_visible = false
    @rows = {} of Tab => Array(Inspector::Item)
    @inspectors = {} of Tab => Inspector
    @snapshot : JSON::Any?
    @received : Time::Instant?
    @jobs_received : Time::Instant?
    @jobs : Events::JobsSample?
    @second = -1_i64
    @notice = "c console · e exceptions · ? commands"
    @now = Time.instant
    @composer : CommandComposer

    def initialize(@legacy : Hud, @project : String, @reduced_motion : Bool = false,
                   @clock : Proc(Time::Instant) = -> { Time.instant },
                   @read_only : Bool = false,
                   on_command : Proc(Control::Command, Bool) = ->(_command : Control::Command) { false })
      @composer = CommandComposer.new(on_command)
      @notice = read_only_notice if @read_only
      Tab.each do |tab|
        @rows[tab] = [] of Inspector::Item
        @inspectors[tab] = Inspector.new
      end
    end

    def summary : String
      @legacy.summary
    end

    def handoff : Proc(Nil)?
      return nil if @read_only
      @legacy.handoff
    end

    # Ticks also expire telemetry. Idle ticks update nothing visible until the
    # next second; reduced motion disables the busy spinner, not freshness checks.
    def animating? : Bool
      true
    end

    def update(event : Event) : Action
      @now = @clock.call
      @composer.update(event) unless event.is_a?(Key)
      if @legacy_visible
        if event.is_a?(Key) && event.code.esc?
          @legacy_visible = false
          return Action::Redraw
        end
        return @legacy.update(event)
      end
      return key(event) if event.is_a?(Key)
      @legacy.update(event) unless @read_only
      case event
      when Events::Telemetry
        @snapshot = event.data
        @received = @now
        ingest
      when Events::RemoteStatus
        @notice = "#{read_only_notice} · #{event.message}"
        @received = nil unless event.connected
        @jobs_received = nil unless event.connected
      when Events::JobsSample
        @jobs = event
        @jobs_received = @now
        replace(Tab::Jobs, event.queues.first(200).map do |queue|
          Inspector::Item.new(queue.name, "#{queue.name}  wait #{queue.pending}  processing #{queue.processing}  failed #{queue.failed}",
            ["Queue: #{queue.name}", "Pending: #{queue.pending}", "Processing: #{queue.processing}", "Failed: #{queue.failed}",
             "", "Processing is not a process-wide fiber count.", "Use azu joobq for worker/DAG/DLQ inspection and confirmed replay."])
        end)
      when Events::LogLine
        @log_sequence += 1
        line = event.line[0, 2048]
        item = Inspector::Item.new(@log_sequence.to_s, line, [line])
        replace(Tab::Logs, ([item] + @rows[Tab::Logs]).first(200))
        @inspectors[Tab::Logs].key(Key.new(KeyCode::Home)) if @follow_logs
      when Tick
        second = (@now - Widgets::EPOCH).total_seconds.to_i64
        return Action::Continue if second == @second && (@reduced_motion || !@legacy.animating?)
        @second = second
      end
      Action::Redraw
    end

    private def key(key : Key) : Action
      return Action::Quit if key.code.ctrl_c?
      return @composer.update(key) if @composer.active?
      if key.code.ctrl_p?
        @menu_open = !menu_open?
        @menu_query = ""
        @menu_selected = 0
        return Action::Redraw
      end
      return menu_key(key) if menu_open?
      if searching?
        case key.code
        when .esc?       then @searching = false; @query = ""
        when .enter?     then @searching = false
        when .backspace? then @query = query[0, Math.max(0, query.size - 1)]
        when .char?      then @query += key.char.to_s if query.size < 64
        end
        filter
        return Action::Redraw
      end
      return Action::Quit if key.char?('q')
      if @read_only && (key.char?('c') || key.char?('e') || key.char?('?') || key.char?('r') || key.char?(':') || key.char?('g'))
        @notice = read_only_notice
      elsif key.char?(':') || key.char?('g')
        @composer.open(key.char?('g'))
      elsif key.char?('/')
        @searching = true
      elsif key.code.esc?
        @query = ""
        filter
      elsif key.char?('c') || key.char?('e') || key.char?('?')
        @legacy_visible = true
        @legacy.update(Key.new(KeyCode::Char, key.char?('c') ? '3' : key.char?('e') ? '9' : '2'))
      elsif key.char?('b')
        @sidebar = !@sidebar
      elsif key.char?('l')
        @tab = Tab::Logs
      elsif tab.logs? && key.char?('f')
        @follow_logs = true
        @inspectors[tab].key(Key.new(KeyCode::Home))
      elsif (char = key.char) && ('1'..'7').includes?(char)
        @tab = Tab.from_value(char.ord - '1'.ord)
        filter
      elsif key.char?('r')
        @legacy.update(key)
      else
        @follow_logs = false if tab.logs?
        @inspectors[tab].key(key)
      end
      Action::Redraw
    end

    private def menu_items : Array({String, Char})
      entries = Tab.values.map { |item| {"Open #{item}", ('1'.ord + item.value).chr} }
      unless @read_only
        entries.concat([{"Run azu command", ':'}, {"Generate code", 'g'}, {"Open console", 'c'}, {"Inspect exceptions", 'e'}, {"Open command center", '?'}])
      end
      entries.select { |entry| self.class.matches?(entry[0], @menu_query) }
    end

    private def menu_key(event : Key) : Action
      case event.code
      when .esc?  then @menu_open = false
      when .up?   then @menu_selected -= 1
      when .down? then @menu_selected += 1
      when .backspace?
        @menu_query = @menu_query[0, Math.max(0, @menu_query.size - 1)]
        @menu_selected = 0
      when .char?
        @menu_query += event.char.to_s if @menu_query.size < 64
        @menu_selected = 0
      when .enter?
        if chosen = menu_items[@menu_selected]?
          @menu_open = false
          return key(Key.new(KeyCode::Char, chosen[1]))
        end
      end
      @menu_selected = @menu_selected.clamp(0, Math.max(0, menu_items.size - 1))
      Action::Redraw
    end

    private def replace(tab : Tab, rows : Array(Inspector::Item)) : Nil
      @rows[tab] = rows
      @inspectors[tab].replace(rows.select { |row| self.class.matches?(row.label, query) })
    end

    private def filter : Nil
      @rows.each { |tab, rows| @inspectors[tab].replace(rows.select { |row| self.class.matches?(row.label, query) }) }
    end

    # Bounded subsequence search; no user-supplied regular expressions.
    def self.matches?(label : String, query : String) : Bool
      text = label.downcase
      position = 0
      query.downcase.each_char do |char|
        found = text.index(char, position)
        return false unless found
        position = found + 1
      end
      true
    end

    private def field(value : JSON::Any?, key : String) : JSON::Any?
      DiagnosticData.field(value, key)
    end

    private def text(value : JSON::Any?, key : String) : String
      DiagnosticData.text(value, key, "--")[0, 512]
    end

    private def ingest : Nil
      requests = field(@snapshot, "requests")
      replace(Tab::Server, DiagnosticData.rows(requests, "recent", 200).map do |row|
        label = "#{text(row, "method")} #{text(row, "path")}  #{text(row, "status")}  #{text(row, "ms")}ms"
        Inspector::Item.new(text(row, "at") + label, label,
          [label, "Time: #{text(row, "at")}", "Endpoint: #{text(row, "endpoint")}", "Trace ID: #{text(row, "id")}"])
      end)
      sql = field(@snapshot, "sql")
      replace(Tab::SQL, DiagnosticData.rows(sql, "recent", 200).map do |row|
        statement = text(row, "sql")
        Inspector::Item.new(text(row, "id"), "#{text(row, "ms")}ms #{statement}",
          [statement, "Caller: #{text(row, "caller")}", "Model: #{text(row, "model")}", "Pool wait: #{text(row, "pool_wait_ms")}ms"])
      end)
      # Extension contracts: no database credentials, SQL parameters or auth tokens.
      database = field(@snapshot, "database")
      replace(Tab::DB, DiagnosticData.rows(database, "tables", 200).map do |row|
        name = text(row, "name")
        columns = DiagnosticData.rows(row, "columns", 100).map { |column| "#{text(column, "name")} : #{text(column, "type")}" }
        Inspector::Item.new(name, name, [name, "Schema version: #{text(database, "migration_version")}"] + columns)
      end)
      auth = field(@snapshot, "auth")
      replace(Tab::Auth, DiagnosticData.rows(auth, "recent", 200).map do |row|
        label = "#{text(row, "at")} #{text(row, "event")} #{text(row, "outcome")}"
        Inspector::Item.new(text(row, "id"), label, [label, "Only allowlisted, redacted security events are displayed."])
      end)
    end

    private def freshness(at : Time::Instant?) : String
      return "not connected" unless at
      @now - at > 5.seconds ? "stale" : "connected"
    end

    private def read_only_notice : String
      "PRODUCTION · READ ONLY · commands, console and rebuild disabled"
    end

    def view(frame : Frame) : Nil
      if @legacy_visible
        @legacy.view(frame)
        frame.text(0, frame.height - 1, "Esc mission control · existing console / errors / commands", Token::Cyan, max: frame.width)
        return
      end
      if frame.width < 48 || frame.height < 14
        frame.text(0, 0, "azu dev · enlarge to 48x14 or use --ui plain", Token::Amber, max: frame.width)
        return
      end
      header, rest = frame.area.inset(1, 0).split_top(3)
      inner = frame.card(header, "▲ AZU / #{@project} / #{tab}", @read_only ? "READ ONLY" : @legacy.state.to_s.downcase)
      frame.gradient(header.x + 3, header.y, frame.glyphs.brand, Attr::Bold)
      spinner = @legacy.animating? ? Widgets.spinner(frame.glyphs, @now, @reduced_motion) + " " : ""
      frame.text(inner.x, inner.y, spinner + @notice, Token::Muted, max: inner.w)
      content = Rect.new(rest.x, rest.y, rest.w, rest.h - 2)
      if frame.width >= 104 && @sidebar
        sidebar, content = content.split_left(18, 1)
        nav = frame.card(sidebar, "Workspace")
        row = nav.y
        Tab.each do |item|
          if nav.h >= 17 && (item.dashboard? || item.db? || item.logs?)
            group = item.dashboard? ? "OBSERVE" : item.db? ? "DATA & ACCESS" : "DEVELOP"
            row += 1 unless item.dashboard?
            frame.text(nav.x, row, group, Token::Muted, max: nav.w)
            row += 1
          end
          break if row >= nav.bottom
          frame.text(nav.x, row, "#{item == tab ? '▌' : ' '} #{item}",
            item == tab ? Token::Cyan : Token::Muted, max: nav.w)
          frame.text(nav.right - 1, row, (item.value + 1).to_s, Token::Muted, max: 1)
          row += 1
        end
      else
        nav, content = content.split_top(2)
        frame.text(nav.x, nav.y, "#{tab}  /  Ctrl-P navigate", Token::Cyan, max: nav.w)
      end
      if tab.dashboard?
        dashboard(frame, content)
      else
        @inspectors[tab].draw(frame, content, "#{tab} · #{freshness(tab.jobs? ? @jobs_received : @received)}",
          tab.db? || tab.auth? ? "No adapter data · see integration contract" : "No samples received", highlighter(tab))
      end
      frame.text(1, frame.height - 2, searching? ? "/ #{query}▏" : "#{query.empty? ? @notice : "filter: #{query}"} · telemetry #{freshness(@received)}", Token::Muted, max: frame.width - 2)
      shortcuts = @read_only ? "Ctrl-P menu  b sidebar  j/k select  Tab pane  / search  q disconnect" : "Ctrl-P menu  : command  g generate  b sidebar  j/k select  / search  q quit"
      frame.text(1, frame.height - 1, shortcuts, Token::Cyan, max: frame.width - 2)
      draw_menu(frame) if menu_open?
      @composer.view(frame) if @composer.active?
    end

    private def highlighter(section : Tab) : Proc(String, Array(Seg))?
      return SQL_COLOR if section.sql?
      return LOG_COLOR if section.logs? || section.server?
      nil
    end

    private def draw_menu(frame : Frame) : Nil
      width = Math.min(64, frame.width - 4)
      height = Math.min(16, frame.height - 4)
      box = Rect.new((frame.width - width) // 2, (frame.height - height) // 2, width, height)
      style = frame.style(bg: Token::Backplate)
      box.y.upto(box.bottom - 1) { |y| box.x.upto(box.right - 1) { |x| frame.put(x, y, ' ', style) } }
      inner = frame.card(box, "Navigate · Enter opens · Esc closes", border: Token::Cyan)
      frame.text(inner.x, inner.y, "> #{@menu_query}▏", Token::Cyan, max: inner.w)
      _, list = inner.split_top(2)
      labels = menu_items.map_with_index { |item, index| "#{index == @menu_selected ? '›' : ' '} #{item[0]}  [#{item[1]}]" }
      @menu_viewport.configure(labels.size, list.h)
      @menu_viewport.reveal(@menu_selected)
      @menu_viewport.draw(frame, list, labels, @menu_selected)
    end

    private def dashboard(frame : Frame, area : Rect) : Nil
      metrics, body = area.split_top(4)
      requests = field(@snapshot, "requests")
      sql = field(@snapshot, "sql")
      pool = field(sql, "pool")
      values = { {"Requests/s", text(requests, "rps")}, {"P95 ms", text(requests, "p95_ms")},
                {"Processing", @jobs.try { |sample| sample.error ? "unavailable" : sample.queues.sum(&.processing).to_s } || "--"},
                {"DB pool", "#{text(pool, "in_flight")}/#{text(pool, "max")}"} }
      metrics.columns(4, 1).each_with_index do |rect, index|
        inner = frame.card(rect, values[index][0])
        frame.text(inner.x, inner.y, values[index][1], Token::Cyan, Attr::Bold, max: inner.w)
      end
      top, bottom = body.split_top(body.h // 2)
      { {Tab::Server, Tab::Jobs}, {Tab::SQL, Tab::Auth} }.each_with_index do |tabs, row|
        (row == 0 ? top : bottom).columns(2, 1).each_with_index do |rect, column|
          section = tabs[column]
          badge = freshness(section.jobs? ? @jobs_received : @received)
          badge = "unavailable" if section.jobs? && @jobs.try(&.error)
          badge = "adapter needed" if section.auth? && field(@snapshot, "auth").try(&.as_h?).nil?
          inner = frame.card(rect, section.to_s, badge)
          items = @inspectors[section].items
          lines = items.empty? ? ["No samples · #{section.value + 1} opens inspector"] : items.map(&.label)
          Viewport.new.draw(frame, inner, lines, highlight: highlighter(section))
        end
      end
    end
  end
end
