require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Mailer Generator E2E" do
  it "generates mailer, compiles, and sends" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate mailer
      result = run_generator("generate mailer Welcome user_name:string", project_path)
      result.success?.should be_true

      # Verify mailer files created
      file_exists?(project_path, "src/mailers/welcome_mailer.cr").should be_true
      file_exists?(project_path, "src/jobs/welcome_job.cr").should be_true

      # Verify content of generated files
      mailer_content = read_file(project_path, "src/mailers/welcome_mailer.cr").not_nil!
      mailer_content.should contain("class WelcomeMailer")
      mailer_content.should contain("Carbon::Email")
      mailer_content.should contain("def welcome")

      job_content = read_file(project_path, "src/jobs/welcome_job.cr").not_nil!
      job_content.should contain("struct WelcomeMailerJob")
      job_content.should contain("include JoobQ::Job")
    end
  end
end
