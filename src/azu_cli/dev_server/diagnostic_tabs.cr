require "../ui"
require "json"

module AzuCLI::DevServer
  # Tolerates absent fields from older apps; no unchecked JSON casts in the render path.
  module DiagnosticData
    def self.field(value : JSON::Any?, key : String) : JSON::Any?
      value.try(&.as_h?).try(&.[key]?)
    end

    def self.rows(value : JSON::Any?, key : String, limit = 100) : Array(JSON::Any)
      field(value, key).try(&.as_a?).try(&.first(limit)) || [] of JSON::Any
    end

    def self.text(value : JSON::Any?, key : String, fallback = "—") : String
      found = field(value, key)
      return fallback unless found
      found.as_s? || (found.raw.nil? ? fallback : found.to_json)
    end

    def self.number(value : JSON::Any?, key : String) : Float64
      found = field(value, key)
      number = found.try { |item| item.as_f? || item.as_i64?.try(&.to_f) } || 0.0
      number.finite? ? number : 0.0
    end
  end

  class ErrorsTab
    getter inspector = UI::Inspector.new
    getter? available = false

    def update(snapshot : JSON::Any) : Nil
      errors = DiagnosticData.field(snapshot, "errors")
      @available = !errors.nil? && !!errors.try(&.as_a?)
      rows = errors.try(&.as_a?).try(&.first(100)) || [] of JSON::Any
      inspector.replace(rows.compact_map do |row|
        next unless row.as_h?
        details = ["#{DiagnosticData.text(row, "class")}: #{DiagnosticData.text(row, "message")}",
                   "Request: #{DiagnosticData.text(row, "route")}", "", "RFC 7807 problem details:",
                   DiagnosticData.field(row, "problem").try(&.to_pretty_json) || "Not supplied",
                   "", "Request parameters (redacted by app):", DiagnosticData.field(row, "params").try(&.to_pretty_json) || "Not supplied",
                   "", "Stack trace:"]
        DiagnosticData.rows(row, "frames", 100).each { |entry| details << (entry.as_s? || entry.to_json) }
        UI::Inspector::Item.new(DiagnosticData.text(row, "id"),
          "#{DiagnosticData.text(row, "at")} #{DiagnosticData.text(row, "route")} #{DiagnosticData.text(row, "class")}", details)
      end)
    end

    def key(key : UI::Key) : Bool
      inspector.key(key)
    end

    def draw(frame : UI::Frame, rect : UI::Rect) : Nil
      inspector.draw(frame, rect, "Errors", available? ? "No captured exceptions" : "Waiting for errors · update azu/dev telemetry")
    end
  end

  class SQLTab
    getter inspector = UI::Inspector.new
    @data : JSON::Any?

    def update(snapshot : JSON::Any) : Nil
      @data = DiagnosticData.field(snapshot, "sql")
      inspector.replace(self.class.items(@data))
    end

    # Both HUDs consume the same producer contract: older Azu versions export
    # slowest samples, newer versions also export recent queries and origins.
    def self.items(data : JSON::Any?) : Array(UI::Inspector::Item)
      rows = DiagnosticData.rows(data, "recent", 200)
      rows = DiagnosticData.rows(data, "slowest", 200) if rows.empty?
      items = rows.compact_map do |row|
        next unless row.as_h?
        sql = DiagnosticData.text(row, "sql")[0, 4096]
        origin = DiagnosticData.text(row, "caller", DiagnosticData.text(row, "model", DiagnosticData.text(row, "endpoint")))
        UI::Inspector::Item.new(DiagnosticData.text(row, "id", sql),
          "#{DiagnosticData.text(row, "at", "")} #{DiagnosticData.text(row, "ms")} ms #{origin} #{sql}",
          [sql, "", "Duration: #{DiagnosticData.text(row, "ms")} ms", "Origin: #{origin}",
           "Pool wait: #{DiagnosticData.text(row, "pool_wait_ms")} ms", "Endpoint: #{DiagnosticData.text(row, "endpoint")}"])
      end
      alerts = DiagnosticData.rows(data, "n_plus_one", 30)
      alerts.each_with_index do |alert, index|
        sql = DiagnosticData.text(alert, "sql")[0, 4096]
        items << UI::Inspector::Item.new("n+1:#{index}:#{sql}", "N+1 ×#{DiagnosticData.text(alert, "count")} #{sql}",
          ["N+1 ×#{DiagnosticData.text(alert, "count")}", sql, DiagnosticData.text(alert, "caller"), DiagnosticData.text(alert, "endpoint"), DiagnosticData.text(alert, "suggestion")])
      end
      items
    end

    def self.feed_label(data : JSON::Any?) : String
      DiagnosticData.rows(data, "recent", 1).empty? && !DiagnosticData.rows(data, "slowest", 1).empty? ? "slowest sample" : "recent queries"
    end

    def key(key : UI::Key) : Bool
      inspector.key(key)
    end

    def self.draw_metrics(frame : UI::Frame, rect : UI::Rect, data : JSON::Any?) : UI::Rect
      metrics, body = rect.split_top(Math.min(5, Math.max(0, rect.h - 6)))
      unless metrics.empty?
        left, right = metrics.columns(2, 1)
        pool = DiagnosticData.field(data, "pool")
        inner = frame.card(left, "SQL · Pool")
        unless inner.empty?
          frame.text(inner.x, inner.y, "#{DiagnosticData.text(data, "total")} queries · avg #{DiagnosticData.text(data, "avg_ms")} ms", UI::Token::Cyan, max: inner.w)
          if inner.h > 1
            frame.text(inner.x, inner.y + 1, "checkouts #{DiagnosticData.text(pool, "in_flight")}/#{DiagnosticData.text(pool, "max")} · idle #{DiagnosticData.text(pool, "idle")}", UI::Token::Muted, max: inner.w)
          end
          alerts = DiagnosticData.rows(data, "n_plus_one", 100)
          frame.text(inner.x, inner.y + 2, "N+1 warnings: #{alerts.size} · slow #{DiagnosticData.text(data, "slow")}", UI::Token::Amber, max: inner.w) if inner.h > 2
        end
        inner = frame.card(right, "Latency histogram · ms")
        buckets = DiagnosticData.rows(data, "histogram", 10)
        lines = buckets.map { |bucket| "#{DiagnosticData.text(bucket, "label")} #{"█" * DiagnosticData.number(bucket, "bar").to_i.clamp(0, 12)} #{DiagnosticData.text(bucket, "count")}" }
        lines << "Not supplied by this exporter" if lines.empty?
        # Three compact rows preserve every bucket in a short metrics card.
        lines.each_slice(2).with_index do |pair, index|
          break if index >= inner.h
          frame.text(inner.x, inner.y + index, pair.join("  "), UI::Token::Cyan, max: inner.w)
        end
      end
      body
    end

    def draw(frame : UI::Frame, rect : UI::Rect) : Nil
      return if rect.empty?
      body = self.class.draw_metrics(frame, rect, @data)
      inspector.draw(frame, body, "Live queries · N+1", @data ? "No captured queries" : "Waiting for azu/cql telemetry")
    end
  end
end
