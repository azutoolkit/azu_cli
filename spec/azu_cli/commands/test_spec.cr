require "../../spec_helper"

describe AzuCLI::Commands::Test do
  describe "#execute" do
    it "has correct command name" do
      command = AzuCLI::Commands::Test.new
      command.name.should eq("test")
    end

    it "has correct description" do
      command = AzuCLI::Commands::Test.new
      command.description.should contain("test")
    end
  end

  describe "#show_help" do
    it "displays help information" do
      command = AzuCLI::Commands::Test.new

      # Just ensure it doesn't crash
      command.show_help
    end
  end
end
