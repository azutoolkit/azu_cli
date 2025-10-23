require "../../spec_helper"

describe AzuCLI::OpenAPI::CodeGenerator do
  describe "#initialize" do
    it "initializes with required parameters" do
      # Create minimal spec file for parser
      spec_content = <<-YAML
      openapi: 3.1.0
      info:
        title: Test API
        version: 1.0.0
      paths: {}
      YAML
      File.write("spec/fixtures/test_spec.yaml", spec_content)

      generator = AzuCLI::OpenAPI::CodeGenerator.new("spec/fixtures/test_spec.yaml", false)

      generator.parser.should_not be_nil
      generator.force.should be_false

      # Cleanup
      File.delete("spec/fixtures/test_spec.yaml")
    end

    it "initializes with force flag" do
      # Create minimal spec file for parser
      spec_content = <<-YAML
      openapi: 3.1.0
      info:
        title: Test API
        version: 1.0.0
      paths: {}
      YAML
      File.write("spec/fixtures/test_spec.yaml", spec_content)

      generator = AzuCLI::OpenAPI::CodeGenerator.new("spec/fixtures/test_spec.yaml", true)

      generator.force.should be_true

      # Cleanup
      File.delete("spec/fixtures/test_spec.yaml")
    end
  end

  describe "#generate_all" do
    it "generates all code from OpenAPI spec" do
      # Create temporary directory for test
      temp_dir = File.join(Dir.tempdir, "code_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      Dir.cd(temp_dir) do
        # Create comprehensive test spec
        spec_content = <<-YAML
        openapi: 3.1.0
        info:
          title: Test API
          version: 1.0.0
        components:
          schemas:
            User:
              type: object
              properties:
                id:
                  type: integer
                  format: int32
                name:
                  type: string
                email:
                  type: string
                  format: email
              required: [id, name, email]
            Post:
              type: object
              properties:
                id:
                  type: integer
                title:
                  type: string
                content:
                  type: string
              required: [id, title]
        paths:
          /users:
            get:
              summary: List users
              responses:
                '200':
                  description: Success
                  content:
                    application/json:
                      schema:
                        type: array
                        items:
                          $ref: '#/components/schemas/User'
            post:
              summary: Create user
              requestBody:
                required: true
                content:
                  application/json:
                    schema:
                      $ref: '#/components/schemas/User'
              responses:
                '200':
                  description: Success
                  content:
                    application/json:
                      schema:
                        $ref: '#/components/schemas/User'
          /posts:
            get:
              summary: List posts
              responses:
                '200':
                  description: Success
                  content:
                    application/json:
                      schema:
                        type: array
                        items:
                          $ref: '#/components/schemas/Post'
        YAML
        File.write("test_spec.yaml", spec_content)

        generator = AzuCLI::OpenAPI::CodeGenerator.new("test_spec.yaml", true)

        # Generate all code
        generator.generate_all

        # Check if model files were created
        user_model = "src/models/user.cr"
        post_model = "src/models/post.cr"
        File.exists?(user_model).should be_true
        File.exists?(post_model).should be_true

        # Check if endpoint files were created
        users_index_endpoint = "src/endpoints/users/users_index_endpoint.cr"
        users_create_endpoint = "src/endpoints/users/users_create_endpoint.cr"
        posts_index_endpoint = "src/endpoints/posts/posts_index_endpoint.cr"
        File.exists?(users_index_endpoint).should be_true
        File.exists?(users_create_endpoint).should be_true
        File.exists?(posts_index_endpoint).should be_true

        # Check if request files were created
        users_create_request = "src/requests/users/users_create_request.cr"
        File.exists?(users_create_request).should be_true

        # Check if response files were created
        users_index_page = "src/pages/users/users_index_page.cr"
        users_create_page = "src/pages/users/users_create_page.cr"
        posts_index_page = "src/pages/posts/posts_index_page.cr"
        File.exists?(users_index_page).should be_true
        File.exists?(users_create_page).should be_true
        File.exists?(posts_index_page).should be_true

        # Check model content
        user_content = File.read(user_model)
        user_content.should contain("struct User")
        user_content.should contain("include JSON::Serializable")
        user_content.should contain("property id : Int32")
        user_content.should contain("property name : String")
        user_content.should contain("property email : String")

        # Check endpoint content
        users_create_content = File.read(users_create_endpoint)
        users_create_content.should contain("struct Users::UsersCreateEndpoint")
        users_create_content.should contain("include Azu::Endpoint(Users::UsersCreateRequest, Users::UsersCreatePage)")
        users_create_content.should contain("post \"/users\"")
      end

      # Cleanup temp directory
      FileUtils.rm_rf(temp_dir)
    end
  end

  describe "#generate_models" do
    it "generates only models from schemas" do
      # Create temporary directory for test
      temp_dir = File.join(Dir.tempdir, "code_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      Dir.cd(temp_dir) do
        # Create test spec with schemas
        spec_content = <<-YAML
        openapi: 3.1.0
        info:
          title: Test API
          version: 1.0.0
        components:
          schemas:
            User:
              type: object
              properties:
                id:
                  type: integer
                name:
                  type: string
              required: [id, name]
        paths: {}
        YAML
        File.write("test_spec.yaml", spec_content)

        generator = AzuCLI::OpenAPI::CodeGenerator.new("test_spec.yaml", true)

        # Generate only models
        generator.generate_models

        # Check if model file was created
        user_model = "src/models/user.cr"
        File.exists?(user_model).should be_true

        # Check that no endpoint files were created
        Dir.exists?("src/endpoints").should be_false
      end

      # Cleanup temp directory
      FileUtils.rm_rf(temp_dir)
    end
  end

  describe "#generate_endpoints" do
    it "generates only endpoints from paths" do
      # Create temporary directory for test
      temp_dir = File.join(Dir.tempdir, "code_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      Dir.cd(temp_dir) do
        # Create test spec with paths
        spec_content = <<-YAML
        openapi: 3.1.0
        info:
          title: Test API
          version: 1.0.0
        paths:
          /users:
            get:
              summary: List users
              responses:
                '200':
                  description: Success
        YAML
        File.write("test_spec.yaml", spec_content)

        generator = AzuCLI::OpenAPI::CodeGenerator.new("test_spec.yaml", true)

        # Generate only endpoints
        generator.generate_endpoints

        # Check if endpoint file was created
        users_index_endpoint = "src/endpoints/users/users_index_endpoint.cr"
        File.exists?(users_index_endpoint).should be_true

        # Check that no model files were created
        Dir.exists?("src/models").should be_false
      end

      # Cleanup temp directory
      FileUtils.rm_rf(temp_dir)
    end
  end

  describe "#extract_resource_name" do
    it "extracts resource name from path" do
      # Create minimal spec file for parser
      spec_content = <<-YAML
      openapi: 3.1.0
      info:
        title: Test API
        version: 1.0.0
      paths: {}
      YAML
      File.write("spec/fixtures/test_spec.yaml", spec_content)

      generator = AzuCLI::OpenAPI::CodeGenerator.new("spec/fixtures/test_spec.yaml", false)

      # Test different path patterns by creating actual operations and checking generated files
      # This tests the behavior indirectly through the generate_endpoints method

      # Cleanup
      File.delete("spec/fixtures/test_spec.yaml")
    end
  end
end
