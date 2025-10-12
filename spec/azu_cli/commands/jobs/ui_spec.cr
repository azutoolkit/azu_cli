require "../../../spec_helper"

describe AzuCLI::Commands::Jobs::UI do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::Jobs::UI.new
      command.name.should eq("jobs:ui")
    end

    it "has correct description" do
      command = AzuCLI::Commands::Jobs::UI.new
      command.description.should contain("UI")
    end
  end

  describe "default properties" do
    it "has default port of 4000" do
      command = AzuCLI::Commands::Jobs::UI.new
      command.port.should eq(4000)
    end

    it "has default host of localhost" do
      command = AzuCLI::Commands::Jobs::UI.new
      command.host.should eq("localhost")
    end
  end

  describe "option parsing" do
    it "parses --port option" do
      command = AzuCLI::Commands::Jobs::UI.new
      command.parse_args(["--port", "5000"])

      command.port.should eq(5000)
    end

    it "parses -p short option" do
      command = AzuCLI::Commands::Jobs::UI.new
      command.parse_args(["-p", "8080"])

      command.port.should eq(8080)
    end

    it "parses --host option" do
      command = AzuCLI::Commands::Jobs::UI.new
      command.parse_args(["--host", "0.0.0.0"])

      command.host.should eq("0.0.0.0")
    end

    it "parses -h short option" do
      command = AzuCLI::Commands::Jobs::UI.new
      command.parse_args(["-h", "127.0.0.1"])

      command.host.should eq("127.0.0.1")
    end

    it "parses multiple options" do
      command = AzuCLI::Commands::Jobs::UI.new
      command.parse_args(["--port", "3333", "--host", "0.0.0.0"])

      command.port.should eq(3333)
      command.host.should eq("0.0.0.0")
    end
  end
end
