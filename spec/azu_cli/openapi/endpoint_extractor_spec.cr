require "../../spec_helper"

describe AzuCLI::OpenAPI::EndpointExtractor do
  describe "#extract" do
    it "extracts endpoints from Crystal files" do
      Dir.mkdir_p("spec/fixtures/test_project/src/endpoints/users")

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

      extractor = AzuCLI::OpenAPI::EndpointExtractor.new("spec/fixtures/test_project")
      endpoints = extractor.extract

      endpoints.size.should eq(1)
      endpoints[0].name.should eq("Users::UsersIndexEndpoint")
      endpoints[0].method.should eq("get")
      endpoints[0].path.should eq("/users")
      endpoints[0].request_type.should eq("Users::UsersIndexRequest")
      endpoints[0].response_type.should eq("Users::UsersIndexPage")

      File.delete("spec/fixtures/test_project/src/endpoints/users/users_index_endpoint.cr")
      Dir.delete("spec/fixtures/test_project/src/endpoints/users")
      Dir.delete("spec/fixtures/test_project/src/endpoints")
      Dir.delete("spec/fixtures/test_project/src")
      Dir.delete("spec/fixtures/test_project")
    end

    it "extracts POST endpoints" do
      Dir.mkdir_p("spec/fixtures/test_project/src/endpoints/users")

      endpoint_content = <<-CRYSTAL
      struct Users::UsersCreateEndpoint
        include Azu::Endpoint(Users::UsersCreateRequest, Users::UsersCreatePage)

        post "/users"

        def call : Users::UsersCreatePage
          Users::UsersCreatePage.new
        end
      end
      CRYSTAL

      File.write("spec/fixtures/test_project/src/endpoints/users/users_create_endpoint.cr", endpoint_content)

      extractor = AzuCLI::OpenAPI::EndpointExtractor.new("spec/fixtures/test_project")
      endpoints = extractor.extract

      endpoints.size.should eq(1)
      endpoints[0].method.should eq("post")

      File.delete("spec/fixtures/test_project/src/endpoints/users/users_create_endpoint.cr")
      Dir.delete("spec/fixtures/test_project/src/endpoints/users")
      Dir.delete("spec/fixtures/test_project/src/endpoints")
      Dir.delete("spec/fixtures/test_project/src")
      Dir.delete("spec/fixtures/test_project")
    end

    it "returns empty array when no endpoints exist" do
      Dir.mkdir_p("spec/fixtures/empty_project")

      extractor = AzuCLI::OpenAPI::EndpointExtractor.new("spec/fixtures/empty_project")
      endpoints = extractor.extract

      endpoints.should be_empty

      Dir.delete("spec/fixtures/empty_project")
    end
  end
end
