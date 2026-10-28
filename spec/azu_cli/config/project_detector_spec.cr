require "../../spec_helper"
require "file_utils"

describe AzuCLI::ProjectDetector do
  describe "#detect_type" do
    it "returns api for a project with src/api.cr and no src/server.cr" do
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

    it "reads the type from the main target of shard.yml, because generated web and api projects share their files" do
      {"src/server.cr" => "web", "src/api.cr" => "api"}.each do |main, type|
        dir = "spec/fixtures/generated_#{type}_project"
        Dir.mkdir_p("#{dir}/src")
        Dir.mkdir_p("#{dir}/public/templates")
        Dir.mkdir_p("#{dir}/config")
        File.write("#{dir}/src/server.cr", "# server")
        File.write("#{dir}/src/api.cr", "# api")
        File.write("#{dir}/config/api.yml", "version: v1
")
        File.write("#{dir}/config/openapi.yml", "openapi: 3.1.0
")
        File.write("#{dir}/shard.yml", "name: app
version: 0.1.0
targets:
  app:
    main: #{main}
  tasks:
    main: src/tasks.cr
")

        AzuCLI::ProjectDetector.new(dir).detect_type.should eq(type)

        FileUtils.rm_rf(dir)
      end
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

    it "does not read the type from a config/azu.yml" do
      Dir.mkdir_p("spec/fixtures/config_project/config")
      File.write("spec/fixtures/config_project/config/azu.yml", "project:
  type: api
")

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/config_project")
      detector.detect_type.should eq("web")

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
end
