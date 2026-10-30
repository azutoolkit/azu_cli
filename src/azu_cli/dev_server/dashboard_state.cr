require "./diagnostic_tabs"

module AzuCLI::DevServer
  # Transport decoding and bounded histories live here, never in drawing code.
  class DashboardState
    alias Data = DiagnosticData
    record Card, title : String, lines : Array(String), target : String, series : Array(Float64) = [] of Float64
    getter data : JSON::Any?
    getter histories = {} of String => Array(Float64)
    @identity = ""
    @stamp = ""
    @cards : Array(Card)?

    def reset : Nil
      @data = nil
      @cards = nil
      @histories.clear
      @identity = @stamp = ""
    end

    def update(snapshot : JSON::Any) : Bool
      incoming = Data.field(snapshot, "dashboard")
      process = Data.field(incoming, "process")
      identity = "#{Data.text(process, "pid")} / #{Data.text(process, "started_at")}"
      stamp = Data.text(snapshot, "at", "")
      return false if !stamp.empty? && @stamp == stamp && @identity == identity
      reset if @identity != identity
      @identity, @stamp, @data = identity, stamp, incoming
      @cards = nil
      %w(memory latency traffic).each do |name|
        @histories[name] = Data.rows(Data.field(data, "series"), name, 120).compact_map do |v|
          n = v.as_f? || v.as_i64?.try(&.to_f)
          n if n && n.finite? && n >= 0
        end
      end
      true
    end

    def section(name : String) : JSON::Any?
      Data.field(data, name)
    end

    def enabled?(name : String) : Bool
      Data.text(section("features"), name, "unavailable") != "disabled"
    end

    def status(name : String) : String
      Data.text(section("features"), name, section(name) ? "enabled" : "unavailable")
    end

    def value(section : String, key : String, suffix = "") : String
      found = Data.field(self.section(section), key)
      return "n/a" unless found && !found.raw.nil?
      return "#{found.as_i64}#{suffix}" if found.as_i64?
      number = found.as_f?
      "#{number ? number.round(2) : Data.text(self.section(section), key)}#{suffix}"
    end

    def cards : Array(Card)
      @cards ||= build_cards
    end

    private def build_cards : Array(Card)
      process = section("process")
      seconds = Data.number(process, "uptime_seconds")
      memory = Data.field(process, "rss_bytes").try(&.as_i64?)
      heap = Data.field(process, "heap_bytes").try(&.as_i64?)
      routes = Data.field(section("routes"), "methods").try(&.as_h?)
      result = [
        Card.new("Uptime", [process ? "#{seconds.to_i // 60}m #{seconds.to_i % 60}s" : "n/a", "Since #{value("process", "started_at")}"], "Runtime"),
        Card.new("Memory (RSS)", [memory ? UI::Widgets.bytes(memory) : "RSS unavailable", "GC heap #{heap ? UI::Widgets.bytes(heap) : "n/a"}", "GC heap samples"], "Profiler", histories["memory"]? || [] of Float64),
        Card.new("Latency", ["#{value("requests", "p50_ms", " ms")} p50", "#{value("requests", "p99_ms", " ms")} p99"], "Tracing", histories["latency"]? || [] of Float64),
        Card.new("Active routes", [value("routes", "total"), routes.try(&.map { |k, v| "#{v} #{k}" }.join(" / ")) || "Routes unavailable"], "Routes"),
        Card.new("Traffic", ["Requests #{value("requests", "total")}", "Throughput #{value("requests", "rps", " req/s")}"], "Tracing", histories["traffic"]? || [] of Float64),
        Card.new("Errors", ["Error rate #{value("requests", "error_rate", "%")}", "Failed requests #{value("requests", "failed")}"] + Data.rows(section("requests"), "recent_errors", 1).map { |r| "#{Data.text(r, "status")} #{Data.text(r, "method")} #{Data.text(r, "path")}" }, "Errors"),
      ]
      result << Card.new("Cache", ["Hit rate #{value("cache", "hit_rate", "%")}", "Operations #{value("cache", "total")}", "Errors #{value("cache", "error_rate", "%")}", "Average #{value("cache", "avg_ms", " ms")}", section("cache").nil? ? "Cache telemetry unavailable" : (value("cache", "hit_rate") == "n/a" ? "No cache reads recorded" : "")], "Cache") if enabled?("cache")
      result << Card.new("Database", ["Queries #{value("database", "queries")}", "Slow queries #{value("database", "slow")}", "N+1 patterns #{value("database", "n_plus_one")}", "Average #{value("database", "avg_ms", " ms")}"], "Database") if enabled?("database")
      result << Card.new("Components", ["Active #{value("components", "active")}", "Mounts / unmounts #{value("components", "mounts")} / #{value("components", "unmounts")}", "Refreshes #{value("components", "refreshes")}", "Average age #{value("components", "avg_age", " s")}"], "Components") if enabled?("components")
      result << Card.new("Runtime", ["Crystal #{value("process", "crystal")}", "Environment #{value("process", "environment")}", "Process ID #{value("process", "pid")}", "GC heap #{heap ? UI::Widgets.bytes(heap) : "n/a"}"], "Runtime")
      result
    end

    # Bounded inspectors keep data accessible at every terminal size.
    def items(name : String) : Array(UI::Inspector::Item)
      source = section(name)
      return [] of UI::Inspector::Item unless source
      rows = [] of UI::Inspector::Item
      source.as_h?.try(&.each do |key, value|
        next if value.raw.nil?
        if list = value.as_a?
          list.first(100).each_with_index do |entry, index|
            fields = entry.as_h?
            label = fields ? fields.map { |k, v| "#{k}: #{v.as_s? || v.to_json}" }.join(" · ")[0, 512] : entry.to_json[0, 512]
            rows << UI::Inspector::Item.new("#{name}:#{key}:#{index}", "#{key} · #{label}", entry.to_pretty_json.lines.first(200).map(&.[0, 1024]))
          end
        else
          rows << UI::Inspector::Item.new("#{name}:#{key}", "#{key}: #{value.as_s? || value.to_json[0, 512]}", value.to_pretty_json.lines.first(200).map(&.[0, 1024]))
        end
      end)
      rows
    end
  end
end
