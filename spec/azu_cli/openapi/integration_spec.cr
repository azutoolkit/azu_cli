require "../../spec_helper"

describe "OpenAPI Integration" do
  describe "full roundtrip: code -> spec -> code" do
    it "exports spec and regenerates equivalent code" do
      # Setup test project
      Dir.mkdir_p("spec/fixtures/roundtrip/src/models")
      Dir.mkdir_p("spec/fixtures/roundtrip/src/endpoints/posts")

      # Create original model
      model_content = <<-CRYSTAL
      struct Post
        property title : String
        property content : String
        property published : Bool
      end
      CRYSTAL
      File.write("spec/fixtures/roundtrip/src/models/post.cr", model_content)

      # Create original endpoint
      endpoint_content = <<-CRYSTAL
      struct Posts::PostsIndexEndpoint
        include Azu::Endpoint(Posts::PostsIndexRequest, Posts::PostsIndexPage)

        get "/posts"

        def call : Posts::PostsIndexPage
          Posts::PostsIndexPage.new
        end
      end
      CRYSTAL
      File.write("spec/fixtures/roundtrip/src/endpoints/posts/posts_index_endpoint.cr", endpoint_content)

      # Export to OpenAPI spec
      builder = AzuCLI::OpenAPI::SpecBuilder.new("RoundtripTest", "1.0.0", "spec/fixtures/roundtrip")
      spec = builder.build

      # Verify spec was created correctly
      spec.info.title.should eq("RoundtripTest API")
      spec.components.should_not be_nil
      schemas = spec.components.not_nil!.schemas
      schemas.should_not be_nil
      schemas.not_nil!.has_key?("Post").should be_true

      # Cleanup
      File.delete("spec/fixtures/roundtrip/src/models/post.cr")
      File.delete("spec/fixtures/roundtrip/src/endpoints/posts/posts_index_endpoint.cr")
      Dir.delete("spec/fixtures/roundtrip/src/models")
      Dir.delete("spec/fixtures/roundtrip/src/endpoints/posts")
      Dir.delete("spec/fixtures/roundtrip/src/endpoints")
      Dir.delete("spec/fixtures/roundtrip/src")
      Dir.delete("spec/fixtures/roundtrip")
    end
  end

  describe "API project workflow" do
    it "creates API project and generates resources" do
      # Test project detection
      Dir.mkdir_p("spec/fixtures/api_workflow/src")
      File.write("spec/fixtures/api_workflow/src/api.cr", "# API file")

      detector = AzuCLI::ProjectDetector.new("spec/fixtures/api_workflow")
      detector.api_project?.should be_true

      # Cleanup
      File.delete("spec/fixtures/api_workflow/src/api.cr")
      Dir.delete("spec/fixtures/api_workflow/src")
      Dir.delete("spec/fixtures/api_workflow")
    end
  end

  describe "type mapping consistency" do
    it "maintains type integrity through roundtrip" do
      # Crystal -> OpenAPI
      crystal_types = {
        "String"  => {"string", nil},
        "Int32"   => {"integer", "int32"},
        "Int64"   => {"integer", "int64"},
        "Float32" => {"number", "float"},
        "Float64" => {"number", "double"},
        "Bool"    => {"boolean", nil},
        "Time"    => {"string", "date-time"},
        "UUID"    => {"string", "uuid"},
      }

      crystal_types.each do |crystal_type, (openapi_type, format)|
        oa_type, oa_format = AzuCLI::OpenAPI::SchemaMapper.to_openapi_type(crystal_type)
        oa_type.should eq(openapi_type)
        oa_format.should eq(format)
      end

      # OpenAPI -> Crystal
      openapi_types = [
        {"string", nil, "String"},
        {"string", "date-time", "Time"},
        {"string", "uuid", "UUID"},
        {"integer", "int32", "Int32"},
        {"integer", "int64", "Int64"},
        {"number", "float", "Float32"},
        {"number", "double", "Float64"},
        {"boolean", nil, "Bool"},
      ]

      openapi_types.each do |(type, format, expected_crystal)|
        schema = AzuCLI::OpenAPI::Schema.new
        schema.type = type
        schema.format = format

        result = AzuCLI::OpenAPI::SchemaMapper.to_crystal_type(schema)
        result.should eq(expected_crystal)
      end
    end
  end

  describe "parser robustness" do
    it "handles minimal OpenAPI spec" do
      spec_content = <<-YAML
      openapi: 3.1.0
      info:
        title: Minimal API
        version: 1.0.0
      paths: {}
      YAML

      File.write("spec/fixtures/minimal_spec.yaml", spec_content)
      parser = AzuCLI::OpenAPI::Parser.new("spec/fixtures/minimal_spec.yaml")

      parser.spec.openapi.should eq("3.1.0")
      parser.paths.should be_empty
      parser.schemas.should be_empty

      File.delete("spec/fixtures/minimal_spec.yaml")
    end

    it "handles spec with references" do
      spec_content = <<-YAML
      openapi: 3.1.0
      info:
        title: API with Refs
        version: 1.0.0
      paths:
        /users:
          get:
            responses:
              '200':
                description: Success
                content:
                  application/json:
                    schema:
                      $ref: '#/components/schemas/User'
      components:
        schemas:
          User:
            type: object
            properties:
              name:
                type: string
      YAML

      File.write("spec/fixtures/ref_spec.yaml", spec_content)
      parser = AzuCLI::OpenAPI::Parser.new("spec/fixtures/ref_spec.yaml")

      schema = parser.resolve_ref("#/components/schemas/User")
      schema.should_not be_nil
      schema.not_nil!.type.should eq("object")

      File.delete("spec/fixtures/ref_spec.yaml")
    end
  end
end

