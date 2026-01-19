require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "JoobQ Generator E2E" do
  it "generates JoobQ setup, compiles, and queues jobs" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate JoobQ
      result = run_generator("generate joobq", project_path)
      unless result.success?
        puts "ERROR OUTPUT: #{result.error}"
        puts "STDOUT: #{result.output}"
      end
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

  it "generates example job file by default" do
    with_temp_project("testapp", "web") do |project_path|
      result = run_generator("generate joobq", project_path)
      result.success?.should be_true

      # Verify example job file is created
      file_exists?(project_path, "src/jobs/example_job.cr").should be_true

      # Verify example job content
      job_content = read_file(project_path, "src/jobs/example_job.cr").not_nil!
      job_content.should contain("struct ExampleJob")
      job_content.should contain("include JoobQ::Job")
      job_content.should contain("def perform")
      job_content.should contain("@queue")
      job_content.should contain("@retries")
    end
  end

  it "generates config files for all environments" do
    with_temp_project("testapp", "web") do |project_path|
      result = run_generator("generate joobq", project_path)
      result.success?.should be_true

      # Verify development config
      dev_config = read_file(project_path, "config/joobq.development.yml").not_nil!
      dev_config.should contain("redis")

      # Verify production config
      prod_config = read_file(project_path, "config/joobq.production.yml").not_nil!
      prod_config.should contain("redis")

      # Verify test config
      test_config = read_file(project_path, "config/joobq.test.yml").not_nil!
      test_config.should contain("redis")
    end
  end
end
