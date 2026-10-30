require "json"
require "random/secure"

module AzuCLI::DevServer
  # One writer, atomic replacement, private directory; consumers never compete
  # for the application's telemetry socket. No application or DB calls here.
  class SnapshotExport
    def initialize(@path : String)
      raise ArgumentError.new("--snapshot requires an absolute path") unless Path[@path].absolute?
      directory = File.dirname(@path)
      Dir.mkdir_p(directory, 0o700)
      raise ArgumentError.new("Snapshot directory must be private (chmod 700)") unless File.info(directory).permissions.value & 0o077 == 0
      raise ArgumentError.new("Snapshot must not be a symlink") if File.symlink?(@path)
    end

    def write(snapshot : JSON::Any) : Nil
      # Auth is a separate stream; do not replace the whole application snapshot.
      return if snapshot["stream"]?
      data = snapshot.to_json
      return if data.bytesize > TelemetryServer::MAX_SNAPSHOT
      temporary = "#{@path}.#{Random::Secure.hex(6)}"
      File.write(temporary, data, perm: 0o600)
      File.rename(temporary, @path)
    ensure
      File.delete?(temporary) if temporary
    end
  end
end
