module AzuCLI::DevServer
  class MissionControl
    @overview_page = 0
    @overview_pages = 1
    @overview_count = 1
    @visible_cards = [] of DashboardState::Card

    private def overview_key(key : Key) : Nil
      if key.char?('[') || key.char?(']')
        @overview_page = (@overview_page + (key.char?(']') ? 1 : -1)).clamp(0, @overview_pages - 1)
        @overview_focus = 0
      elsif key.code.tab? || key.code.down? || key.char?('j')
        @overview_focus = (@overview_focus + 1) % @overview_count
      elsif key.code.back_tab? || key.code.up? || key.char?('k')
        @overview_focus = (@overview_focus - 1) % @overview_count
      elsif key.code.enter?
        if card = @visible_cards[@overview_focus]?
          target = case card.target
                   when "Routes" then Tab::Server
                   else               Tab.parse?(card.target)
                   end
          select_tab(target) if target
        end
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
      primary_columns = (grid.w // 29).clamp(1, 4)
      secondary_columns = (grid.w // 29).clamp(1, 5)
      card_height = 9
      rows = Math.max(1, (grid.h - 1) // card_height)
      layout = [] of {Array(DashboardState::Card), Int32}
      cards.first(4).each_slice(primary_columns) { |group| layout << {group, primary_columns} }
      cards.skip(4).each_slice(secondary_columns) { |group| layout << {group, secondary_columns} }
      @overview_pages = Math.max(1, (layout.size + rows - 1) // rows)
      @overview_page = @overview_page.clamp(0, @overview_pages - 1)
      visible = layout.skip(@overview_page * rows).first(rows)
      @visible_cards = visible.flat_map(&.[0])
      @overview_count = Math.max(1, @visible_cards.size)
      @overview_focus = @overview_focus.clamp(0, @overview_count - 1)
      height = Math.min(card_height, Math.max(3, (grid.h - 1) // rows))
      index = 0
      visible.each_with_index do |(group, columns), row|
        line = Rect.new(grid.x, grid.y + row * height, grid.w, height)
        rectangles = line.columns(columns, 1)
        group.each_with_index do |card, column|
          draw_overview_card(frame, rectangles[column], card, index == @overview_focus)
          index += 1
        end
      end
      frame.text(grid.x, grid.bottom - 1, "Page #{@overview_page + 1}/#{@overview_pages} · [ / ] page · Tab select · Enter inspect", Token::Muted, max: grid.w)
    end

    private def draw_overview_card(frame : Frame, rect : Rect, card : DashboardState::Card, selected : Bool) : Nil
      frame.fill(rect, style: frame.style(Token::Text, bg: Token::Surface))
      inner = frame.card(rect, card.title, border: selected ? Token::Blue : Token::Border, title_color: Token::Muted)
      chart = !card.series.empty? && inner.h >= 4
      count = chart ? inner.h - 2 : inner.h
      card.lines.first(count).each_with_index do |line, i|
        frame.text(inner.x, inner.y + i, line, frame.style(i == 0 ? Token::Text : Token::Muted, bg: Token::Surface), max: inner.w)
      end
      if chart
        Widgets.braille_sparkline(card.series, inner.w, frame.glyphs).each_with_index do |line, i|
          frame.text(inner.x, inner.bottom - 2 + i, line, frame.style(Token::Blue, bg: Token::Surface), max: inner.w)
        end
      end
    end
  end
end
