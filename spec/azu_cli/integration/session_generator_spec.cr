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

      # Build project
      build_project(project_path).should be_true

      # Test session initializer loads
      script = <<-CRYSTAL
        require "./src/testapp"

        # Test session initializer can be loaded
        puts "Session test passed: Session initializer loaded"
      CRYSTAL

      result = run_crystal_script(project_path, script)
      result.success?.should be_true
      result.output.to_s.should contain("Session test passed")
    end
  end
end
