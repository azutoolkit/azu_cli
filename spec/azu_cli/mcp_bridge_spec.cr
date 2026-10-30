require "../spec_helper"
require "../../src/azu_cli/mcp_bridge"
require "../../src/azu_cli/dev_server/snapshot_export"
require "../../src/azu_cli/dev_server/telemetry"

describe AzuCLI::MCPBridge do
  it "keeps nested database files and symlinks out of generator shadows" do
    root = File.join(Dir.tempdir, "azu-mcp-shadow-#{Random::Secure.hex(6)}")
    project = File.join(root, "project")
    shadow = File.join(root, "shadow")
    Dir.mkdir_p(File.join(project, "db"))
    %w(app.db app.db-wal app.sqlite3 app.sqlite3-shm).each { |name| File.write(File.join(project, "db", name), "database bytes") }
    File.write(File.join(project, "db/migration.cr"), "# source")
    File.symlink("/tmp", File.join(project, "db/escape"))
    AzuCLI::GeneratePlan.copy_project(project, shadow)
    Dir.children(File.join(shadow, "db")).should eq(["migration.cr"])
  ensure
    FileUtils.rm_rf(root) if root
  end

  it "refuses traversal arguments and nested symlinks before launching a preview" do
    root = File.join(Dir.tempdir, "azu-mcp-preview-#{Random::Secure.hex(6)}")
    Dir.mkdir_p(File.join(root, "src"))
    expect_raises(Exception, /inside the project/) do
      AzuCLI::MCPBridge.generate_plan(["job", "../Escaped"], root, "must-not-run")
    end
    File.symlink("/tmp", File.join(root, "src/jobs"))
    expect_raises(Exception, /refuses symlinks/) do
      AzuCLI::MCPBridge.generate_plan(["job", "Example"], root, "must-not-run")
    end
  ensure
    FileUtils.rm_rf(root) if root
  end

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
  it "coalesces auth without replacing the application and clears it on restart" do
    root = File.join(Dir.tempdir, "azu-mcp-export-#{Random::Secure.hex(6)}")
    path = File.join(root, "snapshot.json")
    writer = AzuCLI::DevServer::SnapshotExport.new(path)
    writer.write(JSON.parse(%({"v":1,"runtime":{"pid":123}})))
    File.info(path).permissions.value.should eq(0o600)
    writer.write(JSON.parse(%({"v":1,"stream":"auth","auth":{"recent":[{"event":"sign-in","outcome":"accepted"}]}})))
    JSON.parse(File.read(path))["runtime"]["pid"].as_i.should eq(123)
    JSON.parse(File.read(path))["auth"]["recent"][0]["outcome"].as_s.should eq("accepted")
    writer.write(JSON.parse(%({"v":1,"runtime":{"pid":124}})))
    JSON.parse(File.read(path))["auth"]?.should be_nil
  ensure
    FileUtils.rm_rf(root) if root
  end
end
