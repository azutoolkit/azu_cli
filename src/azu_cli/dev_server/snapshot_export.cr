require "json"
require "random/secure"

module AzuCLI::DevServer
  # One writer, atomic replacement, private directory; consumers never compete
  # for the application's telemetry socket. No application or DB calls here.
  class SnapshotExport
    @application : JSON::Any?
    @auth : JSON::Any?
    @identity : String?
    @mutex = Mutex.new

    def initialize(@path : String)
      raise ArgumentError.new("--snapshot requires an absolute path") unless Path[@path].absolute?
      directory = File.dirname(@path)
      Dir.mkdir_p(directory, 0o700)
      raise ArgumentError.new("Snapshot directory must be private (chmod 700)") unless File.info(directory).permissions.value & 0o077 == 0
      raise ArgumentError.new("Snapshot must not be a symlink") if File.symlink?(@path)
    end

    def write(snapshot : JSON::Any) : Nil
      @mutex.synchronize do
        if snapshot["stream"]?.try(&.as_s?) == "auth"
          fields = snapshot["auth"].as_h.dup
          fields["captured_at"] = JSON::Any.new(Time.utc.to_rfc3339)
          @auth = JSON::Any.new(fields)
        else
          process = snapshot["dashboard"]?.try(&.as_h?).try(&.["process"]?).try(&.as_h?) || snapshot["runtime"]?.try(&.as_h?)
          identity = process.try(&.["pid"]?).try(&.to_json)
          if identity && @identity && identity != @identity
            @auth = nil
          end
          @identity = identity if identity
          @application = snapshot
        end
        if application = @application
          fields = application.as_h.dup
          if auth = @auth
            fields["auth"] = auth
          end
          persist(JSON::Any.new(fields))
        end
      end
    end

    private def persist(snapshot : JSON::Any) : Nil
      data = snapshot.to_json
      return if data.bytesize > TelemetryServer::MAX_SNAPSHOT
      temporary = "#{@path}.#{Random::Secure.hex(6)}"
      File.write(temporary, data, perm: 0o600)
      File.rename(temporary, @path)
    rescue IO::Error
      # Keep the previous complete snapshot; consumers report it as stale.
      # A failed optional export must not interrupt the HUD receiver.
    ensure
      File.delete?(temporary) if temporary
    end
  end
end
