require "../../../spec_helper"

describe AzuCLI::Commands::OpenAPI::Export do
  describe "#initialize" do
    it "has correct command name" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.name.should eq("openapi:export")
    end

    it "has correct description" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.description.should contain("Export")
    end

    it "has default output_path" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.output_path.should eq("openapi.yaml")
    end

    it "has default format" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.format.should eq("yaml")
    end

    it "has default project_name as empty string" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.project_name.should eq("")
    end

    it "has default version" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.version.should eq("1.0.0")
    end
  end

  describe "option parsing" do
    it "parses --output option" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.parse_args(["--output", "api-spec.yaml"])

      command.output_path.should eq("api-spec.yaml")
    end

    it "parses --format option" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.parse_args(["--format", "json"])

      command.format.should eq("json")
    end

    it "parses --format option and normalizes to lowercase" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.parse_args(["--format", "JSON"])

      command.format.should eq("json")
    end

    it "parses --project option" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.parse_args(["--project", "my_api"])

      command.project_name.should eq("my_api")
    end

    it "parses --version option" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.parse_args(["--version", "2.0.0"])

      command.version.should eq("2.0.0")
    end

    it "auto-detects JSON format from .json extension" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.parse_args(["--output", "api.json"])

      command.format.should eq("json")
    end

    it "auto-detects YAML format from .yaml extension" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.parse_args(["--output", "api.yaml"])

      command.format.should eq("yaml")
    end

    it "auto-detects YAML format from .yml extension" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.parse_args(["--output", "api.yml"])

      command.format.should eq("yaml")
    end

    it "parses multiple options" do
      command = AzuCLI::Commands::OpenAPI::Export.new
      command.parse_args(["--output", "docs/api.json", "--project", "MyAPI", "--version", "3.0.0"])

      command.output_path.should eq("docs/api.json")
      command.project_name.should eq("MyAPI")
      command.version.should eq("3.0.0")
      command.format.should eq("json")
    end
  end

  describe "#show_help" do
    it "displays help information" do
      command = AzuCLI::Commands::OpenAPI::Export.new

      # Just ensure it doesn't crash
      command.show_help
    end
  end
end
