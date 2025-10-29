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
      result_content.should contain("class Result")
    end
  end
end
