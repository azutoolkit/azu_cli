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
