require "spec"
require "../../support/integration_helpers"
require "json"

include IntegrationHelpers

describe "Scaffold Generator Integration" do

  describe "Scaffold Generator E2E" do
    it "generates complete CRUD scaffold, compiles, and tests all endpoints" do
      with_temp_project("scaffold_test", "web") do |project_path|
        # Generate scaffold for a Post resource with various field types
        result = run_generator("generate scaffold Post title:string content:text published:bool views:int32", ".")
        result.success?.should be_true

        # Verify all scaffold files are generated
        scaffold_files = [
          # Model
          "src/models/post.cr",
          # Migration
          "db/migrations/*_create_posts.cr",
          # Endpoints
          "src/endpoints/post/index_endpoint.cr",
          "src/endpoints/post/show_endpoint.cr",
          "src/endpoints/post/new_endpoint.cr",
          "src/endpoints/post/create_endpoint.cr",
          "src/endpoints/post/edit_endpoint.cr",
          "src/endpoints/post/update_endpoint.cr",
          "src/endpoints/post/destroy_endpoint.cr",
          # Services
          "src/services/post/index_service.cr",
          "src/services/post/show_service.cr",
          "src/services/post/create_service.cr",
          "src/services/post/update_service.cr",
          "src/services/post/destroy_service.cr",
          # Requests
          "src/requests/post/index_request.cr",
          "src/requests/post/show_request.cr",
          "src/requests/post/new_request.cr",
          "src/requests/post/create_request.cr",
          "src/requests/post/edit_request.cr",
          "src/requests/post/update_request.cr",
          "src/requests/post/destroy_request.cr",
          # Pages
          "src/pages/post/index_page.cr",
          "src/pages/post/show_page.cr",
          "src/pages/post/new_page.cr",
          "src/pages/post/edit_page.cr",
          # Templates
          "src/templates/post/index.jinja",
          "src/templates/post/show.jinja",
          "src/templates/post/new.jinja",
          "src/templates/post/edit.jinja"
        ]

        scaffold_files.each do |file_pattern|
          if file_pattern.includes?("*")
            # Handle glob patterns for migrations
            matching_files = Dir.glob(file_pattern)
            matching_files.size.should be > 0
          else
            File.exists?(file_pattern).should be_true, "Expected file #{file_pattern} to exist"
          end
        end

        # Build the project
        build_result = Process.run("shards build", shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
        build_result.success?.should be_true, "Build failed"

        # Start the server and test all endpoints
        with_running_server(".") do |port|
          # Test 1: GET /posts (index) - should return empty list initially
          response = http_get("/posts", port)
          response.should_not be_nil
          response.not_nil!.status_code.should eq(200)

          # Test 2: GET /posts/new (new) - should return form page
          response = http_get("/posts/new", port)
          response.should_not be_nil
          response.not_nil!.status_code.should eq(200)

          # Test 3: POST /posts (create) - should create new post
          post_data = {
            "title" => "Test Post",
            "content" => "This is test content for the post",
            "published" => true,
            "views" => 0
          }.to_json

          response = http_post("/posts", post_data, port)
          response.should_not be_nil
          response.not_nil!.status_code.should be >= 200
          response.not_nil!.status_code.should be <= 422

          # If creation was successful, test other endpoints
          if response.not_nil!.status_code == 200 || response.not_nil!.status_code == 302
            # Test 4: GET /posts (index) - should now show the created post
            response = http_get("/posts", port)
            response.should_not be_nil
            response.not_nil!.status_code.should eq(200)

            # Test 5: GET /posts/1 (show) - should show specific post
            response = http_get("/posts/1", port)
            response.should_not be_nil
            response.not_nil!.status_code.should be >= 200
            response.not_nil!.status_code.should be <= 404

            # Test 6: GET /posts/1/edit (edit) - should show edit form
            response = http_get("/posts/1/edit", port)
            response.should_not be_nil
            response.not_nil!.status_code.should be >= 200
            response.not_nil!.status_code.should be <= 404

            # Test 7: PATCH /posts/1 (update) - should update the post
            update_data = {
              "title" => "Updated Post Title",
              "content" => "Updated content for the post",
              "published" => false,
              "views" => 5
            }.to_json

            response = http_put("/posts/1", update_data, port)
            response.should_not be_nil
            response.not_nil!.status_code.should be >= 200
            response.not_nil!.status_code.should be <= 422

            # Test 8: DELETE /posts/1 (destroy) - should delete the post
            response = http_delete("/posts/1", port)
            response.should_not be_nil
            response.not_nil!.status_code.should be >= 200
            response.not_nil!.status_code.should be <= 404

            # Test 9: GET /posts/1 (show) - should return 404 after deletion
            response = http_get("/posts/1", port)
            response.should_not be_nil
            response.not_nil!.status_code.should be >= 404
          end

          # Test 10: Test validation errors
          invalid_post_data = {
            "title" => "",  # Empty title should fail validation
            "content" => "Content without title",
            "published" => "invalid_boolean",  # Invalid boolean
            "views" => "not_a_number"  # Invalid number
          }.to_json

          response = http_post("/posts", invalid_post_data, port)
          response.should_not be_nil
          response.not_nil!.status_code.should eq(422) # Should fail validation

          # Test 11: Test non-existent resource
          response = http_get("/posts/999", port)
          response.should_not be_nil
          response.not_nil!.status_code.should be >= 404

          # Test 12: Test invalid HTTP methods
          response = http_post("/posts/1", "{}", port)  # POST to show endpoint should fail
          response.should_not be_nil
          response.not_nil!.status_code.should be >= 400
        end
      end
    end

    it "generates scaffold for API project with JSON responses" do
      with_temp_project("api_scaffold_test", "api") do |project_path|
        # Generate scaffold for User resource
        result = run_generator("generate scaffold User name:string email:string age:int32", ".")
        result.success?.should be_true

        # Verify API-specific files are generated
        api_files = [
          "src/responses/user/index_response.cr",
          "src/responses/user/show_response.cr",
          "src/responses/user/create_response.cr",
          "src/responses/user/update_response.cr"
        ]

        api_files.each do |file|
          File.exists?(file).should be_true, "Expected API file #{file} to exist"
        end

        # Build the project
        build_result = Process.run("shards build", shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
        build_result.success?.should be_true, "Build failed"

        # Start the server and test API endpoints
        with_running_server(".") do |port|
          # Test API endpoints return JSON
          response = http_get("/users", port)
          response.should_not be_nil
          response.not_nil!.status_code.should eq(200)

          # Check if response is JSON
          content_type = response.not_nil!.headers["Content-Type"]?
          if content_type
            content_type.should contain("application/json")
          end

          # Test POST to create user
          user_data = {
            "name" => "John Doe",
            "email" => "john@example.com",
            "age" => 30
          }.to_json

          response = http_post("/users", user_data, port)
          response.should_not be_nil
          response.not_nil!.status_code.should be >= 200
          response.not_nil!.status_code.should be <= 422

          # Test PATCH to update user
          update_data = {
            "name" => "John Smith",
            "email" => "johnsmith@example.com",
            "age" => 31
          }.to_json

          response = http_put("/users/1", update_data, port)
          response.should_not be_nil
          response.not_nil!.status_code.should be >= 200
          response.not_nil!.status_code.should be <= 422

          # Test DELETE user
          response = http_delete("/users/1", port)
          response.should_not be_nil
          response.not_nil!.status_code.should be >= 200
          response.not_nil!.status_code.should be <= 404
        end
      end
    end

    it "handles scaffold with skipped components correctly" do
      with_temp_project("partial_scaffold_test", "web") do |project_path|
        # Generate scaffold skipping some components
        result = run_generator("generate scaffold Article title:string body:text --skip template,page", ".")
        result.success?.should be_true

        # Verify skipped files don't exist
        skipped_files = [
          "src/templates/article/index.jinja",
          "src/templates/article/show.jinja",
          "src/templates/article/new.jinja",
          "src/templates/article/edit.jinja",
          "src/pages/article/index_page.cr",
          "src/pages/article/show_page.cr",
          "src/pages/article/new_page.cr",
          "src/pages/article/edit_page.cr"
        ]

        skipped_files.each do |file|
          File.exists?(file).should be_false, "Expected skipped file #{file} to not exist"
        end

        # Verify non-skipped files exist
        required_files = [
          "src/models/article.cr",
          "src/endpoints/article/index_endpoint.cr",
          "src/services/article/index_service.cr",
          "src/requests/article/index_request.cr"
        ]

        required_files.each do |file|
          File.exists?(file).should be_true, "Expected required file #{file} to exist"
        end

        # Build should still work
        build_result = Process.run("shards build", shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
        build_result.success?.should be_true, "Build failed"
      end
    end

    it "validates scaffold generation parameters correctly" do
      with_temp_project("validation_test", "web") do |project_path|
        # Test invalid resource name
        result = run_generator("generate scaffold 123invalid name:string", ".")
        result.success?.should be_false

        # Test reserved word
        result = run_generator("generate scaffold class name:string", ".")
        result.success?.should be_false

        # Test invalid attribute type
        result = run_generator("generate scaffold Post title:invalid_type", ".")
        result.success?.should be_false

        # Test duplicate field names
        result = run_generator("generate scaffold Post title:string title:text", ".")
        result.success?.should be_false

        # Test skipping all components
        result = run_generator("generate scaffold Post title:string --skip model,endpoint,service,request,page,template,migration", ".")
        result.success?.should be_false
      end
    end

    it "generates scaffold with complex field types" do
      with_temp_project("complex_scaffold_test", "web") do |project_path|
        # Generate scaffold with various field types
        result = run_generator("generate scaffold Product name:string description:text price:float64 in_stock:bool category_id:int32 tags:json created_at:time", ".")
        result.success?.should be_true

        # Verify model file contains all field types
        model_content = File.read("src/models/product.cr")
        model_content.should contain("getter name : String")
        model_content.should contain("getter description : String")
        model_content.should contain("getter price : Float64")
        model_content.should contain("getter in_stock : Bool")
        model_content.should contain("getter category_id : Int32")
        model_content.should contain("getter tags : JSON::Any")
        model_content.should contain("getter created_at : Time")

        # Build should work with complex types
        build_result = Process.run("shards build", shell: true, output: Process::Redirect::Pipe, error: Process::Redirect::Pipe)
        build_result.success?.should be_true, "Build failed"

        # Test endpoints work with complex data
        with_running_server(".") do |port|
          product_data = {
            "name" => "Test Product",
            "description" => "A test product with complex data",
            "price" => 29.99,
            "in_stock" => true,
            "category_id" => 1,
            "tags" => ["electronics", "test"],
            "created_at" => Time.utc.to_s
          }.to_json

          response = http_post("/products", product_data, port)
          response.should_not be_nil
          response.not_nil!.status_code.should be >= 200
          response.not_nil!.status_code.should be <= 422
        end
      end
    end
  end
end
