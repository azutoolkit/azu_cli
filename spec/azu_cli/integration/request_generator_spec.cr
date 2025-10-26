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

      # Build project
      build_project(project_path).should be_true

      # Test request can be instantiated
      script = <<-CRYSTAL
        require "./src/testapp"

        # Test request can be instantiated
        request = User::CreateRequest.new
        puts "Request test passed: \#{request.class.name}"
      CRYSTAL

      result = run_crystal_script(project_path, script)
      result.success?.should be_true
      result.output.to_s.should contain("Request test passed")
    end
  end
end
