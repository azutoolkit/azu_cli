require "../../spec_helper"

describe AzuCLI::Commands::Completion do
  describe "#execute" do
    it "generates bash completion script" do
      command = AzuCLI::Commands::Completion.new
      command.parse_args(["bash"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Completion script generated for bash")
    end

    it "generates zsh completion script" do
      command = AzuCLI::Commands::Completion.new
      command.parse_args(["zsh"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Completion script generated for zsh")
    end

    it "generates fish completion script" do
      command = AzuCLI::Commands::Completion.new
      command.parse_args(["fish"])

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Completion script generated for fish")
    end

    it "accepts --shell flag" do
      command = AzuCLI::Commands::Completion.new
      command.parse_args(["--shell", "bash"])

      result = command.execute

      result.success?.should be_true
    end

    it "fails with unsupported shell" do
      command = AzuCLI::Commands::Completion.new
      command.parse_args(["--shell", "powershell"])

      result = command.execute

      result.success?.should be_false
      result.error.should contain("Unsupported shell")
    end
  end

  describe "#show_help" do
    it "displays help information" do
      command = AzuCLI::Commands::Completion.new
      command.show_help
    end
  end
end
