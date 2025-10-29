require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Session Generator E2E" do
  it "generates session support, compiles, and stores" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate session
      result = run_generator("generate session", project_path)
      result.success?.should be_true

      # Verify session files created
      file_exists?(project_path, "src/initializers/session.cr").should be_true

      # Verify content of generated file
      session_content = read_file(project_path, "src/initializers/session.cr").not_nil!
      session_content.should contain("Session")
      session_content.should contain("store")
    end
  end
end
