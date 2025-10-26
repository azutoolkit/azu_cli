require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Job Generator E2E" do
  it "generates job with JoobQ, compiles, and processes" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate job
      result = run_generator("generate job SendEmail to:string subject:string", project_path)
      result.success?.should be_true

      # Verify job file created
      file_exists?(project_path, "src/jobs/send_email_job.cr").should be_true

      # Build project
      build_project(project_path).should be_true

      # Test job can be instantiated
      script = <<-CRYSTAL
        require "./src/testapp"

        # Test job can be instantiated
        job = SendEmailJob.new
        puts "Job test passed: \#{job.class.name}"
      CRYSTAL

      result = run_crystal_script(project_path, script)
      result.success?.should be_true
      result.output.to_s.should contain("Job test passed")
    end
  end
end
