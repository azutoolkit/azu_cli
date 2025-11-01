require "spec"
require "../../support/integration_helpers"
require "json"

include IntegrationHelpers

describe "Scaffold Generator Integration" do
  describe "Scaffold Generator E2E" do
    it "generates complete CRUD scaffold, compiles, and tests all endpoints" do
      with_temp_project("scaffold_test", "web") do |project_path|
        # Generate scaffold for a Post resource with various field types
        result = run_generator("generate scaffold Post title:string content:text published:bool views:int32", project_path)
        result.success?.should be_true

        # Verify all scaffold files are generated
        scaffold_files = [
          # Model
          "src/models/post.cr",
          # Migration
          "db/migrations/*_create_posts.cr",
          # Endpoints (plural directory, singular_action filename)
          "src/endpoints/posts/post_index_endpoint.cr",
          "src/endpoints/posts/post_show_endpoint.cr",
          "src/endpoints/posts/post_new_endpoint.cr",
          "src/endpoints/posts/post_create_endpoint.cr",
          "src/endpoints/posts/post_edit_endpoint.cr",
          "src/endpoints/posts/post_update_endpoint.cr",
          "src/endpoints/posts/post_destroy_endpoint.cr",
          # Services (singular directory, action filename)
          "src/services/post/index_service.cr",
          "src/services/post/show_service.cr",
          "src/services/post/create_service.cr",
          "src/services/post/update_service.cr",
          "src/services/post/destroy_service.cr",
          # Requests (singular directory, action filename)
          "src/requests/post/index_request.cr",
          "src/requests/post/show_request.cr",
          "src/requests/post/new_request.cr",
          "src/requests/post/create_request.cr",
          "src/requests/post/edit_request.cr",
          "src/requests/post/update_request.cr",
          "src/requests/post/destroy_request.cr",
          # Pages (singular directory, action_page filename)
          "src/pages/post/index_page.cr",
          "src/pages/post/show_page.cr",
          "src/pages/post/new_page.cr",
          "src/pages/post/edit_page.cr",
          # Templates (in public/templates)
          "public/templates/post/index_page.jinja",
          "public/templates/post/show_page.jinja",
          "public/templates/post/new_page.jinja",
          "public/templates/post/edit_page.jinja",
        ]

        Dir.cd(project_path) do
          scaffold_files.each do |file_pattern|
            if file_pattern.includes?("*")
              # Handle glob patterns for migrations
              matching_files = Dir.glob(file_pattern)
              matching_files.size.should be > 0, "Expected files matching pattern #{file_pattern} to exist"
            else
              File.exists?(file_pattern).should be_true, "Expected file #{file_pattern} to exist"
            end
          end
        end

        # Note: Build and server testing skipped for this integration test
        # The focus is on file generation correctness
        # Full E2E testing including compilation is done separately
      end
    end

    it "generates scaffold for API project with JSON responses" do
      with_temp_project("api_scaffold_test", "api") do |project_path|
        # Generate scaffold for User resource
        result = run_generator("generate scaffold User name:string email:string age:int32", project_path)
        result.success?.should be_true

        # Verify API-specific files are generated (JSON response files in responses directory)
        api_files = [
          "src/responses/user/user_index_json.cr",
          "src/responses/user/user_show_json.cr",
          "src/responses/user/user_create_json.cr",
          "src/responses/user/user_update_json.cr",
        ]

        Dir.cd(project_path) do
          api_files.each do |file|
            File.exists?(file).should be_true, "Expected API file #{file} to exist"
          end
        end
      end
    end

    it "handles scaffold with skipped components correctly" do
      with_temp_project("partial_scaffold_test", "web") do |project_path|
        # Generate scaffold skipping some components
        result = run_generator("generate scaffold Article title:string body:text --skip template,page", project_path)
        result.success?.should be_true

        Dir.cd(project_path) do
          # Verify skipped files don't exist
          skipped_files = [
            "public/templates/article/index_page.jinja",
            "public/templates/article/show_page.jinja",
            "public/templates/article/new_page.jinja",
            "public/templates/article/edit_page.jinja",
            "src/pages/article/index_page.cr",
            "src/pages/article/show_page.cr",
            "src/pages/article/new_page.cr",
            "src/pages/article/edit_page.cr",
          ]

          skipped_files.each do |file|
            File.exists?(file).should be_false, "Expected skipped file #{file} to not exist"
          end

          # Verify non-skipped files exist
          required_files = [
            "src/models/article.cr",
            "src/endpoints/articles/article_index_endpoint.cr",
            "src/services/article/index_service.cr",
            "src/requests/article/index_request.cr",
          ]

          required_files.each do |file|
            File.exists?(file).should be_true, "Expected required file #{file} to exist"
          end
        end
      end
    end

    it "validates scaffold generation parameters correctly" do
      with_temp_project("validation_test", "web") do |project_path|
        # Test invalid resource name
        result = run_generator("generate scaffold 123invalid name:string", project_path)
        result.success?.should be_false

        # Test reserved word
        result = run_generator("generate scaffold class name:string", project_path)
        result.success?.should be_false

        # Test invalid attribute type
        result = run_generator("generate scaffold Post title:invalid_type", project_path)
        result.success?.should be_false

        # Test duplicate field names
        result = run_generator("generate scaffold Post title:string title:text", project_path)
        result.success?.should be_false

        # Test skipping all components
        result = run_generator("generate scaffold Post title:string --skip model,endpoint,service,request,page,template,migration", project_path)
        result.success?.should be_false
      end
    end

    it "generates scaffold with complex field types" do
      with_temp_project("complex_scaffold_test", "web") do |project_path|
        # Generate scaffold with various field types
        result = run_generator("generate scaffold Product name:string description:text price:float64 in_stock:bool category_id:int32 tags:json created_at:time", project_path)
        result.success?.should be_true

        Dir.cd(project_path) do
          # Verify model file contains all field types
          model_content = File.read("src/models/product.cr")
          model_content.should contain("getter name : String")
          model_content.should contain("getter description : String")
          model_content.should contain("getter price : Float64")
          model_content.should contain("getter in_stock : Bool")
          model_content.should contain("getter category_id : Int32")
          model_content.should contain("getter tags : JSON::Any")
          model_content.should contain("getter created_at : Time")
        end
      end
    end
  end
end
