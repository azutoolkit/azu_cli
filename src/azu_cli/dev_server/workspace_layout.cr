module AzuCLI::DevServer
  # Reference-inspired shell. Every pane paints into the shared frame; none owns
  # terminal IO. Small terminals retain the same routes and keyboard controls.
  class MissionControl
    @overview_focus = 0
    @overview_queues = Viewport.new

    private def section_name(section : Tab) : String
      case section
      when .dashboard? then "Overview"
      when .db?        then "Schema"
      when .auth?      then "Sessions"
      when .jobs?      then "Queues & Activity"
      when .server?    then "Routes"
      else                  section.to_s
      end
    end

    private def section_group(section : Tab) : String
      case section
      when .db?, .migrations?, .auth?, .sql?, .database?, .cache?                                                       then "Data & Access"
      when .jobs?, .joob_q?                                                                                             then "Jobs"
      when .console?, .commands?, .build?, .config?, .generators?, .serve?, .server?, .doctor?, .components?, .mailers? then "Develop"
      else                                                                                                                   "Observe"
      end
    end

    private def navigation_tabs : Array(Tab)
      NAVIGATION.select do |section|
        name = section_name(section).downcase
        tabs.includes?(section) && @dashboard.enabled?(name)
      end
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
      if tab.generators?
        draw_generators(frame, content)
      elsif tab.serve?
        @workspace.serve_view(frame, content)
      elsif !@read_only && (tab.doctor? || tab.server?)
        @workspace.command_output_view(frame, content, tab.doctor? ? "doctor" : "routes")
      elsif active = panel
        @workspace.panel_view(frame, content, active)
      elsif tab.jobs? && content.h >= 20
        queues, details = content.split_top(10)
        draw_queues(frame, queues)
        draw_inspector(frame, details)
      elsif tab.joob_q?
        @joobq.draw(frame, content, embedded: true)
      elsif tab.dashboard?
        dashboard(frame, content)
      else
        content = draw_database_nav(frame, content) if database_view?
        content = draw_section_metrics(frame, content)
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
        label = Width.pad("#{nav_icon(section, frame)} #{section.jobs? ? "Queues" : section_name(section)}", rail.w - 7) + "[#{shortcut(section)}]"
        labels << label
      end
      area = Rect.new(rail.x + 1, 7, rail.w - 2, Math.max(0, rail.h - 12))
      @nav_viewport.configure(labels.size, area.h)
      @nav_viewport.reveal(selection)
      @nav_viewport.draw(frame, area, labels, selection)
      labels.skip(@nav_viewport.offset).first(area.h).each_with_index do |label, row|
        if {"OBSERVE", "DATA & ACCESS", "JOBS", "DEVELOP"}.includes?(label)
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
      frame.text(header.x, header.y + 1, @notice, Token::Muted, max: header.w - reserve) if @read_only
      if @received && !@read_only && !@sample_data
        frame.text(header.x, header.y + 1, SharedTelemetry.runtime_label(@snapshot), Token::Muted, max: header.w - reserve)
      end
      frame.line(header.x, header.y, segments, header.w - reserve)
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
                "↑/↓ scroll · PgUp/PgDn page · Esc/? close · Ctrl-P navigate"
              elsif searching?
                "/ #{query}▏  Enter apply · Esc clear"
              elsif menu_open?
                "↑/↓ choose · Enter open · Esc close"
              elsif @read_only
                "Ctrl-P navigate · ? help · Tab pane · ↑/↓ select · / filter · q disconnect"
              elsif tab.console?
                "Ctrl-P menu · Enter run · Alt-Enter newline · Ctrl-O interpreter · Esc back"
              elsif tab.commands?
                "Ctrl-P menu · ↑/↓ select · Enter run · y confirm · PgUp/PgDn output · q quit"
              elsif !query.empty?
                "filter: #{query} · Esc clear · Ctrl-P navigate · q quit"
              elsif frame.width < 110
                "Ctrl-P menu · ? help · Tab pane · Enter open · q quit"
              else
                "Ctrl-P navigate · ? help · #{context_hint} · q quit"
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
        "Tab focus · ↑/↓ select/scroll · Enter open · [ ] page"
      when .logs?
        "Tab pane · ↑/↓ select · Enter inspect · / filter · f follow · t source"
      when .generators?
        "Enter compose generator · Esc close editor"
      when .serve?
        "Enter start/restart · r rebuild · PgUp/PgDn output"
      when .doctor?, .server?
        "Enter refresh · ↑/↓ scroll · PgUp/PgDn page"
      when .joob_q?
        "[ ] view · Tab pane · ↑/↓ select · r replay"
      when .build?
        "r rebuild · PgUp/PgDn scroll"
      when .config?
        "Enter refresh · PgUp/PgDn scroll"
      else
        "Tab pane · ↑/↓ select · Enter inspect · / filter · PgUp/PgDn scroll"
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
               "? or h       Keyboard help",
               "Esc          Close overlay / clear filter",
               "Alt-Left/Right Previous / next sidebar section",
               "b            Collapse or expand navigation",
               "q / Ctrl-C   Quit (Ctrl-C cancels inside Console)",
               "", "VIEWS"]
      navigation_tabs.each { |section| lines << "#{shortcut(section).to_s.ljust(13)}#{section_name(section)}" }
      lines.concat(["", "LISTS AND OVERVIEW", "j/k or ↑/↓   Select a row", "Tab          Switch pane", "PgUp/PgDn    Scroll the focused list or detail pane",
                    "Home/End     First/last row", "/            Filter data; Enter applies; Esc clears",
                    "f            Follow newest logs", "t            Toggle app output / azu/dev requests", "[ / ]        Overview pages / Database or JoobQ subviews", "s / u / i    SQL / Schema / Migrations", "Enter        Open the focused Overview card or feed"])
      unless @read_only
        lines.concat(["", "LOCAL TOOLS", "`            Console", "d / x / v    Build / Commands / Configuration", "S / a / D    Serve / Routes / Doctor", "", "LOCAL COMMANDS", ":            Compose an azu command", "g            Open Generators; Enter composes", "Enter, y/n   Review, then confirm/cancel a command",
                      "r            Rebuild application", "", "CONSOLE", "Enter        Evaluate", "Alt-Enter    Insert newline", "Ctrl-O       Interpreter", "Esc          Back; Ctrl-P opens hints/menu", "Letters are input while editing Console or search."])
      end
      @help_viewport.draw(frame, inner, Viewport.wrap(lines, Math.max(1, inner.w - 1)))
    end

    private def draw_inspector(frame : Frame, content : Rect) : Nil
      content = SQLTab.draw_metrics(frame, content, field(@snapshot, "sql")) if tab.sql?
      title = case tab
              when .sql?  then "SQL · #{SQLTab.feed_label(field(@snapshot, "sql"))}"
              when .auth? then @read_only ? "Sessions · not exported" : "Sessions · #{@dashboard.section("sessions") ? @dashboard.status("sessions") : @auth.label}"
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
      if {Tab::Tracing, Tab::Profiler, Tab::Cache, Tab::Components, Tab::Mailers, Tab::Runtime}.includes?(tab)
        name = tab.runtime? ? "process" : section_name(tab).downcase
        title += " · #{@dashboard.status(name)}"
        empty = "#{@dashboard.status(name)} · #{@dashboard.section(name) ? "No samples recorded" : "Application adapter not supplied"}"
      end
      empty = @jobs.try(&.error) || "No queue samples; configure config/joobq.development.yml or config/jobs.yml" if tab.jobs?
      @inspectors[tab].draw(frame, content, "#{tab.jobs? ? jobs_status : freshness(at)} · #{title}", empty, highlighter(tab))
    end

    private def jobs_status : String
      return "unavailable" if @jobs.try(&.error)
      status = freshness(@jobs_received)
      status == "connected" && !@read_only ? "Redis connected" : status
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

    private def gauge(frame : Frame, area : Rect, fraction : Float64) : Nil
      full, empty = Widgets.meter(fraction, Math.max(0, area.w), frame.glyphs.spark.last, frame.glyphs.spark.last)
      frame.gradient(area.x, area.y, full)
      frame.text(area.x + full.size, area.y, empty, Token::Faint, max: empty.size)
    end

    private def draw_queues(frame : Frame, rect : Rect) : Nil
      inner = frame.card(rect, "Queues & activity", @overview_focus == 2 ? "focus" : jobs_status, border: Token::Border)
      return if inner.empty?
      if @jobs.nil? || @jobs.try(&.error)
        frame.text(inner.x, inner.y, "Queue telemetry unavailable · configure the JoobQ sampler", Token::Muted, max: inner.w)
        return
      end
      widths = {Math.min(16, Math.max(10, inner.w // 4)), 10, 12, 8, 12}
      headings = "#{Width.pad("QUEUE", widths[0])}#{Width.pad("WAITING", widths[1])}#{Width.pad("PROCESSING", widths[2])}#{Width.pad("DLQ", widths[3])}COMPLETED"
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
        "#{Width.pad(queue.name, widths[0])}#{Width.pad(queue.pending.to_s, widths[1])}#{Width.pad(queue.processing.to_s, widths[2])}#{Width.pad(queue.failed.to_s, widths[3])}#{queue.completed || "--"}"
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

require "./overview"
require "./database_navigation"

require "./section_panels"

require "./develop_sections"
