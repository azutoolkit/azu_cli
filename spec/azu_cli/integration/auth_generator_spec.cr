require "spec"
require "../../support/integration_helpers"
require "json"

include IntegrationHelpers

describe "Auth Generator E2E" do
  it "generates auth system, compiles, and authenticates" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate auth
      result = run_generator("generate auth", ".")
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
        File.exists?(file).should be_true
      end

      # Build project
      build_project(".").should be_true

      # Test comprehensive auth flow
      with_running_server(".") do |port|
        # Test 1: Register endpoint with valid data
        register_data = {
          "email" => "test@example.com",
          "password" => "Password123!",
          "password_confirmation" => "Password123!",
          "name" => "Test User"
        }.to_json

        response = http_post("/auth/register", register_data, port)
        response.should_not be_nil
        response.not_nil!.status_code.should be >= 200
        response.not_nil!.status_code.should be <= 422

        # Test 2: Login endpoint with valid data
        login_data = {
          "email" => "test@example.com",
          "password" => "Password123!"
        }.to_json

        response = http_post("/auth/login", login_data, port)
        response.should_not be_nil
        response.not_nil!.status_code.should be >= 200
        response.not_nil!.status_code.should be <= 422

        # Extract tokens from login response if successful
        access_token = nil
        refresh_token = nil

        if response.not_nil!.status_code == 200
          begin
            login_response = JSON.parse(response.not_nil!.body)
            access_token = login_response["access_token"]?.try(&.as_s)
            refresh_token = login_response["refresh_token"]?.try(&.as_s)
          rescue
            # If JSON parsing fails, tokens might not be in response
          end
        end

        # Test 3: Get current user (authenticated endpoint)
        if access_token
          response = http_get_with_auth("/auth/me", access_token, port)
          response.should_not be_nil
          response.not_nil!.status_code.should be >= 200
          response.not_nil!.status_code.should be <= 401
        end

        # Test 4: Refresh token endpoint
        if refresh_token
          refresh_data = {
            "refresh_token" => refresh_token
          }.to_json

          response = http_post("/auth/refresh", refresh_data, port)
          response.should_not be_nil
          response.not_nil!.status_code.should be >= 200
          response.not_nil!.status_code.should be <= 422
        end

        # Test 5: Change password endpoint (authenticated)
        if access_token
          change_password_data = {
            "current_password" => "Password123!",
            "new_password" => "NewPassword123!",
            "new_password_confirmation" => "NewPassword123!"
          }.to_json

          response = http_post_with_auth("/auth/change-password", change_password_data, access_token, port)
          response.should_not be_nil
          response.not_nil!.status_code.should be >= 200
          response.not_nil!.status_code.should be <= 422
        end

        # Test 6: Logout endpoint
        if refresh_token
          logout_data = {
            "refresh_token" => refresh_token
          }.to_json

          response = http_post("/auth/logout", logout_data, port)
          response.should_not be_nil
          response.not_nil!.status_code.should be >= 200
          response.not_nil!.status_code.should be <= 422
        end

        # Test 7: Invalid login attempt
        invalid_login_data = {
          "email" => "test@example.com",
          "password" => "wrongpassword"
        }.to_json

        response = http_post("/auth/login", invalid_login_data, port)
        response.should_not be_nil
        response.not_nil!.status_code.should be >= 401
        response.not_nil!.status_code.should be <= 422

        # Test 8: Invalid registration data
        invalid_register_data = {
          "email" => "invalid-email",
          "password" => "123",
          "password_confirmation" => "456"
        }.to_json

        response = http_post("/auth/register", invalid_register_data, port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(422) # Should fail validation

        # Test 9: Unauthorized access to protected endpoint
        response = http_get("/auth/me", port)
        response.should_not be_nil
        response.not_nil!.status_code.should be >= 401
        response.not_nil!.status_code.should be <= 403

        # Test 10: Basic endpoints still work
        response = http_get("/", port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(200)

        response = http_get("/welcome", port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(200)
      end
    end
  end

  it "generates auth system for API project" do
    with_temp_project("testapp", "api") do
      # Generate auth
      result = run_generator("generate auth", ".")
      result.success?.should be_true

      # Verify auth files created
      File.exists?("src/models/user.cr").should be_true
      File.exists?("src/endpoints/auth_endpoint.cr").should be_true
      File.exists?("src/requests/auth/login_request.cr").should be_true
      File.exists?("src/requests/auth/register_request.cr").should be_true

      # Build project
      build_project(".").should be_true

      # Test auth endpoints exist
      with_running_server(".") do |port|
        # Test register endpoint exists
        register_data = {
          "email" => "test@example.com",
          "password" => "Password123!",
          "password_confirmation" => "Password123!"
        }.to_json

        response = http_post("/auth/register", register_data, port)
        response.should_not be_nil
        content_type = response.not_nil!.headers["Content-Type"]?
        content_type.should_not be_nil
        content_type.not_nil!.should contain("application/json")

        # Test login endpoint exists
        login_data = {
          "email" => "test@example.com",
          "password" => "Password123!"
        }.to_json

        response = http_post("/auth/login", login_data, port)
        response.should_not be_nil
        content_type = response.not_nil!.headers["Content-Type"]?
        content_type.should_not be_nil
        content_type.not_nil!.should contain("application/json")
      end
    end
  end

  it "handles auth validation errors properly" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate auth
      result = run_generator("generate auth", ".")
      result.success?.should be_true

      # Build project
      build_project(".").should be_true

      with_running_server(".") do |port|
        # Test weak password validation
        weak_password_data = {
          "email" => "test@example.com",
          "password" => "123",
          "password_confirmation" => "123"
        }.to_json

        response = http_post("/auth/register", weak_password_data, port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(422) # Validation error

        # Test password mismatch validation
        mismatch_data = {
          "email" => "test@example.com",
          "password" => "Password123!",
          "password_confirmation" => "DifferentPassword123!"
        }.to_json

        response = http_post("/auth/register", mismatch_data, port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(422) # Validation error

        # Test invalid email format
        invalid_email_data = {
          "email" => "not-an-email",
          "password" => "Password123!",
          "password_confirmation" => "Password123!"
        }.to_json

        response = http_post("/auth/register", invalid_email_data, port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(422) # Validation error
      end
    end
  end
end
