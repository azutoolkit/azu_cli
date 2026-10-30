module AzuCLI::DevServer
  class MissionControl
    private def draw_section_metrics(frame : Frame, area : Rect) : Rect
      return area if area.h < 16
      metrics = case tab
                when .cache?
                  [{"Hit rate", @dashboard.value("cache", "hit_rate", "%")}, {"Operations", @dashboard.value("cache", "total")},
                   {"Error rate", @dashboard.value("cache", "error_rate", "%")}, {"Average time", @dashboard.value("cache", "avg_ms", " ms")}]
                when .components?
                  [{"Active", @dashboard.value("components", "active")}, {"Mounts", @dashboard.value("components", "mounts")},
                   {"Unmounts", @dashboard.value("components", "unmounts")}, {"Refreshes", @dashboard.value("components", "refreshes")}]
                when .database?
                  [{"Queries", @dashboard.value("database", "queries")}, {"Slow queries", @dashboard.value("database", "slow")},
                   {"N+1 patterns", @dashboard.value("database", "n_plus_one")}, {"Average time", @dashboard.value("database", "avg_ms", " ms")}]
                when .auth?
                  [{"Backend", @dashboard.value("sessions", "backend")}, {"Active sessions", @dashboard.value("sessions", "active")}]
                else [] of {String, String}
                end
      if tab.tracing?
        top, body = area.split_top(10)
        boxes = top.columns(2, 1)
        histogram = DiagnosticData.rows(@dashboard.section("tracing"), "histogram", 6)
        maximum = Math.max(1.0, histogram.max_of? { |r| DiagnosticData.number(r, "count") } || 0.0)
        inner = frame.card(boxes[0], "Latency distribution", border: Token::Border)
        histogram.first(inner.h).each_with_index do |bucket, i|
          label = "#{text(bucket, "label")} #{text(bucket, "count")}"
          frame.text(inner.x, inner.y + i, label, Token::Muted, max: inner.w)
          width = Math.max(0, inner.w - 20)
          bar, _ = Widgets.meter(DiagnosticData.number(bucket, "count") / maximum, width, '█', ' ')
          frame.text(inner.x + 20, inner.y + i, bar, Token::Green, max: width)
        end
        inner = frame.card(boxes[1], "Slowest requests", border: Token::Border)
        DiagnosticData.rows(@dashboard.section("tracing"), "slowest", inner.h).each_with_index do |r, i|
          frame.text(inner.x, inner.y + i, "#{text(r, "method")} #{text(r, "path")} #{text(r, "ms")} ms", Token::Text, max: inner.w)
        end
        return body
      elsif tab.profiler?
        graph, body = area.split_top(6)
        inner = frame.card(graph, "Memory trend · GC heap", border: Token::Border)
        values = @dashboard.histories["memory"]? || [] of Float64
        if values.empty?
          frame.text(inner.x, inner.y, "No memory samples", Token::Muted, max: inner.w)
        else
          Widgets.braille_sparkline(values, inner.w, frame.glyphs).each_with_index { |line, i| frame.text(inner.x, inner.y + i, line, Token::Blue, max: inner.w) }
        end
        return body
      end
      return area if metrics.empty?
      top, body = area.split_top(tab.auth? ? 6 : 5)
      if tab.auth?
        cards, source = top.split_top(5)
        top = cards
        shared_sessions = @dashboard.section("sessions").try(&.["backend"]?)
        source_label = shared_sessions ? "application session events" : @auth.label
        received = shared_sessions ? @received : @auth.received
        frame.text(source.x, source.y, "Source: #{source_label} · #{freshness(received)}", Token::Muted, max: source.w)
      end
      top.columns(metrics.size, 1).each_with_index do |box, i|
        title, value = metrics[i]
        inner = frame.card(box, title, border: Token::Border)
        frame.text(inner.x, inner.y, value, Token::Text, max: inner.w)
      end
      body
    end
  end
end
