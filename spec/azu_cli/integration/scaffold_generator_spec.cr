require "spec"
require "../support/integration_helpers"

include IntegrationHelpers

describe "Scaffold Generator E2E" do
  it "generates full scaffold for web project and works" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate scaffold
      result = run_generator("generate scaffold Post title:string body:text published:bool", project_path)
      result.success?.should be_true

      # Verify all scaffold files created
      # Model
      file_exists?(project_path, "src/models/post.cr").should be_true

      # Endpoints
      file_exists?(project_path, "src/endpoints/posts/index_endpoint.cr").should be_true
      file_exists?(project_path, "src/endpoints/posts/show_endpoint.cr").should be_true
      file_exists?(project_path, "src/endpoints/posts/new_endpoint.cr").should be_true
      file_exists?(project_path, "src/endpoints/posts/create_endpoint.cr").should be_true
      file_exists?(project_path, "src/endpoints/posts/edit_endpoint.cr").should be_true
      file_exists?(project_path, "src/endpoints/posts/update_endpoint.cr").should be_true
      file_exists?(project_path, "src/endpoints/posts/destroy_endpoint.cr").should be_true

      # Requests
      file_exists?(project_path, "src/requests/posts/index_request.cr").should be_true
      file_exists?(project_path, "src/requests/posts/show_request.cr").should be_true
      file_exists?(project_path, "src/requests/posts/new_request.cr").should be_true
      file_exists?(project_path, "src/requests/posts/create_request.cr").should be_true
      file_exists?(project_path, "src/requests/posts/edit_request.cr").should be_true
      file_exists?(project_path, "src/requests/posts/update_request.cr").should be_true
      file_exists?(project_path, "src/requests/posts/destroy_request.cr").should be_true

      # Pages
      file_exists?(project_path, "src/pages/posts/index_page.cr").should be_true
      file_exists?(project_path, "src/pages/posts/show_page.cr").should be_true
      file_exists?(project_path, "src/pages/posts/new_page.cr").should be_true
      file_exists?(project_path, "src/pages/posts/edit_page.cr").should be_true

      # Services
      file_exists?(project_path, "src/services/posts/index_service.cr").should be_true
      file_exists?(project_path, "src/services/posts/show_service.cr").should be_true
      file_exists?(project_path, "src/services/posts/create_service.cr").should be_true
      file_exists?(project_path, "src/services/posts/update_service.cr").should be_true
      file_exists?(project_path, "src/services/posts/destroy_service.cr").should be_true

      # Validators
      file_exists?(project_path, "src/validators/post.cr").should be_true

      # Templates
      file_exists?(project_path, "public/templates/posts/index_page.jinja").should be_true
      file_exists?(project_path, "public/templates/posts/show_page.jinja").should be_true
      file_exists?(project_path, "public/templates/posts/new_page.jinja").should be_true
      file_exists?(project_path, "public/templates/posts/edit_page.jinja").should be_true

      # Build project
      build_project(project_path).should be_true

      # Test all CRUD operations via HTTP
      with_running_server(project_path) do |port|
        # GET /posts (index)
        response = http_get("/posts", port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(200)

        # GET /posts/new (new form)
        response = http_get("/posts/new", port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(200)

        # POST /posts (create) - this might fail without proper form data, but endpoint should exist
        response = http_post("/posts", "", port)
        response.should_not be_nil
        # Should get some response (might be error due to missing form data, but endpoint exists)

        # GET /posts/1 (show)
        response = http_get("/posts/1", port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(200)

        # GET /posts/1/edit (edit form)
        response = http_get("/posts/1/edit", port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(200)
      end
    end
  end

  it "generates full scaffold for api project and works" do
    with_temp_project("testapp", "api") do |project_path|
      # Generate scaffold
      result = run_generator("generate scaffold User name:string email:string", project_path)
      result.success?.should be_true

      # Verify API-specific scaffold files
      file_exists?(project_path, "src/models/user.cr").should be_true
      file_exists?(project_path, "src/endpoints/users/index_endpoint.cr").should be_true
      file_exists?(project_path, "src/endpoints/users/show_endpoint.cr").should be_true
      file_exists?(project_path, "src/endpoints/users/create_endpoint.cr").should be_true
      file_exists?(project_path, "src/endpoints/users/update_endpoint.cr").should be_true
      file_exists?(project_path, "src/endpoints/users/destroy_endpoint.cr").should be_true

      # Build project
      build_project(project_path).should be_true

      # Test API endpoints respond with JSON
      with_running_server(project_path) do |port|
        response = http_get("/users", port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(200)
        response.not_nil!.headers["Content-Type"]?.should contain("application/json")

        response = http_get("/users/1", port)
        response.should_not be_nil
        response.not_nil!.status_code.should eq(200)
      end
    end
  end
end
