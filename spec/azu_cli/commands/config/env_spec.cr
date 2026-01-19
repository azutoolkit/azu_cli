require "../../../spec_helper"

describe AzuCLI::Commands::Config::Env do
  describe "#execute" do
    it "lists environment variables by default" do
      command = AzuCLI::Commands::Config::Env.new
      command.parse_args([] of String)

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Environment variables displayed")
    end

    it "shows current values with --show flag" do
      command = AzuCLI::Commands::Config::Env.new
      command.parse_args(["--show"])

      result = command.execute

      result.success?.should be_true
    end

    it "lists variables with --list flag" do
      command = AzuCLI::Commands::Config::Env.new
      command.parse_args(["--list"])

      result = command.execute

      result.success?.should be_true
    end

    it "fails to set variable with invalid format" do
      command = AzuCLI::Commands::Config::Env.new
      command.parse_args(["--set", "INVALID_NO_EQUALS"])

      result = command.execute

      result.success?.should be_false
      result.error.should contain("Invalid format")
    end

    it "sets a variable correctly" do
      # Create a temporary directory for this test
      temp_dir = File.tempname("azu_cli_test")
      Dir.mkdir_p(temp_dir)

      Dir.cd(temp_dir) do
        command = AzuCLI::Commands::Config::Env.new
        command.parse_args(["--set", "AZU_TEST_VAR=test_value"])

        result = command.execute

        result.success?.should be_true
        File.exists?(".env").should be_true
        File.read(".env").should contain("AZU_TEST_VAR=test_value")
      end

      # Cleanup
      FileUtils.rm_rf(temp_dir)
    end
  end

  describe "#show_help" do
    it "displays help information" do
      command = AzuCLI::Commands::Config::Env.new
      command.show_help
    end
  end
end
