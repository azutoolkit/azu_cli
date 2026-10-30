require "json"
require "socket"

# Copyable, dependency-free development adapter. No user IDs, credentials,
# cookies or request parameters enter this stream. This is not an audit log.
module AzuAuthTelemetry
  record Entry, id : String, at : String, event : String, outcome : String

  class Store
    LIMIT = 200
    @entries = [] of Entry
    @sequence = 0_i64
    @mutex = Mutex.new
    @instance = "#{Process.pid}-#{Time.utc.to_unix_ms}"

    def record(event : String, outcome : String) : Nil
      return unless {"sign-in", "sign-out", "sign-up"}.includes?(event)
      return unless {"accepted", "rejected", "throttled"}.includes?(outcome)
      @mutex.synchronize do
        @sequence += 1
        @entries.shift if @entries.size >= LIMIT
        @entries << Entry.new("#{@instance}-#{@sequence}", Time.utc.to_rfc3339, event, outcome)
      end
    end

    def snapshot : String
      entries, total = @mutex.synchronize { {@entries.dup, @sequence} }
      JSON.build do |json|
        json.object do
          json.field "v", 1
          json.field "stream", "auth"
          json.field "auth" do
            json.object do
              json.field "total", total
              json.field "recent" do
                json.array do
                  entries.reverse_each do |entry|
                    json.object do
                      json.field "id", entry.id
                      json.field "at", entry.at
                      json.field "event", entry.event
                      json.field "outcome", entry.outcome
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  # Capture only when azu dev explicitly supplies its private socket. A single
  # reporter owns the connection; request fibers only append to the bounded ring.
  PATH  = ENV["CRYSTAL_ENV"]? == "production" ? nil : ENV["AZU_TELEMETRY_SOCKET"]?.try(&.presence)
  STORE = Store.new

  def self.record(event : String, outcome : String) : Nil
    STORE.record(event, outcome) if PATH
  end

  def self.report(path : String) : Nil
    socket : UNIXSocket? = nil
    loop do
      begin
        socket ||= UNIXSocket.new(path)
        socket.write_timeout = 250.milliseconds
        socket.puts STORE.snapshot
        socket.flush
      rescue IO::Error | Socket::Error
        socket.try(&.close) rescue nil
        socket = nil
      end
      sleep 1.second
    end
  end

  if path = PATH
    spawn(name: "azu-auth-telemetry") { report(path) }
  end
end
