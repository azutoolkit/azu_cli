module AzuCLI::DevServer
  # Reference-inspired shell. Every pane paints into the shared frame; none owns
  # terminal IO. Small terminals retain the same routes and keyboard controls.
  class MissionControl
    @request_history = [] of Float64
    @overview_focus = 0
    @overview_logs = Viewport.new
    @overview_sql = Viewport.new
    @overview_queries = Viewport.new
    @overview_queues = Viewport.new

    private def section_name(section : Tab) : String
      case section
      when .dashboard? then "Overview"
      when .db?        then "Schema"
      else                  section.to_s
      end
    end

    private def section_group(section : Tab) : String
      case section
      when .db?, .migrations?, .auth?                         then "Data & Access"
      when .console?, .commands?, .build?, .errors?, .config? then "Develop"
      else                                                         "Observe"
      end
    end

    private def navigation_tabs : Array(Tab)
      [Tab::Dashboard, Tab::Server, Tab::Jobs, Tab::SQL, Tab::Logs,
       Tab::DB, Tab::Migrations, Tab::Auth, Tab::Console, Tab::Commands,
       Tab::Build, Tab::Errors, Tab::Config].select { |section| tabs.includes?(section) }
    end

    private def nav_icon(section : Tab, frame : Frame) : String
      return ">" if frame.glyphs == Glyphs::ASCII
      case section
      when .dashboard?      then "▌"
      when .server?, .jobs? then "▷"
      when .sql?            then "▤"
      when .db?             then "▣"
      when .migrations?     then "≈"
      when .auth?           then "◇"
      when .console?        then ">_"
      when .commands?       then "≡"
      when .logs?, .errors? then "▧"
      else                       "·"
      end
    end

    private def overview_key(key : Key) : Nil
      if key.code.tab? || key.code.back_tab?
        @overview_focus = (@overview_focus + (key.code.back_tab? ? 2 : 1)) % 3
        return
      end
      section = {Tab::Logs, Tab::SQL, Tab::Jobs}[@overview_focus]
      if key.code.enter?
        select_tab(section)
        return
      end
      if section.sql? && (key.code.page_up? || key.code.page_down?)
        @overview_sql.key(key)
      else
        if section.logs?
          @follow_logs = false
          # Log storage is newest-first; the overview reads chronologically.
          code = case key.code
                 when .down?      then KeyCode::Up
                 when .up?        then KeyCode::Down
                 when .page_down? then KeyCode::PageUp
                 when .page_up?   then KeyCode::PageDown
                 when .home?      then KeyCode::End
                 when .end?       then KeyCode::Home
                 else                  key.char?('j') ? KeyCode::Up : (key.char?('k') ? KeyCode::Down : key.code)
                 end
          key = Key.new(code)
        end
        @overview_sql.reset if section.sql?
        @inspectors[section].key(key)
      end
    end

    def view(frame : Frame) : Nil
      frame.fill(frame.area, style: frame.style(Token::Text, bg: Token::Backplate))
      if frame.width < 48 || frame.height < 14
        frame.text(0, 0, "azu dev · enlarge to 48x14 or use --ui plain", Token::Amber, max: frame.width)
        return
      end
      body = Rect.new(1, 0, frame.width - 2, frame.height - 2)
      if frame.width >= 104 && @sidebar
        rail, body = body.split_left(20, 1)
        draw_rail(frame, rail)
      end
      header, content = body.split_top(3)
      draw_header(frame, header)
      if active = panel
        @workspace.panel_view(frame, content, active)
      elsif tab.dashboard?
        dashboard(frame, content)
      else
        draw_inspector(frame, content)
      end
      draw_footer(frame)
      draw_menu(frame) if menu_open?
      draw_help(frame) if @help_open
      @composer.view(frame) if @composer.active?
    end

    private def draw_rail(frame : Frame, rail : Rect) : Nil
      frame.gradient(rail.x + 2, 1, frame.glyphs.brand, Attr::Bold)
      frame.text(rail.x + 2, 3, @project, Token::Cyan, max: rail.w - 3)
      frame.text(rail.x + 2, 4, @read_only ? "PRODUCTION / READ ONLY" : @workspace.environment, Token::Muted, max: rail.w - 3)
      rail.h.times { |y| frame.put(rail.right - 1, y, frame.glyphs.vertical, frame.style(Token::Border)) }
      frame.hline(rail.x + 2, 6, rail.w - 4, frame.style(Token::Border))
      labels = [] of String
      selection = 0
      previous_group = ""
      navigation_tabs.each do |section|
        group = section_group(section)
        if group != previous_group
          labels << "" unless labels.empty?
          labels << group.upcase
          previous_group = group
        end
        selection = labels.size if section == tab
        label = Width.pad("#{nav_icon(section, frame)} #{section_name(section)}", rail.w - 7) + "[#{shortcut(section)}]"
        labels << label
      end
      area = Rect.new(rail.x + 1, 7, rail.w - 2, Math.max(0, rail.h - 12))
      @nav_viewport.configure(labels.size, area.h)
      @nav_viewport.reveal(selection)
      @nav_viewport.draw(frame, area, labels, selection)
      labels.skip(@nav_viewport.offset).first(area.h).each_with_index do |label, row|
        if {"OBSERVE", "DATA & ACCESS", "DEVELOP"}.includes?(label)
          frame.text(area.x, area.y + row, label, Token::Muted, max: area.w - 1)
        elsif label.empty?
          frame.hline(area.x, area.y + row, area.w - 2, frame.style(Token::Border))
        end
      end
      selected_y = area.y + selection - @nav_viewport.offset
      if area.h > 0 && area.y <= selected_y < area.bottom
        frame.text(rail.x, selected_y, frame.glyphs == Glyphs::ASCII ? "|" : "▌", Token::Cyan, max: 1)
      end
      if rail.h >= 18
        frame.hline(rail.x + 2, rail.bottom - 4, rail.w - 4, frame.style(Token::Border))
        frame.text(rail.x + 2, rail.bottom - 3, "Ctrl-P  Navigate", Token::Muted, max: rail.w - 3)
        frame.text(rail.x + 2, rail.bottom - 2, "b       collapse", Token::Muted, max: rail.w - 3)
      end
    end

    private def draw_header(frame : Frame, header : Rect) : Nil
      state = @read_only ? "READ ONLY" : @workspace.state.to_s.downcase
      color = @workspace.state.running? ? Token::Green : Token::Amber
      segments = [Seg[@project, Token::Text], Seg[" / #{section_group(tab)} / ", Token::Muted],
                  Seg[section_name(tab), Token::Cyan], Seg["  |  ", Token::Muted],
                  Seg["#{frame.glyphs.on} #{state}", color]]
      unless @read_only
        segments << Seg["  pid #{@workspace.pid || "--"}", Token::Muted]
        segments << Seg[" :#{@workspace.port}", Token::Cyan]
      end
      reserve = header.w >= 100 ? 25 : 0
      frame.text(header.x, header.y, @notice, Token::Muted, max: header.w - reserve) if @read_only
      if @received && !@read_only && !@sample_data
        frame.text(header.x, header.y, SharedTelemetry.runtime_label(@snapshot), Token::Muted, max: header.w - reserve)
      end
      frame.line(header.x, header.y + 1, segments, header.w - reserve)
      if reserve > 0
        label = @sample_data ? "PREVIEW · SAMPLE DATA" : (@read_only ? "PRODUCTION · READ ONLY" : "LOCAL DEVELOPMENT")
        frame.text(header.right - reserve, header.y, label, Token::Muted, max: reserve)
        frame.text(header.right - 8, header.y + 1, Time.local.to_s("%H:%M:%S"), Token::Muted, max: 8)
      elsif @sample_data
        frame.text(header.x, header.y, "PREVIEW · SAMPLE DATA", Token::Muted, max: header.w)
      end
      frame.hline(header.x, header.bottom - 1, header.w, frame.style(Token::Border))
    end

    private def draw_footer(frame : Frame) : Nil
      y = frame.height - 2
      frame.hline(1, y, frame.width - 2, frame.style(Token::Border))
      label = if @help_open
                "↑/↓ scroll · PgUp/PgDn page · Esc/h close · Ctrl-P navigate"
              elsif searching?
                "/ #{query}▏  Enter apply · Esc clear"
              elsif menu_open?
                "↑/↓ choose · Enter open · Esc close"
              elsif @read_only
                "h help · Ctrl-P menu · q disconnect · Tab pane · j/k select · / filter"
              elsif tab.console?
                "Ctrl-P menu · Enter run · Alt-Enter newline · Ctrl-O interpreter · Esc back"
              elsif tab.commands?
                "Ctrl-P menu · ↑/↓ select · Enter run · y confirm · PgUp/PgDn output · q quit"
              elsif !query.empty?
                "filter: #{query} · Esc clear · Ctrl-P navigate · q quit"
              else
                "h help · Ctrl-P menu · q quit · #{context_hint}"
              end
      reserve = frame.width >= 136 ? 25 : 0
      frame.text(2, y + 1, label, Token::Cyan, max: frame.width - 4 - reserve)
      if reserve > 0
        frame.text(frame.width - reserve, y + 1, "telemetry · #{freshness(@received)}", Token::Muted, max: reserve - 1)
      end
    end

    private def context_hint : String
      return "y confirm · n cancel" if tab.commands? && @workspace.confirming
      case tab
      when .console?
        "Enter evaluate · Alt-Enter newline · Ctrl-O interpreter · Esc back"
      when .commands?
        "j/k select · Enter run/review · PgUp/PgDn output"
      when .dashboard?
        "Tab pane · Enter inspect · j/k select · f follow · t source"
      when .logs?
        "j/k select · Tab details · f follow · t source · / filter"
      when .build?
        "r rebuild · PgUp/PgDn scroll"
      when .config?
        "Enter refresh · PgUp/PgDn scroll"
      else
        "Tab details · j/k select · PgUp/PgDn scroll · / filter"
      end
    end

    private def draw_help(frame : Frame) : Nil
      width = Math.min(76, frame.width - 4)
      height = Math.min(32, frame.height - 4)
      box = Rect.new((frame.width - width) // 2, (frame.height - height) // 2, width, height)
      frame.fill(box, style: frame.style(bg: Token::Backplate))
      inner = frame.card(box, "Keyboard hints · #{section_name(tab)}", border: Token::Cyan)
      lines = ["THIS VIEW", context_hint, "", "NAVIGATION",
               "Ctrl-P       Search views, commands and keyboard hints",
               "h / Esc      Open hints / close hints or clear filter",
               "b            Collapse or expand navigation",
               "q / Ctrl-C   Quit (Ctrl-C cancels inside Console)",
               "", "VIEWS"]
      navigation_tabs.each { |section| lines << "#{shortcut(section).to_s.ljust(13)}#{section_name(section)}" }
      lines.concat(["", "LISTS AND OVERVIEW", "j/k or ↑/↓   Select a row", "Tab          Switch pane", "PgUp/PgDn    Scroll a page (SQL text in Overview)",
                    "Home/End     First/last row", "/            Filter data; Enter applies; Esc clears",
                    "f            Follow newest logs", "t            Toggle app output / azu/dev requests", "Enter        Open the focused Overview inspector"])
      unless @read_only
        lines.concat(["", "LOCAL COMMANDS", ":            Compose an azu command", "g            Compose a generator", "Enter, y/n   Review, then confirm/cancel a command",
                      "r            Rebuild application", "", "CONSOLE", "Enter        Evaluate", "Alt-Enter    Insert newline", "Ctrl-O       Interpreter", "Esc          Back; Ctrl-P opens hints/menu", "Letters are input while editing Console or search."])
      end
      @help_viewport.draw(frame, inner, Viewport.wrap(lines, Math.max(1, inner.w - 1)))
    end

    private def draw_inspector(frame : Frame, content : Rect) : Nil
      content = SQLTab.draw_metrics(frame, content, field(@snapshot, "sql")) if tab.sql?
      title = case tab
              when .sql?  then "SQL · #{SQLTab.feed_label(field(@snapshot, "sql"))}"
              when .auth? then @read_only ? "Auth · not exported" : "Auth · #{@auth.label}"
              when .logs? then using_shared_logs? ? "Logs · azu/dev requests" : "Logs · application output"
              else             section_name(tab)
              end
      empty = if !query.empty? && !@rows[tab].empty?
                "No matching samples · Esc clears the filter"
              elsif tab.sql?
                "No SQL samples · check azu/cql schema attachment"
              elsif tab.auth?
                @auth.empty_message(@read_only)
              elsif tab.migrations?
                "No migration history supplied by the application adapter"
              elsif tab.db?
                "No adapter data · see integration contract"
              else
                "No samples received"
              end
      at = tab.jobs? ? @jobs_received : (tab.auth? && @auth.available? ? @auth.received : @received)
      @inspectors[tab].draw(frame, content, "#{title} · #{freshness(at)}", empty, highlighter(tab))
    end

    private def highlighter(section : Tab) : Proc(String, Array(Seg))?
      return SQL_COLOR if section.sql?
      return LOG_COLOR if section.logs? || section.server?
      nil
    end

    private def draw_menu(frame : Frame) : Nil
      width = Math.min(55, frame.width - 4)
      height = Math.min(13, frame.height - 4)
      # Anchored like a command launcher, leaving the overview visible above it.
      box = Rect.new(frame.width - width - 3, frame.height - height - 3, width, height)
      frame.fill(box, style: frame.style(bg: Token::Backplate))
      inner = frame.card(box, "Navigate", border: Token::Cyan, title_color: Token::Cyan)
      frame.text(inner.x, inner.y, "> #{@menu_query}▏", Token::Cyan, max: inner.w)
      frame.hline(inner.x, inner.y + 1, inner.w, frame.style(Token::Border))
      list = Rect.new(inner.x, inner.y + 2, inner.w, Math.max(0, inner.h - 4))
      labels = menu_items.map_with_index do |item, index|
        Width.pad("#{index == @menu_selected ? '›' : ' '} #{item[0]}", Math.max(0, list.w - 5)) + "[#{item[1]}]"
      end
      @menu_viewport.configure(labels.size, list.h)
      @menu_viewport.reveal(@menu_selected)
      @menu_viewport.draw(frame, list, labels, @menu_selected)
      frame.text(inner.x, inner.bottom - 1, "↑/↓ choose · Enter open · Esc close", Token::Muted, max: inner.w)
    end

    private def dashboard(frame : Frame, area : Rect) : Nil
      metrics, body = area.split_top(area.w < 88 ? 8 : 6)
      draw_metrics(frame, metrics)
      queue_height = body.h >= 18 ? Math.min(9, body.h // 3) : 0
      main, queues = body.split_top(body.h - queue_height)
      if main.w >= 88
        logs, sql = main.split_left(main.w * 61 // 100, 1)
        draw_live_logs(frame, logs)
        draw_sql_preview(frame, sql)
      elsif @overview_focus == 1
        draw_sql_preview(frame, main)
      elsif @overview_focus == 2
        draw_queues(frame, main)
      else
        draw_live_logs(frame, main)
      end
      draw_queues(frame, queues) if queue_height > 0
    end

    private def draw_metrics(frame : Frame, area : Rect) : Nil
      requests = field(@snapshot, "requests")
      pool = field(field(@snapshot, "sql"), "pool")
      jobs = @jobs
      available_jobs = jobs.try { |sample| sample.error ? nil : sample.queues }
      active = available_jobs.try(&.sum(&.processing))
      waiting = available_jobs.try(&.sum(&.pending))
      cards = if area.w < 88
                top, bottom = area.split_top(4)
                top.columns(2, 1) + bottom.columns(2, 1)
              else
                area.columns(4, 1)
              end
      titles = {"Requests", "JoobQ", "CQL pool", "Auth"}
      values = {"#{text(requests, "rps")} req/s", "#{active || "--"} processing", "#{text(pool, "in_flight")} / #{SQLTab.pool_capacity(pool)} in use",
                @read_only ? "not exported" : "#{@rows[Tab::Auth].size} recent events"}
      notes = {"p95 #{text(requests, "p95_ms")}ms", "#{waiting || "--"} waiting", "idle #{text(pool, "idle")}",
               @read_only ? "read only" : (@auth.available? ? "application events" : "HTTP only")}
      cards.each_with_index do |rect, index|
        inner = frame.card(rect, titles[index], border: Token::Border)
        frame.text(inner.x, inner.y, values[index], Token::Cyan, max: inner.w)
        frame.text(inner.x, inner.y + 1, notes[index], Token::Muted, max: inner.w) if inner.h >= 2
        next if inner.h < 3
        if index == 0 && !@request_history.empty?
          chart = Widgets.sparkline(@request_history, inner.w // 2, frame.glyphs).chars.map { |char| "#{char}#{char}" }.join
          frame.gradient(inner.x, inner.bottom - 1, chart)
        elsif index == 2 && DiagnosticData.number(pool, "max") > 0
          gauge(frame, Rect.new(inner.x, inner.bottom - 1, inner.w, 1), DiagnosticData.number(pool, "in_flight") / DiagnosticData.number(pool, "max"))
        elsif index == 1 && active && waiting && active + waiting > 0
          gauge(frame, Rect.new(inner.x, inner.bottom - 1, inner.w, 1), active.to_f / (active + waiting))
        else
          frame.text(inner.x, inner.bottom - 1, index == 3 ? "#{@auth.available? ? freshness(@auth.received) : "adapter needed"}" : "#{freshness(index == 1 ? @jobs_received : @received)}", Token::Muted, max: inner.w)
        end
      end
    end

    private def gauge(frame : Frame, area : Rect, fraction : Float64) : Nil
      full, empty = Widgets.meter(fraction, Math.max(0, area.w), frame.glyphs.spark.last, frame.glyphs.spark.last)
      frame.gradient(area.x, area.y, full)
      frame.text(area.x + full.size, area.y, empty, Token::Faint, max: empty.size)
    end

    private def draw_live_logs(frame : Frame, rect : Rect) : Nil
      title = "Live logs · #{using_shared_logs? ? "azu/dev" : (@follow_logs ? "following" : "paused")}"
      inner = frame.card(rect, title, @overview_focus == 0 ? "focus" : nil, border: Token::Border)
      inspector = @inspectors[Tab::Logs]
      if inspector.items.empty?
        empty = query.empty? ? (using_shared_logs? ? "No request samples · require azu/dev + PERFORMANCE_MONITORING=true" : "Waiting for application logs") : "No matching logs · Esc clears filter"
        frame.text(inner.x, inner.y, empty, Token::Muted, max: inner.w)
        return
      end
      lines = inspector.items.reverse.map(&.label)
      inspector.list.configure(lines.size, inner.h)
      selected = lines.size - 1 - inspector.selected
      @overview_logs.configure(lines.size, inner.h)
      @overview_logs.reveal(selected)
      @overview_logs.draw(frame, inner, lines, @overview_focus == 0 ? selected : nil, LOG_COLOR)
    end

    private def draw_sql_preview(frame : Frame, rect : Rect) : Nil
      inner = frame.card(rect, "SQL · selected query", @overview_focus == 1 ? "focus" : nil, border: Token::Border)
      inspector = @inspectors[Tab::SQL]
      unless selected = inspector.selected_item
        frame.text(inner.x, inner.y, "No SQL samples received", Token::Muted, max: inner.w)
        return
      end
      # Lexical formatting only: quoted SQL literals are indivisible tokens.
      source = selected.details.first? || selected.label
      formatted = String.build do |io|
        Highlight.sql(source).each do |seg|
          io << '\n' if seg.style.fg == Token::Purple && {"FROM", "WHERE", "ORDER", "GROUP", "LIMIT", "JOIN", "LEFT", "INNER", "HAVING", "RETURNING", "AND"}.includes?(seg.text.upcase)
          io << seg.text
        end
      end
      lines = Viewport.wrap(formatted.lines.map(&.strip), Math.max(1, inner.w - 6))
      code_height = Math.min(lines.size, Math.max(1, inner.h - 10))
      code, details = inner.split_top(code_height)
      numbered = lines.map_with_index { |line, i| "#{(i + 1).to_s.rjust(2, '0')}  #{line}" }
      @overview_sql.draw(frame, code, numbered, highlight: ->(line : String) { [Seg[line[0, 4], Token::Muted]] + Highlight.sql(line[4..]) })
      return if details.h < 3
      frame.hline(details.x, details.y, details.w, frame.style(Token::Border))
      # Duration, caller and pool wait come from the selected query's actual row.
      metadata = selected.details.reject { |line| line.empty? || line == source }
      frame.text(details.x, details.y + 1, metadata.first? || "Origin: not supplied", Token::Cyan, max: details.w)
      frame.text(details.x, details.y + 2, metadata[1]? || "", Token::Muted, max: details.w)
      return if details.h < 8
      frame.text(details.x, details.y + 3, metadata[2]? || "", Token::Cyan, max: details.w)
      alerts = DiagnosticData.rows(field(@snapshot, "sql"), "n_plus_one", 30)
      frame.text(details.x, details.y + 4, alerts.empty? ? "No N+1 warnings reported" : "N+1 · #{alerts.size} #{alerts.size == 1 ? "pattern" : "patterns"} · 5 opens SQL", alerts.empty? ? Token::Muted : Token::Amber, max: details.w)
      frame.hline(details.x, details.y + 5, details.w, frame.style(Token::Border))
      frame.text(details.x, details.y + 6, "#{SQLTab.feed_label(field(@snapshot, "sql")).capitalize} · #{inspector.items.size} samples", Token::Purple, max: details.w)
      list = Rect.new(details.x, details.y + 7, details.w, details.h - 7)
      inspector.list.configure(inspector.items.size, list.h)
      @overview_queries.configure(inspector.items.size, list.h)
      @overview_queries.reveal(inspector.selected)
      @overview_queries.draw(frame, list, inspector.items.map(&.label), inspector.selected, SQL_COLOR)
    end

    private def draw_queues(frame : Frame, rect : Rect) : Nil
      inner = frame.card(rect, "Queues & activity", @overview_focus == 2 ? "focus" : freshness(@jobs_received), border: Token::Border)
      return if inner.empty?
      if @jobs.nil? || @jobs.try(&.error)
        frame.text(inner.x, inner.y, "Queue telemetry unavailable · configure the JoobQ sampler", Token::Muted, max: inner.w)
        return
      end
      widths = {Math.min(16, Math.max(10, inner.w // 4)), 10, 12, 8}
      headings = "#{Width.pad("QUEUE", widths[0])}#{Width.pad("WAITING", widths[1])}#{Width.pad("PROCESSING", widths[2])}FAILED"
      frame.text(inner.x, inner.y, headings, Token::Muted, max: inner.w)
      chart_x = inner.x + widths.sum
      chart_width = inner.right - chart_x
      if chart_width >= 20
        frame.text(chart_x, inner.y, "Share of waiting jobs", Token::Muted, max: chart_width)
      end
      frame.hline(inner.x, inner.y + 1, inner.w, frame.style(Token::Border)) if inner.h > 1
      inspector = @inspectors[Tab::Jobs]
      queues = @jobs.try(&.queues) || [] of Events::Queue
      lines = inspector.items.map do |item|
        queue = queues.find { |sample| sample.name == item.id }
        next item.label unless queue
        "#{Width.pad(queue.name, widths[0])}#{Width.pad(queue.pending.to_s, widths[1])}#{Width.pad(queue.processing.to_s, widths[2])}#{queue.failed}"
      end
      area = Rect.new(inner.x, inner.y + 2, inner.w, Math.max(0, inner.h - 2))
      @overview_queues.configure(lines.size, area.h)
      inspector.list.configure(lines.size, area.h)
      @overview_queues.reveal(inspector.selected)
      @overview_queues.draw(frame, area, lines, @overview_focus == 2 ? inspector.selected : nil)
      total = queues.sum(&.pending)
      if chart_width >= 20 && total > 0
        inspector.items.skip(@overview_queues.offset).first(area.h).each_with_index do |item, row|
          if queue = queues.find { |sample| sample.name == item.id }
            gauge(frame, Rect.new(chart_x, area.y + row, chart_width - 2, 1), queue.pending.to_f / total)
          end
        end
      end
    end
  end
end
