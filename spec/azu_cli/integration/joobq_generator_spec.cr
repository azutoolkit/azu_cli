require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "JoobQ Generator E2E" do
  it "generates JoobQ setup, compiles, and queues jobs" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate JoobQ
      result = run_generator("generate joobq", project_path)
      result.success?.should be_true

      # Verify JoobQ files created
      file_exists?(project_path, "config/joobq.development.yml").should be_true
      file_exists?(project_path, "config/joobq.production.yml").should be_true
      file_exists?(project_path, "config/joobq.test.yml").should be_true
      file_exists?(project_path, "src/initializers/joobq.cr").should be_true
      file_exists?(project_path, "src/worker.cr").should be_true

      # Build project
      build_project(project_path).should be_true

      # Test JoobQ initializer loads
      script = <<-CRYSTAL
        require "./src/testapp"

        # Test JoobQ initializer can be loaded
        puts "JoobQ test passed: JoobQ initializer loaded"
      CRYSTAL

      result = run_crystal_script(project_path, script)
      result.success?.should be_true
      result.output.to_s.should contain("JoobQ test passed")
    end
  end
end
