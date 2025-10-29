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

      # Verify content of generated file
      job_content = read_file(project_path, "src/jobs/send_email_job.cr").not_nil!
      job_content.should contain("struct SendEmailJob")
      job_content.should contain("include JoobQ::Job")
      job_content.should contain("def perform")
      job_content.should contain("to")
      job_content.should contain("subject")
    end
  end
end
