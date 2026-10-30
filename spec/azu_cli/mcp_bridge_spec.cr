require "../spec_helper"
require "../../src/azu_cli/mcp_bridge"
require "../../src/azu_cli/dev_server/snapshot_export"
require "../../src/azu_cli/dev_server/telemetry"

describe AzuCLI::MCPBridge do
  it "rejects stale plans before writing any files" do
    root = File.join(Dir.tempdir, "azu-mcp-bridge-#{Random::Secure.hex(6)}")
    Dir.mkdir_p(File.join(root, "src"))
    File.write(File.join(root, "src/existing.cr"), "edited")
    plan = JSON.parse({version: 1, project: File.realpath(root), files: [
      {path: "src/new.cr", before_sha256: nil, after_sha256: Digest::SHA256.hexdigest("new"), content: "new"},
      {path: "src/existing.cr", before_sha256: Digest::SHA256.hexdigest("old"), after_sha256: Digest::SHA256.hexdigest("changed"), content: "changed"},
    ]}.to_json)
    expect_raises(Exception, /Project changed/) { AzuCLI::MCPBridge.apply(plan, root) }
    File.exists?(File.join(root, "src/new.cr")).should be_false
  ensure
    FileUtils.rm_rf(root) if root
  end

  it "rejects symlink parents for new output paths" do
    root = File.join(Dir.tempdir, "azu-mcp-symlink-#{Random::Secure.hex(6)}")
    Dir.mkdir_p(root)
    File.symlink("/tmp", File.join(root, "escape"))
    expect_raises(Exception, /escapes/) { AzuCLI::MCPBridge.safe_path(root, "escape/new.cr") }
  ensure
    FileUtils.rm_rf(root) if root
  end
end

describe AzuCLI::DevServer::SnapshotExport do
  it "exports the application snapshot privately and ignores separate auth streams" do
    root = File.join(Dir.tempdir, "azu-mcp-export-#{Random::Secure.hex(6)}")
    path = File.join(root, "snapshot.json")
    writer = AzuCLI::DevServer::SnapshotExport.new(path)
    writer.write(JSON.parse(%({"v":1,"runtime":{"pid":123}})))
    File.info(path).permissions.value.should eq(0o600)
    writer.write(JSON.parse(%({"v":1,"stream":"auth","auth":{}})))
    JSON.parse(File.read(path))["runtime"]["pid"].as_i.should eq(123)
  ensure
    FileUtils.rm_rf(root) if root
  end
end
