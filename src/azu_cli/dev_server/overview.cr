module AzuCLI::DevServer
  class MissionControl
    @overview_page = 0
    @overview_pages = 1
    @overview_count = 1
    @visible_cards = [] of DashboardState::Card
    @overview_feeds = false
    @overview_logs = Viewport.new
    @overview_sql = Viewport.new

    private def overview_feed : Tab?
      return nil unless @overview_feeds
      case @overview_focus - @visible_cards.size
      when 0 then Tab::Logs
      when 1 then Tab::SQL
      end
    end

    private def overview_key(key : Key) : Nil
      if key.char?('[') || key.char?(']')
        @overview_page = (@overview_page + (key.char?(']') ? 1 : -1)).clamp(0, @overview_pages - 1)
        @overview_focus = 0
      elsif key.code.tab?
        @overview_focus = (@overview_focus + 1) % @overview_count
      elsif key.code.back_tab?
        @overview_focus = (@overview_focus - 1) % @overview_count
      elsif key.code.enter?
        if feed = overview_feed
          select_tab(feed)
        elsif card = @visible_cards[@overview_focus]?
          target = case card.target
                   when "Routes" then Tab::Server
                   else               Tab.parse?(card.target)
                   end
          select_tab(target) if target
        end
      elsif feed = overview_feed
        viewport = feed.logs? ? @overview_logs : @overview_sql
        viewport.key(key)
      elsif key.code.down? || key.char?('j') || key.code.right?
        @overview_focus = (@overview_focus + 1) % @overview_count
      elsif key.code.up? || key.char?('k') || key.code.left?
        @overview_focus = (@overview_focus - 1) % @overview_count
      end
    end

    private def dashboard(frame : Frame, area : Rect) : Nil
      banner, grid = area.split_top(Math.min(5, area.h))
      health = @dashboard.section("health")
      insights = DiagnosticData.rows(health, "insights", 5)
      color = health.nil? ? Token::Muted : (insights.empty? ? Token::Green : Token::Amber)
      inner = frame.card(banner, "System health", border: Token::Border)
      title = if health.nil?
                "n/a · Dashboard telemetry unavailable"
              elsif freshness(@received) != "connected"
                "#{text(health, "score")} · Stale sample · waiting for application"
              else
                "#{text(health, "score")} · #{insights.empty? ? "All systems nominal" : "#{insights.size} item(s) need attention"}"
              end
      frame.text(inner.x, inner.y, title, color, max: inner.w)
      note = insights.first?.try { |i| "#{text(i, "message")} · #{text(i, "detail")}" } || (@dashboard.data ? "Health of recorded traffic" : "Update azu/dev for shared dashboard metrics; existing inspectors remain available")
      frame.text(inner.x, inner.y + 1, note, Token::Muted, max: inner.w) if inner.h > 1
      return if grid.h < 3
      cards = @dashboard.cards
      columns = (grid.w // 22).clamp(1, 5)
      # Identical column geometry on every row, including incomplete rows.
      card_height = 9
      layout = cards.each_slice(columns).to_a
      available = grid.h - 1
      all_fit = layout.size * card_height + 8 <= available
      rows = Math.max(1, available // card_height)
      card_pages = (layout.size + rows - 1) // rows
      @overview_pages = all_fit ? 1 : card_pages + 1
      @overview_page = @overview_page.clamp(0, @overview_pages - 1)
      @overview_feeds = all_fit || @overview_page == card_pages
      visible = if all_fit
                  layout
                elsif @overview_feeds
                  [] of Array(DashboardState::Card)
                else
                  layout.skip(@overview_page * rows).first(rows)
                end
      @visible_cards = visible.flatten
      @overview_count = Math.max(1, @visible_cards.size + (@overview_feeds ? 2 : 0))
      @overview_focus = @overview_focus.clamp(0, @overview_count - 1)
      height = Math.min(card_height, available)
      index = 0
      visible.each_with_index do |group, row|
        line = Rect.new(grid.x, grid.y + row * height, grid.w, height)
        rectangles = overview_columns(line, columns)
        group.each_with_index do |card, column|
          draw_overview_card(frame, rectangles[column], card, index == @overview_focus)
          index += 1
        end
      end
      if @overview_feeds
        top = grid.y + visible.size * height
        feeds = overview_columns(Rect.new(grid.x, top, grid.w, grid.bottom - 1 - top), 2)
        draw_overview_feed(frame, feeds[0], Tab::Logs, @overview_logs)
        draw_overview_feed(frame, feeds[1], Tab::SQL, @overview_sql)
      end
      frame.text(grid.x, grid.bottom - 1, "Page #{@overview_page + 1}/#{@overview_pages} · [ / ] page · Tab focus · Enter inspect", Token::Muted, max: grid.w)
    end

    # Keep card widths identical; distribute spare cells across gutters so the
    # health banner, card rows and feed panes share both outside edges.
    private def overview_columns(rect : Rect, count : Int32) : Array(Rect)
      return [rect] if count == 1
      width = (rect.w - count + 1) // count
      space = rect.w - width * count
      gap, remainder = space.divmod(count - 1)
      Array.new(count) do |index|
        Rect.new(rect.x + index * (width + gap) + Math.min(index, remainder), rect.y, width, rect.h)
      end
    end

    private def draw_overview_feed(frame : Frame, rect : Rect, section : Tab, viewport : Viewport) : Nil
      sql = section.sql?
      label = sql ? "Latest queries" : "Latest logs"
      status = sql ? SQLTab.feed_label(field(@snapshot, "sql")) : (using_shared_logs? ? "azu/dev requests" : "application output")
      inner = frame.card(rect, label, status, border: overview_feed == section ? Token::Blue : Token::Border)
      items = @inspectors[section].items
      lines = items.map(&.label)
      if lines.empty?
        message = query.empty? ? (sql ? "No SQL samples received" : "No logs received") : "No matching entries"
        frame.text(inner.x, inner.y, message, Token::Muted, max: inner.w)
      else
        viewport.draw(frame, inner, lines, highlight: sql ? SQL_COLOR : LOG_COLOR)
      end
    end

    private def draw_overview_card(frame : Frame, rect : Rect, card : DashboardState::Card, selected : Bool) : Nil
      frame.fill(rect, style: frame.style(Token::Text, bg: Token::Surface))
      inner = frame.card(rect, card.title, border: selected ? Token::Blue : Token::Border, title_color: Token::Muted)
      chart = !card.series.empty? && inner.h >= 5
      count = chart ? inner.h - 3 : inner.h
      Viewport.wrap(card.lines, inner.w).first(count).each_with_index do |line, i|
        frame.text(inner.x, inner.y + i, line, frame.style(i == 0 ? Token::Text : Token::Muted, bg: Token::Surface), max: inner.w)
      end
      if chart
        Widgets.filled_bars(card.series, inner.w, frame.glyphs).each_with_index do |line, i|
          frame.text(inner.x, inner.bottom - 3 + i, line, frame.style(Token::Blue, bg: Token::Surface), max: inner.w)
        end
      end
    end
  end
end
