require "../../spec_helper"

describe AzuCLI::ProjectDetector do
  describe "#detect_type" do
    it "returns api for projects with api.cr file" do
      Dir.mkdir_p("spec/fixtures/api_project/src")
      File.write("spec/fixtures/api_project/src/api.cr", "# API file")

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/api_project")
      detector.detect_type.should eq("api")

      File.delete("spec/fixtures/api_project/src/api.cr")
      Dir.delete("spec/fixtures/api_project/src")
      Dir.delete("spec/fixtures/api_project")
    end

    it "returns web for projects with templates directory" do
      Dir.mkdir_p("spec/fixtures/web_project/public/templates")

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/web_project")
      detector.detect_type.should eq("web")

      Dir.delete("spec/fixtures/web_project/public/templates")
      Dir.delete("spec/fixtures/web_project/public")
      Dir.delete("spec/fixtures/web_project")
    end

    it "returns cli for projects with cli.cr file and no server" do
      Dir.mkdir_p("spec/fixtures/cli_project/src")
      File.write("spec/fixtures/cli_project/src/cli.cr", "# CLI file")

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/cli_project")
      detector.detect_type.should eq("cli")

      File.delete("spec/fixtures/cli_project/src/cli.cr")
      Dir.delete("spec/fixtures/cli_project/src")
      Dir.delete("spec/fixtures/cli_project")
    end

    it "returns web by default" do
      Dir.mkdir_p("spec/fixtures/default_project")

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/default_project")
      detector.detect_type.should eq("web")

      Dir.delete("spec/fixtures/default_project")
    end

    it "reads type from config/azu.yml" do
      Dir.mkdir_p("spec/fixtures/config_project/config")
      config_content = <<-YAML
      project:
        type: api
      YAML
      File.write("spec/fixtures/config_project/config/azu.yml", config_content)

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/config_project")
      detector.detect_type.should eq("api")

      File.delete("spec/fixtures/config_project/config/azu.yml")
      Dir.delete("spec/fixtures/config_project/config")
      Dir.delete("spec/fixtures/config_project")
    end
  end

  describe "#api_project?" do
    it "returns true for api projects" do
      Dir.mkdir_p("spec/fixtures/api_project/src")
      File.write("spec/fixtures/api_project/src/api.cr", "# API file")

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/api_project")
      detector.api_project?.should be_true

      File.delete("spec/fixtures/api_project/src/api.cr")
      Dir.delete("spec/fixtures/api_project/src")
      Dir.delete("spec/fixtures/api_project")
    end

    it "returns false for web projects" do
      Dir.mkdir_p("spec/fixtures/web_project/public/templates")

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/web_project")
      detector.api_project?.should be_false

      Dir.delete("spec/fixtures/web_project/public/templates")
      Dir.delete("spec/fixtures/web_project/public")
      Dir.delete("spec/fixtures/web_project")
    end
  end

  describe "#web_project?" do
    it "returns true for web projects" do
      Dir.mkdir_p("spec/fixtures/web_project/public/templates")

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/web_project")
      detector.web_project?.should be_true

      Dir.delete("spec/fixtures/web_project/public/templates")
      Dir.delete("spec/fixtures/web_project/public")
      Dir.delete("spec/fixtures/web_project")
    end

    it "returns false for api projects" do
      Dir.mkdir_p("spec/fixtures/api_project/src")
      File.write("spec/fixtures/api_project/src/api.cr", "# API file")

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/api_project")
      detector.web_project?.should be_false

      File.delete("spec/fixtures/api_project/src/api.cr")
      Dir.delete("spec/fixtures/api_project/src")
      Dir.delete("spec/fixtures/api_project")
    end
  end

  describe "#cli_project?" do
    it "returns true for cli projects" do
      Dir.mkdir_p("spec/fixtures/cli_project/src")
      File.write("spec/fixtures/cli_project/src/cli.cr", "# CLI file")

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/cli_project")
      detector.cli_project?.should be_true

      File.delete("spec/fixtures/cli_project/src/cli.cr")
      Dir.delete("spec/fixtures/cli_project/src")
      Dir.delete("spec/fixtures/cli_project")
    end

    it "returns false for api projects" do
      Dir.mkdir_p("spec/fixtures/api_project/src")
      File.write("spec/fixtures/api_project/src/api.cr", "# API file")

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/api_project")
      detector.cli_project?.should be_false

      File.delete("spec/fixtures/api_project/src/api.cr")
      Dir.delete("spec/fixtures/api_project/src")
      Dir.delete("spec/fixtures/api_project")
    end
  end

  describe "#api_version" do
    it "returns v1 by default" do
      Dir.mkdir_p("spec/fixtures/test_project")

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/test_project")
      detector.api_version.should eq("v1")

      Dir.delete("spec/fixtures/test_project")
    end

    it "reads version from config" do
      Dir.mkdir_p("spec/fixtures/config_project/config")
      config_content = <<-YAML
      project:
        api_version: v2
      YAML
      File.write("spec/fixtures/config_project/config/azu.yml", config_content)

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/config_project")
      detector.api_version.should eq("v2")

      File.delete("spec/fixtures/config_project/config/azu.yml")
      Dir.delete("spec/fixtures/config_project/config")
      Dir.delete("spec/fixtures/config_project")
    end
  end

  describe "#openapi_enabled?" do
    it "returns false by default" do
      Dir.mkdir_p("spec/fixtures/test_project")

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/test_project")
      detector.openapi_enabled?.should be_false

      Dir.delete("spec/fixtures/test_project")
    end

    it "reads from config" do
      Dir.mkdir_p("spec/fixtures/config_project/config")
      config_content = <<-YAML
      project:
        openapi_enabled: true
      YAML
      File.write("spec/fixtures/config_project/config/azu.yml", config_content)

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/config_project")
      detector.openapi_enabled?.should be_true

      File.delete("spec/fixtures/config_project/config/azu.yml")
      Dir.delete("spec/fixtures/config_project/config")
      Dir.delete("spec/fixtures/config_project")
    end
  end
end
