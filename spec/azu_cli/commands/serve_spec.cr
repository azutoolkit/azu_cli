require "../../spec_helper"

describe AzuCLI::Commands::Serve do
  describe "property defaults" do
    it "has default port of 4000" do
      command = AzuCLI::Commands::Serve.new
      command.port.should eq(4000)
    end

    it "has no host unless HOST is set, so the app's per-environment default applies" do
      saved = ENV["HOST"]?
      begin
        ENV.delete("HOST")
        AzuCLI::Commands::Serve.new.host.should be_nil
        ENV["HOST"] = "0.0.0.0"
        AzuCLI::Commands::Serve.new.host.should eq("0.0.0.0")
      ensure
        saved ? (ENV["HOST"] = saved) : ENV.delete("HOST")
      end
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

  describe "#child_env" do
    it "passes HOST only when the user set it" do
      command = AzuCLI::Commands::Serve.new
      command.host = nil
      command.child_env.has_key?("HOST").should be_false

      command.host = "0.0.0.0"
      command.child_env["HOST"].should eq("0.0.0.0")
    end

    it "always passes PORT and the environment" do
      command = AzuCLI::Commands::Serve.new
      command.port = 3000
      command.environment = "test"
      command.child_env.should eq({"PORT" => "3000", "CRYSTAL_ENV" => "test", "AZU_ENV" => "test"})
    end
  end

  describe "#server_lines" do
    it "names the loopback URL when no host is set in development" do
      command = AzuCLI::Commands::Serve.new
      command.host = nil
      command.port = 4000
      command.environment = "development"
      command.server_lines.should eq(["Server: http://127.0.0.1:4000"])
    end

    it "says the app listens on all interfaces in production and staging, with a clickable localhost URL" do
      %w[production staging].each do |environment|
        command = AzuCLI::Commands::Serve.new
        command.host = nil
        command.port = 8080
        command.environment = environment
        lines = command.server_lines
        lines.first.should eq("Server: http://localhost:8080")
        lines.size.should eq(2)
        lines.last.should contain("all interfaces")
        lines.join.should_not contain("loopback")
      end
    end

    it "prints an explicit host, and brackets an IPv6 one" do
      command = AzuCLI::Commands::Serve.new
      command.port = 3000
      command.host = "192.168.1.5"
      command.server_lines.should eq(["Server: http://192.168.1.5:3000"])
      command.host = "::1"
      command.server_lines.should eq(["Server: http://[::1]:3000"])
      command.host = "0.0.0.0"
      command.server_lines.first.should eq("Server: http://localhost:3000")
    end

    it "does not change what the child gets" do
      command = AzuCLI::Commands::Serve.new
      command.host = nil
      command.environment = "production"
      command.server_lines
      command.child_env.has_key?("HOST").should be_false
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
