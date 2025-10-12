require "../../../spec_helper"

describe AzuCLI::Commands::OpenAPI::Generate do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::OpenAPI::Generate.new
      command.name.should eq("openapi:generate")
    end

    it "has correct description" do
      command = AzuCLI::Commands::OpenAPI::Generate.new
      command.description.should contain("OpenAPI specification")
    end

    it "has default spec_path as empty string" do
      command = AzuCLI::Commands::OpenAPI::Generate.new
      command.spec_path.should eq("")
    end

    it "has force set to false by default" do
      command = AzuCLI::Commands::OpenAPI::Generate.new
      command.force.should be_false
    end

    it "has models_only set to false by default" do
      command = AzuCLI::Commands::OpenAPI::Generate.new
      command.models_only.should be_false
    end

    it "has endpoints_only set to false by default" do
      command = AzuCLI::Commands::OpenAPI::Generate.new
      command.endpoints_only.should be_false
    end
  end

  describe "option parsing" do
    it "parses --spec option" do
      command = AzuCLI::Commands::OpenAPI::Generate.new
      command.parse_args(["--spec", "openapi.yaml"])

      command.spec_path.should eq("openapi.yaml")
    end

    it "parses --force option" do
      command = AzuCLI::Commands::OpenAPI::Generate.new
      command.parse_args(["--force"])

      command.force.should be_true
    end

    it "parses --models-only option" do
      command = AzuCLI::Commands::OpenAPI::Generate.new
      command.parse_args(["--models-only"])

      command.models_only.should be_true
    end

    it "parses --endpoints-only option" do
      command = AzuCLI::Commands::OpenAPI::Generate.new
      command.parse_args(["--endpoints-only"])

      command.endpoints_only.should be_true
    end

    it "parses multiple options" do
      command = AzuCLI::Commands::OpenAPI::Generate.new
      command.parse_args(["--spec", "api.yaml", "--force", "--models-only"])

      command.spec_path.should eq("api.yaml")
      command.force.should be_true
      command.models_only.should be_true
    end
  end

  describe "#show_help" do
    it "displays help information" do
      command = AzuCLI::Commands::OpenAPI::Generate.new

      # Just ensure it doesn't crash
      command.show_help
    end
  end
end
