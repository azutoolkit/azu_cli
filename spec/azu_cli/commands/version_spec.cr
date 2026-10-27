require "../../spec_helper"

describe AzuCLI::Commands::Version do
  it "reports the shard version, not a hard-coded one" do
    shard_version = File.read("shard.yml").lines.find!(&.starts_with?("version:")).split(":")[1].strip
    AzuCLI::VERSION.should eq(shard_version)
  end

  describe "#execute" do
    it "displays version information successfully" do
      command = AzuCLI::Commands::Version.new
      command.parse_args([] of String)

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Version information displayed")
    end

    it "executes without arguments" do
      command = AzuCLI::Commands::Version.new

      result = command.execute

      result.success?.should be_true
    end
  end

  describe "#show_help" do
    it "displays help information" do
      command = AzuCLI::Commands::Version.new

      # Just ensure it doesn't crash
      command.show_help
    end
  end
end

describe "AzuCLI::Commands::Version on a terminal" do
  it "draws a card with the CLI, Crystal, and the azu and cql of the project's shard.lock" do
    dir = File.join(Dir.tempdir, "azu_version_#{Random.rand(1_000_000)}")
    Dir.mkdir_p(dir)
    File.write(File.join(dir, "shard.lock"), "version: 2.0\nshards:\n  azu:\n    git: https://github.com/azutoolkit/azu.git\n    version: 0.5.136\n  cql:\n    git: x\n    version: 0.0.604\n")
    card = IO::Memory.new
    command = AzuCLI::Commands::Version.new
    command.ui = AzuCLI::UI::Rich.new(AzuCLI::UI::Terminal.fake(card, columns: 80))
    Dir.cd(dir) { command.execute.success?.should be_true }
    text = card.to_s
    text.should contain "▲ AZU CLI"
    text.should contain "Crystal   #{Crystal::VERSION}"
    text.should contain "azu       0.5.136 (shard.lock)"
    text.should contain "cql       0.0.604 (shard.lock)"
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  it "reads nothing from a missing or broken shard.lock" do
    AzuCLI::Commands::Version.locked_shards("/nonexistent/shard.lock").should be_empty
  end
end
