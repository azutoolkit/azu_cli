require "../../spec_helper"

describe AzuCLI::OpenAPI::ResponseExtractor do
  describe "#initialize" do
    it "initializes with default project path" do
      extractor = AzuCLI::OpenAPI::ResponseExtractor.new
      extractor.project_path.should eq(".")
    end

    it "initializes with custom project path" do
      extractor = AzuCLI::OpenAPI::ResponseExtractor.new("/custom/path")
      extractor.project_path.should eq("/custom/path")
    end
  end

  describe "#extract" do
    it "extracts responses from project" do
      # Create test project structure
      Dir.mkdir_p("spec/fixtures/response_test/src/pages/users")
      Dir.mkdir_p("spec/fixtures/response_test/src/responses/orders")

      # Create page file
      page_content = "struct Users::UsersShowPage\n  include Azu::Response\n  include JSON::Serializable\n\n  property id : Int32\n  property name : String\n  property email : String?\n\n  def render : String\n    to_json\n  end\nend"
      File.write("spec/fixtures/response_test/src/pages/users/users_show_page.cr", page_content)

      # Create response file
      response_content = "struct Orders::OrdersIndexResponse\n  include Azu::Page\n  include JSON::Serializable\n\n  property orders : Array(Order)\n  property total : Int32\n  property page : Int32?\n\n  def render : String\n    to_json\n  end\nend"
      File.write("spec/fixtures/response_test/src/responses/orders/orders_index_response.cr", response_content)

      extractor = AzuCLI::OpenAPI::ResponseExtractor.new("spec/fixtures/response_test")
      responses = extractor.extract

      responses.size.should eq(2)

      # Check first response
      response1 = responses.find { |r| r.name == "Users::UsersShowPage" }
      response1.should_not be_nil
      response1.not_nil!.properties["id"].should eq("Int32")
      response1.not_nil!.properties["name"].should eq("String")
      response1.not_nil!.properties["email"].should eq("String?")
      response1.not_nil!.file.should contain("users_show_page.cr")

      # Check second response
      response2 = responses.find { |r| r.name == "Orders::OrdersIndexResponse" }
      response2.should_not be_nil
      response2.not_nil!.properties["orders"].should eq("Array(Order)")
      response2.not_nil!.properties["total"].should eq("Int32")
      response2.not_nil!.properties["page"].should eq("Int32?")

      # Cleanup
      File.delete("spec/fixtures/response_test/src/pages/users/users_show_page.cr") if File.exists?("spec/fixtures/response_test/src/pages/users/users_show_page.cr")
      File.delete("spec/fixtures/response_test/src/responses/orders/orders_index_response.cr") if File.exists?("spec/fixtures/response_test/src/responses/orders/orders_index_response.cr")
      Dir.delete("spec/fixtures/response_test/src/pages/users") if Dir.exists?("spec/fixtures/response_test/src/pages/users")
      Dir.delete("spec/fixtures/response_test/src/pages") if Dir.exists?("spec/fixtures/response_test/src/pages")
      Dir.delete("spec/fixtures/response_test/src/responses/orders") if Dir.exists?("spec/fixtures/response_test/src/responses/orders")
      Dir.delete("spec/fixtures/response_test/src/responses") if Dir.exists?("spec/fixtures/response_test/src/responses")
      Dir.delete("spec/fixtures/response_test/src") if Dir.exists?("spec/fixtures/response_test/src")
      Dir.delete("spec/fixtures/response_test") if Dir.exists?("spec/fixtures/response_test")
    end

    it "handles files without response/page classes" do
      # Create test project structure
      Dir.mkdir_p("spec/fixtures/response_test/src/pages/users")

      # Create non-response file
      non_response_content = "class SomeHelper\n  def self.helper_method\n    \"helper\"\n  end\nend"
      File.write("spec/fixtures/response_test/src/pages/users/helper.cr", non_response_content)

      extractor = AzuCLI::OpenAPI::ResponseExtractor.new("spec/fixtures/response_test")
      responses = extractor.extract

      responses.size.should eq(0)

      # Cleanup
      File.delete("spec/fixtures/response_test/src/pages/users/helper.cr") if File.exists?("spec/fixtures/response_test/src/pages/users/helper.cr")
      Dir.delete("spec/fixtures/response_test/src/pages/users") if Dir.exists?("spec/fixtures/response_test/src/pages/users")
      Dir.delete("spec/fixtures/response_test/src/pages") if Dir.exists?("spec/fixtures/response_test/src/pages")
      Dir.delete("spec/fixtures/response_test/src") if Dir.exists?("spec/fixtures/response_test/src")
      Dir.delete("spec/fixtures/response_test") if Dir.exists?("spec/fixtures/response_test")
    end

    it "handles empty project" do
      # Create empty project structure
      Dir.mkdir_p("spec/fixtures/empty_response_test/src")

      extractor = AzuCLI::OpenAPI::ResponseExtractor.new("spec/fixtures/empty_response_test")
      responses = extractor.extract

      responses.size.should eq(0)

      # Cleanup
      Dir.delete("spec/fixtures/empty_response_test/src") if Dir.exists?("spec/fixtures/empty_response_test/src")
      Dir.delete("spec/fixtures/empty_response_test") if Dir.exists?("spec/fixtures/empty_response_test")
    end
  end

  describe "#response_files" do
    it "returns all response files" do
      # Create test project structure
      Dir.mkdir_p("spec/fixtures/response_test/src/pages/users")
      Dir.mkdir_p("spec/fixtures/response_test/src/responses/orders")

      # Create files
      File.write("spec/fixtures/response_test/src/pages/users/users_show_page.cr", "")
      File.write("spec/fixtures/response_test/src/responses/orders/orders_index_response.cr", "")

      extractor = AzuCLI::OpenAPI::ResponseExtractor.new("spec/fixtures/response_test")
      files = extractor.response_files

      files.size.should eq(2)
      files.any? { |f| f.ends_with?("users_show_page.cr") }.should be_true
      files.any? { |f| f.ends_with?("orders_index_response.cr") }.should be_true

      # Cleanup
      File.delete("spec/fixtures/response_test/src/pages/users/users_show_page.cr") if File.exists?("spec/fixtures/response_test/src/pages/users/users_show_page.cr")
      File.delete("spec/fixtures/response_test/src/responses/orders/orders_index_response.cr") if File.exists?("spec/fixtures/response_test/src/responses/orders/orders_index_response.cr")
      Dir.delete("spec/fixtures/response_test/src/pages/users") if Dir.exists?("spec/fixtures/response_test/src/pages/users")
      Dir.delete("spec/fixtures/response_test/src/pages") if Dir.exists?("spec/fixtures/response_test/src/pages")
      Dir.delete("spec/fixtures/response_test/src/responses/orders") if Dir.exists?("spec/fixtures/response_test/src/responses/orders")
      Dir.delete("spec/fixtures/response_test/src/responses") if Dir.exists?("spec/fixtures/response_test/src/responses")
      Dir.delete("spec/fixtures/response_test/src") if Dir.exists?("spec/fixtures/response_test/src")
      Dir.delete("spec/fixtures/response_test") if Dir.exists?("spec/fixtures/response_test")
    end
  end
end
