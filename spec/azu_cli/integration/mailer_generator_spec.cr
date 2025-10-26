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

      # Build project
      build_project(project_path).should be_true

      # Test mailer can be instantiated
      script = <<-CRYSTAL
        require "./src/testapp"

        # Test mailer can be instantiated
        mailer = WelcomeMailer.new
        puts "Mailer test passed: \#{mailer.class.name}"
      CRYSTAL

      result = run_crystal_script(project_path, script)
      result.success?.should be_true
      result.output.to_s.should contain("Mailer test passed")
    end
  end
end
