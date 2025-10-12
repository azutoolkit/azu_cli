require "../../spec_helper"

describe AzuCLI::Commands::Plugin do
  describe "#execute" do
    it "has correct command name" do
      command = AzuCLI::Commands::Plugin.new
      command.name.should eq("plugin")
    end

    it "has correct description" do
      command = AzuCLI::Commands::Plugin.new
      command.description.should contain("plugin")
    end
  end

  describe "#show_help" do
    it "displays help information" do
      command = AzuCLI::Commands::Plugin.new

      # Just ensure it doesn't crash
      command.show_help
    end
  end
end
