require "../../spec_helper"

describe AzuCLI::OpenAPI::SpecBuilder do
  describe "#build" do
    it "builds OpenAPI spec from project" do
      # Create test project structure
      Dir.mkdir_p("spec/fixtures/test_project/src/models")
      Dir.mkdir_p("spec/fixtures/test_project/src/endpoints/users")

      # Create model
      model_content = <<-CRYSTAL
      struct User
        property name : String
        property email : String
      end
      CRYSTAL
      File.write("spec/fixtures/test_project/src/models/user.cr", model_content)

      # Create endpoint
      endpoint_content = <<-CRYSTAL
      struct Users::UsersIndexEndpoint
        include Azu::Endpoint(Users::UsersIndexRequest, Users::UsersIndexPage)

        get "/users"

        def call : Users::UsersIndexPage
          Users::UsersIndexPage.new
        end
      end
      CRYSTAL
      File.write("spec/fixtures/test_project/src/endpoints/users/users_index_endpoint.cr", endpoint_content)

      builder = AzuCLI::OpenAPI::SpecBuilder.new("TestProject", "1.0.0", "spec/fixtures/test_project")
      spec = builder.build

      spec.openapi.should eq("3.1.0")
      spec.info.title.should eq("TestProject API")
      spec.info.version.should eq("1.0.0")
      spec.paths.should_not be_nil
      spec.components.should_not be_nil

      # Cleanup
      File.delete("spec/fixtures/test_project/src/models/user.cr")
      File.delete("spec/fixtures/test_project/src/endpoints/users/users_index_endpoint.cr")
      Dir.delete("spec/fixtures/test_project/src/models")
      Dir.delete("spec/fixtures/test_project/src/endpoints/users")
      Dir.delete("spec/fixtures/test_project/src/endpoints")
      Dir.delete("spec/fixtures/test_project/src")
      Dir.delete("spec/fixtures/test_project")
    end

    it "generates correct server information" do
      Dir.mkdir_p("spec/fixtures/test_project")

      builder = AzuCLI::OpenAPI::SpecBuilder.new("TestProject", "1.0.0", "spec/fixtures/test_project")
      spec = builder.build

      servers = spec.servers
      servers.should_not be_nil
      servers.not_nil!.size.should be > 0
      servers.not_nil![0].url.should eq("http://localhost:3000")

      Dir.delete("spec/fixtures/test_project")
    end

    it "includes models in component schemas" do
      Dir.mkdir_p("spec/fixtures/test_project/src/models")

      model_content = <<-CRYSTAL
      struct Post
        property title : String
        property content : String
      end
      CRYSTAL
      File.write("spec/fixtures/test_project/src/models/post.cr", model_content)

      builder = AzuCLI::OpenAPI::SpecBuilder.new("TestProject", "1.0.0", "spec/fixtures/test_project")
      spec = builder.build

      components = spec.components
      components.should_not be_nil
      schemas = components.not_nil!.schemas
      schemas.should_not be_nil
      schemas.not_nil!.has_key?("Post").should be_true

      # Cleanup
      File.delete("spec/fixtures/test_project/src/models/post.cr")
      Dir.delete("spec/fixtures/test_project/src/models")
      Dir.delete("spec/fixtures/test_project/src")
      Dir.delete("spec/fixtures/test_project")
    end
  end
end

