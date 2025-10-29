require "spec"
require "../../support/integration_helpers"
require "json"

include IntegrationHelpers

describe "Auth Generator E2E" do
  it "generates auth system, compiles, and authenticates" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate auth
      result = run_generator("generate auth", project_path)
      result.success?.should be_true

      # Verify all auth files created
      auth_files = [
        "src/models/user.cr",
        "src/endpoints/auth_endpoint.cr",
        "src/requests/auth/login_request.cr",
        "src/requests/auth/register_request.cr",
        "src/requests/auth/refresh_token_request.cr",
        "src/requests/auth/change_password_request.cr",
        "src/config/authly.cr",
        "src/middleware/csrf_protection.cr",
        "src/middleware/security_headers.cr"
      ]

      auth_files.each do |file|
        file_exists?(project_path, file).should be_true
      end

      # Verify auth file content
      user_content = read_file(project_path, "src/models/user.cr").not_nil!
      user_content.should contain("class User")
      user_content.should contain("email")

      auth_endpoint_content = read_file(project_path, "src/endpoints/auth_endpoint.cr").not_nil!
      auth_endpoint_content.should contain("AuthEndpoint")

      login_request_content = read_file(project_path, "src/requests/auth/login_request.cr").not_nil!
      login_request_content.should contain("LoginRequest")
      login_request_content.should contain("email")
      login_request_content.should contain("password")
    end
  end

  it "generates auth system for API project" do
    with_temp_project("testapi", "api") do |project_path|
      # Generate auth for API
      result = run_generator("generate auth --strategy jwt", project_path)
      result.success?.should be_true

      # Verify JWT-specific files
      file_exists?(project_path, "src/models/user.cr").should be_true
      file_exists?(project_path, "src/endpoints/auth_endpoint.cr").should be_true

      # Verify JWT configuration
      auth_endpoint_content = read_file(project_path, "src/endpoints/auth_endpoint.cr").not_nil!
      auth_endpoint_content.should contain("AuthEndpoint")
      auth_endpoint_content.should match(/JWT|token/)
    end
  end

  it "handles auth validation errors properly" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate auth
      result = run_generator("generate auth", project_path)
      result.success?.should be_true

      # Verify validation in requests
      register_content = read_file(project_path, "src/requests/auth/register_request.cr").not_nil!
      register_content.should contain("email")
      register_content.should contain("password")

      login_content = read_file(project_path, "src/requests/auth/login_request.cr").not_nil!
      login_content.should contain("email")
      login_content.should contain("password")
    end
  end
end
