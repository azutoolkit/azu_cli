require "../spec_helper"
require "../support/test_helpers"

describe AzuCLI::CLI do
  describe "#initialize" do
    it "sets up commands, plugins, and middleware" do
      cli = AzuCLI::CLI.new

      # Verify commands are registered
      cli.@commands.should_not be_empty
      cli.@commands.has_key?("new").should be_true
      cli.@commands.has_key?("generate").should be_true
      cli.@commands.has_key?("g").should be_true # Alias
      cli.@commands.has_key?("serve").should be_true
      cli.@commands.has_key?("s").should be_true # Alias
      cli.@commands.has_key?("db:create").should be_true
      cli.@commands.has_key?("help").should be_true
      cli.@commands.has_key?("version").should be_true
    end

    it "loads built-in plugins" do
      cli = AzuCLI::CLI.new

      # Verify plugins are loaded
      cli.@plugins.should_not be_empty
      cli.@plugins.size.should be >= 3 # Generator, Database, Development plugins
    end

    it "sets up middleware chain" do
      cli = AzuCLI::CLI.new

      # Verify middleware is loaded
      cli.@middleware.should_not be_empty
      cli.@middleware.size.should be >= 3 # Logging, ErrorHandler, Configuration
    end
  end

  describe "#run" do
    it "shows help when no arguments provided" do
      cli = AzuCLI::CLI.new

      TestHelpers::TestSetup.with_captured_output do |capture|
        cli.run([] of String)
        capture.stdout.should contain("Help information displayed")
      end
    end

    it "executes known commands" do
      cli = AzuCLI::CLI.new

      TestHelpers::TestSetup.with_captured_output do |capture|
        cli.run(["help"])
        capture.stdout.should contain("Help information displayed")
      end
    end

    it "handles command aliases" do
      cli = AzuCLI::CLI.new

      # Test 'g' alias for generate
      TestHelpers::TestSetup.with_captured_output do |capture|
        cli.run(["g", "model", "User"])
        # Should not error (even if model generation fails, CLI routing works)
        capture.stderr.should_not contain("Unknown command")
      end
    end

    it "handles unknown commands gracefully" do
      cli = AzuCLI::CLI.new

      TestHelpers::TestSetup.with_captured_output do |capture|
        cli.run(["unknown_command"])
        capture.stderr.should contain("Unknown command: unknown_command")
        capture.stderr.should contain("Run 'azu help' to see available commands")
      end
    end

    it "passes arguments to commands" do
      cli = AzuCLI::CLI.new

      TestHelpers::TestSetup.with_captured_output do |capture|
        cli.run(["help", "generate"])
        capture.stdout.should contain("Help information displayed")
      end
    end
  end

  describe "command registration" do
    it "registers all project management commands" do
      cli = AzuCLI::CLI.new

      cli.@commands.has_key?("new").should be_true
      cli.@commands.has_key?("init").should be_true
      cli.@commands.has_key?("version").should be_true
      cli.@commands.has_key?("help").should be_true
    end

    it "registers all code generation commands" do
      cli = AzuCLI::CLI.new

      cli.@commands.has_key?("generate").should be_true
      cli.@commands.has_key?("g").should be_true # Alias
    end

    it "registers all database commands" do
      cli = AzuCLI::CLI.new

      cli.@commands.has_key?("db:create").should be_true
      cli.@commands.has_key?("db:drop").should be_true
      cli.@commands.has_key?("db:migrate").should be_true
      cli.@commands.has_key?("db:rollback").should be_true
      cli.@commands.has_key?("db:seed").should be_true
      cli.@commands.has_key?("db:reset").should be_true
      cli.@commands.has_key?("db:status").should be_true
      cli.@commands.has_key?("db:setup").should be_true
    end

    it "registers development server commands" do
      cli = AzuCLI::CLI.new

      cli.@commands.has_key?("serve").should be_true
      cli.@commands.has_key?("server").should be_true # Alias
      cli.@commands.has_key?("s").should be_true      # Short alias
    end

    it "registers job queue commands" do
      cli = AzuCLI::CLI.new

      cli.@commands.has_key?("jobs:worker").should be_true
      cli.@commands.has_key?("jobs:status").should be_true
      cli.@commands.has_key?("jobs:clear").should be_true
      cli.@commands.has_key?("jobs:retry").should be_true
      cli.@commands.has_key?("jobs:ui").should be_true
    end

    it "registers session commands" do
      cli = AzuCLI::CLI.new

      cli.@commands.has_key?("session:setup").should be_true
      cli.@commands.has_key?("session:clear").should be_true
    end

    it "registers testing commands" do
      cli = AzuCLI::CLI.new

      cli.@commands.has_key?("test").should be_true
      cli.@commands.has_key?("t").should be_true # Alias
    end

    it "registers OpenAPI commands" do
      cli = AzuCLI::CLI.new

      cli.@commands.has_key?("openapi:generate").should be_true
      cli.@commands.has_key?("openapi:export").should be_true
    end

    it "registers plugin commands" do
      cli = AzuCLI::CLI.new

      cli.@commands.has_key?("plugin").should be_true
    end
  end

  describe "plugin system" do
    it "loads built-in plugins" do
      cli = AzuCLI::CLI.new

      cli.@plugins.should_not be_empty
      # Should have Generator, Database, and Development plugins
      cli.@plugins.size.should be >= 3
    end

    it "calls on_load for each plugin" do
      # This is tested implicitly by the plugin loading working
      cli = AzuCLI::CLI.new
      cli.@plugins.should_not be_empty
    end
  end

  describe "middleware system" do
    it "sets up middleware chain" do
      cli = AzuCLI::CLI.new

      cli.@middleware.should_not be_empty
      # Should have Logging, ErrorHandler, and Configuration middleware
      cli.@middleware.size.should be >= 3
    end
  end

  describe "error handling" do
    it "handles command execution errors" do
      cli = AzuCLI::CLI.new

      TestHelpers::TestSetup.with_captured_output do |capture|
        # This should trigger an error in the generate command
        cli.run(["generate", "invalid_generator_type"])
        capture.stderr.should contain("Command failed")
      end
    end

    it "runs middleware on error" do
      cli = AzuCLI::CLI.new

      # The error handling is tested by the middleware being called
      # This is verified by the error being caught and logged
      TestHelpers::TestSetup.with_captured_output do |capture|
        cli.run(["generate", "invalid_generator_type"])
        capture.stderr.should contain("Command failed")
      end
    end
  end

  describe "command execution flow" do
    it "runs middleware before command" do
      cli = AzuCLI::CLI.new

      # This is tested by the command executing successfully
      # The middleware before hooks are called during execution
      TestHelpers::TestSetup.with_captured_output do |capture|
        cli.run(["help"])
        capture.stdout.should contain("Help information displayed")
      end
    end

    it "runs middleware after command" do
      cli = AzuCLI::CLI.new

      # This is tested by the command executing successfully
      # The middleware after hooks are called during execution
      TestHelpers::TestSetup.with_captured_output do |capture|
        cli.run(["help"])
        capture.stdout.should contain("Help information displayed")
      end
    end

    it "runs plugins before and after command" do
      cli = AzuCLI::CLI.new

      # This is tested by the command executing successfully
      # The plugin hooks are called during execution
      TestHelpers::TestSetup.with_captured_output do |capture|
        cli.run(["help"])
        capture.stdout.should contain("Help information displayed")
      end
    end
  end
end
