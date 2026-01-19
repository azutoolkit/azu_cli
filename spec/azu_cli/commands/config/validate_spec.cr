require "../../../spec_helper"

describe AzuCLI::Commands::Config::Validate do
  describe "#execute" do
    it "validates configuration successfully when no issues" do
      command = AzuCLI::Commands::Config::Validate.new
      command.parse_args([] of String)

      result = command.execute

      # Result should indicate validation was performed
      result.message.should_not be_nil
    end

    it "runs in strict mode" do
      command = AzuCLI::Commands::Config::Validate.new
      command.parse_args(["--strict"])

      result = command.execute

      # Strict mode converts warnings to errors
      result.message.should_not be_nil
    end

    it "validates specific environment" do
      command = AzuCLI::Commands::Config::Validate.new
      command.parse_args(["--env", "production"])

      result = command.execute

      result.message.should_not be_nil
    end
  end

  describe "#show_help" do
    it "displays help information" do
      command = AzuCLI::Commands::Config::Validate.new
      command.show_help
    end
  end
end
