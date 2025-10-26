require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Endpoint Generator E2E" do
  it "generates endpoint for web project, compiles and responds" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate endpoint
      result = run_generator("generate endpoint Posts index:get show:get", project_path)
      result.success?.should be_true

      # Verify files created
      file_exists?(project_path, "src/endpoints/posts/index_endpoint.cr").should be_true
      file_exists?(project_path, "src/endpoints/posts/show_endpoint.cr").should be_true
      file_exists?(project_path, "src/requests/posts/index_request.cr").should be_true
      file_exists?(project_path, "src/requests/posts/show_request.cr").should be_true
      file_exists?(project_path, "src/pages/posts/index_page.cr").should be_true
      file_exists?(project_path, "src/pages/posts/show_page.cr").should be_true

      # Build project
      build_project(project_path).should be_true

      # Test endpoints respond
      with_running_server(project_path) do |port|
        response = http_get("/posts", port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(200)

        response = http_get("/posts/1", port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(200)
      end
    end
  end

  it "generates endpoint for api project, compiles and responds" do
    with_temp_project("testapp", "api") do |project_path|
      # Generate endpoint
      result = run_generator("generate endpoint Users index:get show:get", project_path)
      result.success?.should be_true

      # Verify API-specific files
      file_exists?(project_path, "src/endpoints/users/index_endpoint.cr").should be_true
      file_exists?(project_path, "src/endpoints/users/show_endpoint.cr").should be_true
      file_exists?(project_path, "src/requests/users/index_request.cr").should be_true
      file_exists?(project_path, "src/requests/users/show_request.cr").should be_true
      file_exists?(project_path, "src/responses/users/index_response.cr").should be_true
      file_exists?(project_path, "src/responses/users/show_response.cr").should be_true

      # Build project
      build_project(project_path).should be_true

      # Test API endpoints respond with JSON
      with_running_server(project_path) do |port|
        response = http_get("/users", port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(200)
        content_type = response.not_nil!.headers["Content-Type"]?
        content_type.should_not be_nil
        content_type.not_nil!.should contain("application/json")

        response = http_get("/users/1", port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(200)
      end
    end
  end
end
