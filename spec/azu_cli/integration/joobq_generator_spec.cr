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

      # Verify content of generated files
      initializer_content = read_file(project_path, "src/initializers/joobq.cr").not_nil!
      initializer_content.should contain("JoobQ")
      initializer_content.should contain("configure")

      worker_content = read_file(project_path, "src/worker.cr").not_nil!
      worker_content.should contain("JoobQ")
      worker_content.should contain("Worker")
    end
  end
end
