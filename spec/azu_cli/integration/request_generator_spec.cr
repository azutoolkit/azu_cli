require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Request Generator E2E" do
  it "generates request contract, compiles, and validates" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate request
      result = run_generator("generate request User create name:string email:string", project_path)
      result.success?.should be_true

      # Verify request file created
      file_exists?(project_path, "src/requests/user/create_request.cr").should be_true

      # Verify content of generated file
      request_content = read_file(project_path, "src/requests/user/create_request.cr").not_nil!
      request_content.should contain("module Testapp") # Project module name
      request_content.should contain("struct User::CreateRequest")
      request_content.should contain("include Azu::Request")
      request_content.should contain("name")
      request_content.should contain("email")
    end
  end
end
