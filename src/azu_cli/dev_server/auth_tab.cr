require "./diagnostic_tabs"

module AzuCLI::DevServer
  # Authentication outcomes must come from the app's authentication boundary.
  # HTTP 200/303 cannot distinguish successful login from a rejected form.
  class AuthTab
    getter received : Time::Instant?
    @data : JSON::Any?

    def reset : Nil
      @data = nil
      @received = nil
    end

    def update(snapshot : JSON::Any, now : Time::Instant) : Nil
      data = DiagnosticData.field(snapshot, "auth")
      return unless data.try(&.as_h?) && DiagnosticData.field(data, "recent").try(&.as_a?)
      @data = data
      @received = now
    end

    def available? : Bool
      !@data.nil?
    end

    def label : String
      available? ? "application events" : "HTTP activity · outcome unknown"
    end

    def empty_message(read_only : Bool) : String
      return "Auth events are not exported by the production monitor" if read_only
      available? ? "No authentication events yet · sign in to capture one" : "No auth activity · enable auth_telemetry for verified outcomes"
    end

    def items(requests : JSON::Any?) : Array(UI::Inspector::Item)
      return request_items(requests) unless available?
      DiagnosticData.rows(@data, "recent", 200).compact_map do |row|
        next unless row.as_h?
        event = value(row, "event")
        outcome = value(row, "outcome")
        at = value(row, "at")
        label = "#{at} #{event} #{outcome}"
        UI::Inspector::Item.new(value(row, "id", label), label,
          ["Event: #{event}", "Outcome: #{outcome}", "Time: #{at}", "Source: application authentication callback",
           "", "No credentials, cookies or user identifiers are collected.",
           "Active sessions cannot be counted from cookie sessions."])
      end
    end

    private def value(row : JSON::Any, key : String, fallback = "--") : String
      DiagnosticData.field(row, key).try(&.as_s?).try(&.[0, 128]) || fallback
    end

    private def request_items(requests : JSON::Any?) : Array(UI::Inspector::Item)
      DiagnosticData.rows(requests, "recent", 200).compact_map do |row|
        next unless row.as_h?
        # Never display query strings (OAuth codes, tokens, email addresses).
        path = value(row, "path").split('?', 2).first
        method = value(row, "method")
        next unless {"POST", "DELETE"}.includes?(method)
        next unless {"/login", "/logout", "/register", "/sign_in", "/sign_out", "/sign_up", "/sessions"}.includes?(path)
        at = value(row, "at")
        status = DiagnosticData.field(row, "status").try(&.as_i64?).try(&.to_s) || "--"
        label = "#{at} #{method} #{path} HTTP #{status} · unknown"
        UI::Inspector::Item.new(value(row, "id", label), label,
          ["#{method} #{path}", "HTTP status: #{status}", "Time: #{at}", "Authentication outcome: unknown",
           "", "A redirect or HTTP success does not prove authentication.",
           "Add src/services/auth_telemetry.cr and record the outcome",
           "after your authentication/session operation succeeds.",
           "See docs/architecture/mission-control.md (Auth integration)."])
      end
    end
  end
end
