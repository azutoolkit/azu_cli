require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Service Generator E2E" do
  it "generates the write services of a resource" do
    with_temp_project("testapp", "web") do |project_path|
      result = run_generator("generate service EmailSender to:string subject:string", project_path)
      result.success?.should be_true

      file_exists?(project_path, "src/services/email_senders/create_service.cr").should be_true
      file_exists?(project_path, "src/services/email_senders/update_service.cr").should be_true
      file_exists?(project_path, "src/services/email_senders/destroy_service.cr").should be_true

      create_content = read_file(project_path, "src/services/email_senders/create_service.cr").not_nil!
      create_content.should contain("module Testapp")
      create_content.should contain("class EmailSenders::CreateService")
      create_content.should contain("def call(request : EmailSenders::CreateRequest) : EmailSender")
    end
  end
end
