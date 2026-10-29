require "json"
require "file/tempfile"

# Dependency-free publisher shared with the remote reader. Safe to copy into a
# production application; it does not enable azu/dev, a listener, or a console.
module AzuMonitor
  MAX_BYTES = 131_072

  module Snapshot
    def self.number(value : JSON::Any?, key : String) : JSON::Any?
      candidate = value.try(&.as_h?).try(&.[key]?)
      raw = candidate.try(&.raw)
      return unless raw.is_a?(Int64) || raw.is_a?(Float64)
      return unless raw.to_f.finite? && 0 <= raw <= 1e15
      candidate
    end

    def self.metrics(json : JSON::Builder, source : JSON::Any?, keys : Array(String)) : Nil
      keys.each { |key| number(source, key).try { |value| json.field(key, value) } }
    end

    # An allowlist, not a regex redactor: SQL, URLs, parameters, stack traces,
    # user identifiers and raw logs never enter the production HUD.
    def self.filter(data : JSON::Any, now : Time = Time.utc, require_fresh : Bool = true) : JSON::Any
      root = data.as_h? || raise ArgumentError.new("Snapshot must be an object")
      raise ArgumentError.new("Unsupported snapshot version") unless root["v"]?.try(&.as_i?) == 1
      if require_fresh
        stamp = root["captured_at"]?.try(&.as_s?) || raise ArgumentError.new("Snapshot has no captured_at")
        captured = Time.parse_rfc3339(stamp)
        age = now - captured
        raise ArgumentError.new("Snapshot is stale or its clock is ahead") if age > 30.seconds || age < -5.seconds
      end
      JSON.parse(JSON.build do |json|
        json.object do
          json.field "v", 1
          json.field "captured_at", require_fresh ? root["captured_at"] : JSON::Any.new(now.to_rfc3339)
          %w(requests sql).each do |section|
            source = root[section]?
            json.field section do
              json.object do
                metrics(json, source, %w(total rps p50_ms p95_ms p99_ms errors))
                if section == "sql"
                  json.field "pool" do
                    json.object { metrics(json, source.try(&.as_h?).try(&.["pool"]?), %w(in_flight max waiting idle)) }
                  end
                end
                json.field "recent" do
                  json.array do
                    rows = source.try(&.as_h?).try(&.["recent"]?).try(&.as_a?) || [] of JSON::Any
                    rows.first(100).each_with_index do |row, index|
                      next unless row.as_h?
                      json.object do
                        json.field "id", index.to_s
                        metrics(json, row, %w(ms status pool_wait_ms))
                        if section == "sql"
                          json.field "sql", "[statement redacted]"
                        else
                          method = row["method"]?.try(&.as_s?) || ""
                          json.field "method", %w(GET POST PUT PATCH DELETE HEAD OPTIONS).includes?(method) ? method : "?"
                          json.field "path", "[path redacted]"
                        end
                      end
                    end
                  end
                end
              end
            end
          end
          json.field "queues" do
            json.array do
              (root["queues"]?.try(&.as_a?) || [] of JSON::Any).first(100).each do |row|
                name = row.as_h?.try(&.["name"]?).try(&.as_s?)
                next unless name && name.matches?(/\A[A-Za-z0-9_.:-]{1,64}\z/)
                next unless %w(pending processing failed).all? { |key| number(row, key) }
                json.object do
                  json.field "name", name
                  metrics(json, row, %w(pending processing failed))
                end
              end
            end
          end
        end
      end)
    end

    def self.parse(text : String, now : Time = Time.utc) : JSON::Any
      raise ArgumentError.new("Snapshot exceeds 128 KiB") if text.bytesize > MAX_BYTES
      filter(JSON.parse(text), now)
    end

    # Directory must already exist with access restricted to the producer and
    # monitoring identity. Run publisher as that identity or set an explicit ACL.
    # Never overwrite in place: the SSH reader sees an entire old or new snapshot.
    def self.publish(path : String, data : JSON::Any) : Nil
      text = filter(data, require_fresh: false).to_json
      raise ArgumentError.new("Snapshot exceeds 128 KiB") if text.bytesize > MAX_BYTES
      temporary = File.tempfile(File.basename(path) + ".", ".tmp", dir: File.dirname(path))
      begin
        temporary.chmod(0o600)
        temporary << text
        temporary.flush
        temporary.close
        File.rename(temporary.path, path)
      ensure
        temporary.close
        File.delete?(temporary.path)
      end
    end
  end
end
