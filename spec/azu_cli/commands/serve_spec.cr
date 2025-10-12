require "../../spec_helper"

describe AzuCLI::Commands::Serve do
  describe "property defaults" do
    it "has default port of 3000" do
      command = AzuCLI::Commands::Serve.new
      command.port.should eq(3000)
    end

    it "has default host of localhost" do
      command = AzuCLI::Commands::Serve.new
      command.host.should eq("localhost")
    end

    it "has default environment of development" do
      command = AzuCLI::Commands::Serve.new
      command.environment.should eq("development")
    end

    it "has watch enabled by default" do
      command = AzuCLI::Commands::Serve.new
      command.watch.should be_true
    end

    it "has verbose disabled by default" do
      command = AzuCLI::Commands::Serve.new
      command.verbose.should be_false
    end
  end

  describe "properties" do
    it "can set port property" do
      command = AzuCLI::Commands::Serve.new
      command.port = 4000

      command.port.should eq(4000)
    end

    it "can set host property" do
      command = AzuCLI::Commands::Serve.new
      command.host = "0.0.0.0"

      command.host.should eq("0.0.0.0")
    end

    it "can set environment property" do
      command = AzuCLI::Commands::Serve.new
      command.environment = "production"

      command.environment.should eq("production")
    end

    it "can set watch property" do
      command = AzuCLI::Commands::Serve.new
      command.watch = false

      command.watch.should be_false
    end

    it "can set verbose property" do
      command = AzuCLI::Commands::Serve.new
      command.verbose = true

      command.verbose.should be_true
    end
  end

  describe "#show_help" do
    it "displays help information" do
      command = AzuCLI::Commands::Serve.new

      # Just ensure it doesn't crash
      command.show_help
    end
  end
end
