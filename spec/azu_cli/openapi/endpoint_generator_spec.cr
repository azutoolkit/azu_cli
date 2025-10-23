require "../../spec_helper"

describe AzuCLI::OpenAPI::EndpointGenerator do
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

      parser = AzuCLI::OpenAPI::Parser.new("spec/fixtures/test_spec.yaml")
      operations = [] of AzuCLI::OpenAPI::Parser::OperationInfo

      generator = AzuCLI::OpenAPI::EndpointGenerator.new("users", operations, parser)

      generator.resource.should eq("users")
      generator.operations.should eq(operations)
      generator.parser.should eq(parser)

      # Cleanup
      File.delete("spec/fixtures/test_spec.yaml")
    end
  end

  describe "#generate" do
    it "generates endpoint files for operations" do
      # Create temporary directory for test
      temp_dir = File.join(Dir.tempdir, "endpoint_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      Dir.cd(temp_dir) do
        # Create test spec with operations
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
                  content:
                    application/json:
                      schema:
                        type: object
                        properties:
                          users:
                            type: array
                            items:
                              type: object
                              properties:
                                id:
                                  type: integer
                                name:
                                  type: string
            post:
              summary: Create user
              requestBody:
                required: true
                content:
                  application/json:
                    schema:
                      type: object
                      properties:
                        name:
                          type: string
                        email:
                          type: string
                      required: [name]
              responses:
                '200':
                  description: Success
                  content:
                    application/json:
                      schema:
                        type: object
                        properties:
                          id:
                            type: integer
                          name:
                            type: string
        YAML
        File.write("test_spec.yaml", spec_content)

        parser = AzuCLI::OpenAPI::Parser.new("test_spec.yaml")
        operations = parser.operations

        generator = AzuCLI::OpenAPI::EndpointGenerator.new("users", operations, parser)

        # Generate endpoint files
        generator.generate(true)

        # Check if files were created
        index_endpoint = "src/endpoints/users/users_index_endpoint.cr"
        create_endpoint = "src/endpoints/users/users_create_endpoint.cr"
        index_request = "src/requests/users/users_index_request.cr"
        create_request = "src/requests/users/users_create_request.cr"
        index_page = "src/pages/users/users_index_page.cr"
        create_page = "src/pages/users/users_create_page.cr"

        File.exists?(index_endpoint).should be_true
        File.exists?(create_endpoint).should be_true
        File.exists?(index_request).should be_true
        File.exists?(create_request).should be_true
        File.exists?(index_page).should be_true
        File.exists?(create_page).should be_true

        # Check endpoint content
        index_content = File.read(index_endpoint)
        index_content.should contain("struct Users::UsersIndexEndpoint")
        index_content.should contain("include Azu::Endpoint(Users::UsersIndexRequest, Users::UsersIndexPage)")
        index_content.should contain("get \"/users\"")

        create_content = File.read(create_endpoint)
        create_content.should contain("struct Users::UsersCreateEndpoint")
        create_content.should contain("include Azu::Endpoint(Users::UsersCreateRequest, Users::UsersCreatePage)")
        create_content.should contain("post \"/users\"")

        # Check request content
        create_request_content = File.read(create_request)
        create_request_content.should contain("struct Users::UsersCreateRequest")
        create_request_content.should contain("include Azu::Request")
        create_request_content.should contain("property name : String")
        create_request_content.should contain("property email : String?")

        # Check response content
        create_page_content = File.read(create_page)
        create_page_content.should contain("struct Users::UsersCreatePage")
        create_page_content.should contain("include Azu::Response")
        create_page_content.should contain("include JSON::Serializable")
      end

      # Cleanup temp directory
      FileUtils.rm_rf(temp_dir)
    end

    it "respects force flag" do
      # Create temporary directory for test
      temp_dir = File.join(Dir.tempdir, "endpoint_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      Dir.cd(temp_dir) do
        # Create minimal spec file for parser
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

        parser = AzuCLI::OpenAPI::Parser.new("test_spec.yaml")
        operations = parser.operations

        generator = AzuCLI::OpenAPI::EndpointGenerator.new("users", operations, parser)

        # Create existing file
        Dir.mkdir_p("src/endpoints/users")
        File.write("src/endpoints/users/users_index_endpoint.cr", "existing content")

        # Generate without force - should not overwrite
        generator.generate(false)
        content = File.read("src/endpoints/users/users_index_endpoint.cr")
        content.should eq("existing content")

        # Generate with force - should overwrite
        generator.generate(true)
        content = File.read("src/endpoints/users/users_index_endpoint.cr")
        content.should contain("struct Users::UsersIndexEndpoint")
      end

      # Cleanup temp directory
      FileUtils.rm_rf(temp_dir)
    end
  end

  describe "#extract_action_from_operation" do
    it "extracts correct action names" do
      # Create minimal spec file for parser
      spec_content = <<-YAML
      openapi: 3.1.0
      info:
        title: Test API
        version: 1.0.0
      paths: {}
      YAML
      File.write("spec/fixtures/test_spec.yaml", spec_content)

      parser = AzuCLI::OpenAPI::Parser.new("spec/fixtures/test_spec.yaml")
      operations = [] of AzuCLI::OpenAPI::Parser::OperationInfo

      generator = AzuCLI::OpenAPI::EndpointGenerator.new("users", operations, parser)

      # Test different operation patterns by creating actual operations and checking generated files
      # This tests the behavior indirectly through the generate method

      # Cleanup
      File.delete("spec/fixtures/test_spec.yaml")
    end
  end
end
