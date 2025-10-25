require "../../spec_helper"

describe AzuCLI::OpenAPI::RequestExtractor do
  describe "#initialize" do
    it "initializes with default project path" do
      extractor = AzuCLI::OpenAPI::RequestExtractor.new
      extractor.project_path.should eq(".")
    end

    it "initializes with custom project path" do
      extractor = AzuCLI::OpenAPI::RequestExtractor.new("/custom/path")
      extractor.project_path.should eq("/custom/path")
    end
  end

  describe "#extract" do
    it "extracts requests from project" do
      # Create test project structure with unique name
      test_dir = "spec/fixtures/request_test_#{Time.utc.to_unix}"
      Dir.mkdir_p("#{test_dir}/src/requests/users")
      Dir.mkdir_p("#{test_dir}/src/contracts/orders")

      # Create request file
      request_content = "struct Users::UsersCreateRequest\n  include Azu::Request\n\n  property name : String\n  property email : String\n  property age : Int32?\nend"
      File.write("#{test_dir}/src/requests/users/users_create_request.cr", request_content)

      # Create contract file
      contract_content = "struct Orders::OrdersCreateContract\n  include Azu::Contract\n\n  property product_id : Int32\n  property quantity : Int32\n  property notes : String?\nend"
      File.write("#{test_dir}/src/contracts/orders/orders_create_contract.cr", contract_content)

      extractor = AzuCLI::OpenAPI::RequestExtractor.new(test_dir)
      requests = extractor.extract

      requests.size.should eq(2)

      # Check first request
      request1 = requests.find { |r| r.name == "Users::UsersCreateRequest" }
      request1.should_not be_nil
      request1.not_nil!.properties["name"].should eq("String")
      request1.not_nil!.properties["email"].should eq("String")
      request1.not_nil!.properties["age"].should eq("Int32?")
      request1.not_nil!.file.should contain("users_create_request.cr")

      # Check second request
      request2 = requests.find { |r| r.name == "Orders::OrdersCreateContract" }
      request2.should_not be_nil
      request2.not_nil!.properties["product_id"].should eq("Int32")
      request2.not_nil!.properties["quantity"].should eq("Int32")
      request2.not_nil!.properties["notes"].should eq("String?")

      # Cleanup
      File.delete("#{test_dir}/src/requests/users/users_create_request.cr") if File.exists?("#{test_dir}/src/requests/users/users_create_request.cr")
      File.delete("#{test_dir}/src/contracts/orders/orders_create_contract.cr") if File.exists?("#{test_dir}/src/contracts/orders/orders_create_contract.cr")
      Dir.delete("#{test_dir}/src/requests/users") if Dir.exists?("#{test_dir}/src/requests/users")
      Dir.delete("#{test_dir}/src/requests") if Dir.exists?("#{test_dir}/src/requests")
      Dir.delete("#{test_dir}/src/contracts/orders") if Dir.exists?("#{test_dir}/src/contracts/orders")
      Dir.delete("#{test_dir}/src/contracts") if Dir.exists?("#{test_dir}/src/contracts")
      Dir.delete("#{test_dir}/src") if Dir.exists?("#{test_dir}/src")
      Dir.delete(test_dir) if Dir.exists?(test_dir)
    end

    it "handles files without request/contract classes" do
      # Create test project structure
      Dir.mkdir_p("spec/fixtures/request_test/src/requests/users")

      # Create non-request file
      non_request_content = "class SomeHelper\n  def self.helper_method\n    \"helper\"\n  end\nend"
      File.write("spec/fixtures/request_test/src/requests/users/helper.cr", non_request_content)

      extractor = AzuCLI::OpenAPI::RequestExtractor.new("spec/fixtures/request_test")
      requests = extractor.extract

      requests.size.should eq(0)

      # Cleanup
      File.delete("spec/fixtures/request_test/src/requests/users/helper.cr") if File.exists?("spec/fixtures/request_test/src/requests/users/helper.cr")
      Dir.delete("spec/fixtures/request_test/src/requests/users") if Dir.exists?("spec/fixtures/request_test/src/requests/users")
      Dir.delete("spec/fixtures/request_test/src/requests") if Dir.exists?("spec/fixtures/request_test/src/requests")
      Dir.delete("spec/fixtures/request_test/src") if Dir.exists?("spec/fixtures/request_test/src")
      Dir.delete("spec/fixtures/request_test") if Dir.exists?("spec/fixtures/request_test")
    end

    it "handles empty project" do
      # Create empty project structure
      Dir.mkdir_p("spec/fixtures/empty_request_test/src")

      extractor = AzuCLI::OpenAPI::RequestExtractor.new("spec/fixtures/empty_request_test")
      requests = extractor.extract

      requests.size.should eq(0)

      # Cleanup
      Dir.delete("spec/fixtures/empty_request_test/src") if Dir.exists?("spec/fixtures/empty_request_test/src")
      Dir.delete("spec/fixtures/empty_request_test") if Dir.exists?("spec/fixtures/empty_request_test")
    end
  end

  describe "#request_files" do
    it "returns all request files" do
      # Create test project structure
      Dir.mkdir_p("spec/fixtures/request_test/src/requests/users")
      Dir.mkdir_p("spec/fixtures/request_test/src/contracts/orders")

      # Create files
      File.write("spec/fixtures/request_test/src/requests/users/users_create_request.cr", "")
      File.write("spec/fixtures/request_test/src/contracts/orders/orders_create_contract.cr", "")

      extractor = AzuCLI::OpenAPI::RequestExtractor.new("spec/fixtures/request_test")
      files = extractor.request_files

      files.size.should eq(2)
      files.any?(&.ends_with?("users_create_request.cr")).should be_true
      files.any?(&.ends_with?("orders_create_contract.cr")).should be_true

      # Cleanup
      File.delete("spec/fixtures/request_test/src/requests/users/users_create_request.cr") if File.exists?("spec/fixtures/request_test/src/requests/users/users_create_request.cr")
      File.delete("spec/fixtures/request_test/src/contracts/orders/orders_create_contract.cr") if File.exists?("spec/fixtures/request_test/src/contracts/orders/orders_create_contract.cr")
      Dir.delete("spec/fixtures/request_test/src/requests/users") if Dir.exists?("spec/fixtures/request_test/src/requests/users")
      Dir.delete("spec/fixtures/request_test/src/requests") if Dir.exists?("spec/fixtures/request_test/src/requests")
      Dir.delete("spec/fixtures/request_test/src/contracts/orders") if Dir.exists?("spec/fixtures/request_test/src/contracts/orders")
      Dir.delete("spec/fixtures/request_test/src/contracts") if Dir.exists?("spec/fixtures/request_test/src/contracts")
      Dir.delete("spec/fixtures/request_test/src") if Dir.exists?("spec/fixtures/request_test/src")
      Dir.delete("spec/fixtures/request_test") if Dir.exists?("spec/fixtures/request_test")
    end
  end
end
