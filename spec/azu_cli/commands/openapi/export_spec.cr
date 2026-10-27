require "../../../spec_helper"

EXPORT_DOCUMENT = %({"openapi":"3.1.0","info":{"title":"t","version":"1"},"paths":{"/posts/{id}":{"get":{"operationId":"Blog.ShowEndpoint"}}}})

private def with_export_project(&)
  dir = File.tempname("azu-export")
  Dir.mkdir_p(File.join(dir, "src"))
  File.write(File.join(dir, "shard.yml"), "name: blog\nversion: 0.1.0\n")
  File.write(File.join(dir, "src/blog.cr"), "")
  yield dir
ensure
  FileUtils.rm_rf(dir) if dir
end

private def run_export(dir : String, args : Array(String), loader = nil)
  asked = nil.as({String, String, String}?)
  original = AzuCLI::Commands::OpenAPI::Export.loader
  AzuCLI::Commands::OpenAPI::Export.loader = loader || ->(file : String, title : String, version : String) : String do
    asked = {file, title, version}
    EXPORT_DOCUMENT
  end
  command = AzuCLI::Commands::OpenAPI::Export.new
  command.stdout = IO::Memory.new
  command.parse_args(args)
  result = Dir.cd(dir) { command.execute }
  {result: result, asked: asked}
ensure
  AzuCLI::Commands::OpenAPI::Export.loader = original.not_nil!
end

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

  describe "#execute" do
    it "writes the document the app reports, as JSON or YAML" do
      with_export_project do |dir|
        json = run_export(dir, ["--output", "api.json", "--project", "Blog API", "--version", "2.0.0"])
        json[:result].success?.should be_true
        json[:asked].should eq({"./src/blog.cr", "Blog API", "2.0.0"})
        JSON.parse(File.read(File.join(dir, "api.json")))["paths"]["/posts/{id}"]["get"]["operationId"].should eq "Blog.ShowEndpoint"

        yaml = run_export(dir, [] of String)
        yaml[:asked].should eq({"./src/blog.cr", "blog", "1.0.0"})
        YAML.parse(File.read(File.join(dir, "openapi.yaml")))["openapi"].should eq "3.1.0"
      end
    end

    it "refuses an unknown format or option with exit code 2" do
      with_export_project do |dir|
        run_export(dir, ["--format", "xml"])[:result].exit_code.should eq 2
        run_export(dir, ["--colour"])[:result].exit_code.should eq 2
        File.exists?(File.join(dir, "openapi.yaml")).should be_false
      end
    end

    it "fails without an app file, and when the app cannot be loaded" do
      with_export_project do |dir|
        File.delete(File.join(dir, "src/blog.cr"))
        run_export(dir, [] of String)[:result].success?.should be_false
      end
      with_export_project do |dir|
        failing = ->(_file : String, _title : String, _version : String) : String { raise AzuCLI::OpenAPI::Exporter::Error.new("could not be loaded") }
        result = run_export(dir, [] of String, failing)[:result]
        result.success?.should be_false
        result.error.should contain "could not be loaded"
      end
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
