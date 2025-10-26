require "spec"
require "../support/integration_helpers"

include IntegrationHelpers

describe "Project Creation Integration" do
  it "creates a web project that compiles and runs" do
    with_temp_project("testweb", "web") do |project_path|
      # Verify project structure
      file_exists?(project_path, "src/testweb.cr").should be_true
      file_exists?(project_path, "src/server.cr").should be_true
      file_exists?(project_path, "shard.yml").should be_true

      # Verify directories exist
      file_exists?(project_path, "src/validators/.gitkeep").should be_true
      file_exists?(project_path, "src/components/.gitkeep").should be_true
      file_exists?(project_path, "src/middleware/.gitkeep").should be_true
      file_exists?(project_path, "src/services/.gitkeep").should be_true

      # Build project
      build_project(project_path).should be_true

      # Test server starts and responds
      with_running_server(project_path) do |port|
        response = http_get("/", port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(200)
      end
    end
  end

  it "creates an api project that compiles and runs" do
    with_temp_project("testapi", "api") do |project_path|
      # Verify API-specific files
      file_exists?(project_path, "src/api.cr").should be_true
      file_exists?(project_path, "config/openapi.yml").should be_true

      # Build project
      build_project(project_path).should be_true

      # Test API health endpoint
      with_running_server(project_path) do |port|
        response = http_get("/health", port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(200)
      end
    end
  end

  it "creates a cli project that compiles and runs" do
    with_temp_project("testcli", "cli") do |project_path|
      # Verify CLI-specific files
      file_exists?(project_path, "src/testcli.cr").should be_true

      # Build project
      build_project(project_path).should be_true

      # Test CLI commands
      result = Process.run("./bin/testcli --version", shell: true, chdir: project_path, output: Process::Redirect::Pipe)
      result.success?.should be_true
      result.output.to_s.should contain("v0.1.0")

      result = Process.run("./bin/testcli --help", shell: true, chdir: project_path, output: Process::Redirect::Pipe)
      result.success?.should be_true
      result.output.to_s.should contain("Usage:")
    end
  end
end
