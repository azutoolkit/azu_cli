require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Service Generator E2E" do
  it "generates service, compiles, and executes" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate service
      result = run_generator("generate service EmailSender to:string subject:string", project_path)
      result.success?.should be_true

      # Verify service files created (generates all CRUD actions by default)
      file_exists?(project_path, "src/services/email_sender/create_service.cr").should be_true
      file_exists?(project_path, "src/services/email_sender/index_service.cr").should be_true
      file_exists?(project_path, "src/services/result.cr").should be_true

      # Verify content of generated files
      create_content = read_file(project_path, "src/services/email_sender/create_service.cr").not_nil!
      create_content.should contain("module EmailSender")
      create_content.should contain("class CreateService")
      create_content.should contain("Services::Result")

      result_content = read_file(project_path, "src/services/result.cr").not_nil!
      result_content.should contain("module Services")
      # Verify Result class is generic
      result_content.should contain("class Result(T)")
      # Verify factory methods
      result_content.should contain("def self.success")
      result_content.should contain("def self.failure")
      # Verify uses CQL validation errors
      result_content.should contain("CQL::ActiveRecord::Validations::Errors")
      # Verify success/failure predicates
      result_content.should contain("def success?")
      result_content.should contain("def failure?")
    end
  end

  it "generates services with correct return types" do
    with_temp_project("testapp", "web") do |project_path|
      result = run_generator("generate service Order item:string quantity:int32", project_path)
      result.success?.should be_true

      # Verify CreateService returns Result with model type
      create_content = read_file(project_path, "src/services/order/create_service.cr").not_nil!
      create_content.should contain("Services::Result(Order::Order)")

      # Verify IndexService returns Result with Array type
      index_content = read_file(project_path, "src/services/order/index_service.cr").not_nil!
      index_content.should contain("Services::Result(Array(Order::Order))")

      # Verify ShowService accepts ID parameter
      show_content = read_file(project_path, "src/services/order/show_service.cr").not_nil!
      show_content.should contain("def call(id :")

      # Verify UpdateService accepts ID and request
      update_content = read_file(project_path, "src/services/order/update_service.cr").not_nil!
      update_content.should contain("def call(id :")
      update_content.should contain("request : Order::UpdateRequest")
    end
  end

  it "generates services with proper error handling" do
    with_temp_project("testapp", "web") do |project_path|
      result = run_generator("generate service Task name:string", project_path)
      result.success?.should be_true

      # Verify rescue blocks are present
      create_content = read_file(project_path, "src/services/task/create_service.cr").not_nil!
      create_content.should contain("rescue ex")
      create_content.should contain("Log.error")

      # Verify CQL::RecordNotFound handling in show service
      show_content = read_file(project_path, "src/services/task/show_service.cr").not_nil!
      show_content.should contain("rescue CQL::RecordNotFound")
    end
  end
end
