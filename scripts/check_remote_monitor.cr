# Live SSH integration harness. The Python driver supplies an isolated sshd.
require "../src/azu_cli/remote/monitor"

directory = ARGV[0]
path = File.join(directory, "snapshot.json")
wrapper = File.join(directory, "ssh-test")
target = AzuCLI::Remote::Target.new("fixture", path)
reader = AzuCLI::Remote::Reader.new(target, executable: wrapper, timeout: 2.seconds)
AzuMonitor::Snapshot.publish(path, JSON.parse(%({"v":1,"requests":{"rps":42},"sql":{"recent":[{"sql":"SECRET","ms":2}]}})))
snapshot = reader.read
raise "metrics missing" unless snapshot["requests"]["rps"].as_i == 42
raise "SQL disclosure" if snapshot.to_json.includes?("SECRET")

# The server key is known from the isolated test setup, never accepted on first use.
known_hosts = File.join(directory, "known_hosts")
trusted = File.read(known_hosts)
File.write(known_hosts, "")
begin
  reader.read
  raise "accepted an unknown host key"
rescue ex : IO::Error
ensure
  File.write(known_hosts, trusted)
end

authorized = File.join(directory, "authorized_keys")
authorized_key = File.read(authorized)
File.write(authorized, "")
begin
  reader.read
  raise "accepted an unauthorized client key"
rescue ex : IO::Error
ensure
  File.write(authorized, authorized_key)
end

File.write(path, %({"v":1,"captured_at":"2000-01-01T00:00:00Z"}))
begin
  reader.read
  raise "accepted stale data"
rescue ex : ArgumentError
end

File.write(path, "x" * (AzuMonitor::MAX_BYTES + 1))
begin
  reader.read
  raise "accepted oversized data"
rescue ex : IO::Error
end

# A slow remote command must not keep the local reader blocked.
slow = AzuCLI::Remote::Reader.new(target, executable: File.join(directory, "slow-test"), timeout: 50.milliseconds)
started = Time.instant
begin
  slow.read
  raise "accepted a stalled transport"
rescue ex : IO::Error
  raise "deadline not enforced" if Time.instant - started > 2.seconds
end
reader.stop
puts "SSH passed: authenticated snapshot, unknown-host/unauthorized-key rejection, redaction, stale/oversize rejection and deadline"
