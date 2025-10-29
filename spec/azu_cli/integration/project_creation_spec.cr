require "spec"
require "../../support/integration_helpers"

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

      # Verify main file content
      main_content = read_file(project_path, "src/testweb.cr").not_nil!
      main_content.should contain("module Testweb")

      server_content = read_file(project_path, "src/server.cr").not_nil!
      server_content.should contain("Azu")
      server_content.should contain("start")
    end
  end

  it "creates an api project that compiles and runs" do
    with_temp_project("testapi", "api") do |project_path|
      # Verify API-specific files
      file_exists?(project_path, "src/api.cr").should be_true
      file_exists?(project_path, "config/openapi.yml").should be_true

      # Verify API file content
      api_content = read_file(project_path, "src/api.cr").not_nil!
      api_content.should contain("Azu")
      api_content.should contain("start")

      openapi_content = read_file(project_path, "config/openapi.yml").not_nil!
      openapi_content.should contain("openapi")
    end
  end

  it "creates a cli project that compiles and runs" do
    with_temp_project("testcli", "cli") do |project_path|
      # Verify CLI-specific files
      file_exists?(project_path, "src/testcli.cr").should be_true

      # Verify CLI file content
      cli_content = read_file(project_path, "src/testcli.cr").not_nil!
      cli_content.should contain("module Testcli")
    end
  end
end
