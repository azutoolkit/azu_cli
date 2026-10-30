require "./diagnostic_tabs"

module AzuCLI::DevServer
  # Azu::Dev::Telemetry v1, also backed by the web dashboard's
  # Dev.metrics (the configured PerformanceMonitor's metrics), QueryStore and
  # ErrorStore. The CLI receives serialized snapshots, not an in-process handle.
  module SharedTelemetry
    def self.request_logs(snapshot : JSON::Any?) : Array(UI::Inspector::Item)
      requests = DiagnosticData.field(snapshot, "requests")
      DiagnosticData.rows(requests, "recent", 200).compact_map do |row|
        next unless row.as_h?
        at = DiagnosticData.text(row, "at", "--")[0, 64]
        method = DiagnosticData.text(row, "method", "--")[0, 16]
        path = DiagnosticData.text(row, "path", "--")[0, 512]
        status = DiagnosticData.field(row, "status").try(&.as_i64?)
        severity = status && status >= 500 ? "ERROR" : (status && status >= 400 ? "WARN" : "INFO")
        label = "#{at} #{severity} HTTP #{method} #{path} #{status || "--"} #{DiagnosticData.text(row, "ms")}ms"
        id = "request:#{at}:#{method}:#{path}:#{status}:#{DiagnosticData.text(row, "ms")}"
        UI::Inspector::Item.new(id, label, [label,
                                            "Endpoint: #{DiagnosticData.text(row, "endpoint")[0, 512]}",
                                            "Source: Azu::Dev.metrics via Azu::Dev::Telemetry",
                                            "Retained request samples; not a complete access log."])
      end
    end

    def self.runtime_label(snapshot : JSON::Any?) : String
      runtime = DiagnosticData.field(snapshot, "runtime")
      heap = DiagnosticData.field(runtime, "heap_bytes").try(&.as_i64?)
      free = DiagnosticData.field(runtime, "free_bytes").try(&.as_i64?)
      parts = ["azu/dev v1"]
      parts << "heap #{UI::Widgets.bytes(heap)}" if heap && heap >= 0
      parts << "free #{UI::Widgets.bytes(free)}" if free && free >= 0
      parts.join(" · ")
    end
  end
end
