require "../../spec_helper"

describe AzuCLI::OpenAPI::Parser do
  describe "#initialize" do
    it "parses valid YAML OpenAPI spec" do
      spec_content = <<-YAML
      openapi: 3.1.0
      info:
        title: Test API
        version: 1.0.0
      paths:
        /users:
          get:
            summary: Get users
            operationId: getUsers
            responses:
              '200':
                description: Success
      components:
        schemas:
          User:
            type: object
            properties:
              name:
                type: string
              email:
                type: string
      YAML

      File.write("spec/fixtures/test_spec.yaml", spec_content)
      parser = AzuCLI::OpenAPI::Parser.new("spec/fixtures/test_spec.yaml")

      parser.spec.openapi.should eq("3.1.0")
      parser.spec.info.title.should eq("Test API")
      parser.spec.info.version.should eq("1.0.0")

      File.delete("spec/fixtures/test_spec.yaml")
    end

    it "parses valid JSON OpenAPI spec" do
      spec_content = <<-JSON
      {
        "openapi": "3.1.0",
        "info": {
          "title": "Test API",
          "version": "1.0.0"
        },
        "paths": {}
      }
      JSON

      File.write("spec/fixtures/test_spec.json", spec_content)
      parser = AzuCLI::OpenAPI::Parser.new("spec/fixtures/test_spec.json")

      parser.spec.openapi.should eq("3.1.0")
      parser.spec.info.title.should eq("Test API")

      File.delete("spec/fixtures/test_spec.json")
    end
  end

  describe "#paths" do
    it "returns all paths from spec" do
      spec_content = <<-YAML
      openapi: 3.1.0
      info:
        title: Test API
        version: 1.0.0
      paths:
        /users:
          get:
            summary: Get users
        /posts:
          get:
            summary: Get posts
      YAML

      File.write("spec/fixtures/test_spec.yaml", spec_content)
      parser = AzuCLI::OpenAPI::Parser.new("spec/fixtures/test_spec.yaml")

      paths = parser.paths
      paths.size.should eq(2)
      paths.has_key?("/users").should be_true
      paths.has_key?("/posts").should be_true

      File.delete("spec/fixtures/test_spec.yaml")
    end
  end

  describe "#schemas" do
    it "returns all component schemas" do
      spec_content = <<-YAML
      openapi: 3.1.0
      info:
        title: Test API
        version: 1.0.0
      paths: {}
      components:
        schemas:
          User:
            type: object
          Post:
            type: object
      YAML

      File.write("spec/fixtures/test_spec.yaml", spec_content)
      parser = AzuCLI::OpenAPI::Parser.new("spec/fixtures/test_spec.yaml")

      schemas = parser.schemas
      schemas.size.should eq(2)
      schemas.has_key?("User").should be_true
      schemas.has_key?("Post").should be_true

      File.delete("spec/fixtures/test_spec.yaml")
    end
  end

  describe "#operations" do
    it "extracts operations from paths" do
      spec_content = <<-YAML
      openapi: 3.1.0
      info:
        title: Test API
        version: 1.0.0
      paths:
        /users:
          get:
            summary: Get users
            operationId: getUsers
          post:
            summary: Create user
            operationId: createUser
      YAML

      File.write("spec/fixtures/test_spec.yaml", spec_content)
      parser = AzuCLI::OpenAPI::Parser.new("spec/fixtures/test_spec.yaml")

      operations = parser.operations
      operations.size.should eq(2)
      operations[0].method.should eq("get")
      operations[0].path.should eq("/users")
      operations[1].method.should eq("post")

      File.delete("spec/fixtures/test_spec.yaml")
    end
  end
end

