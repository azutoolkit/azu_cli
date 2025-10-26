require "spec"
require "../support/integration_helpers"

include IntegrationHelpers

describe "Service Generator E2E" do
  it "generates service, compiles, and executes" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate service
      result = run_generator("generate service EmailSender to:string subject:string", project_path)
      result.success?.should be_true

      # Verify service file created
      file_exists?(project_path, "src/services/email_sender_service.cr").should be_true

      # Build project
      build_project(project_path).should be_true

      # Test service can be instantiated and used
      script = <<-CRYSTAL
        require "./src/testapp"

        # Test service can be instantiated
        service = EmailSenderService.new
        puts "Service test passed: \#{service.class.name}"
      CRYSTAL

      result = run_crystal_script(project_path, script)
      result.success?.should be_true
      result.output.to_s.should contain("Service test passed")
    end
  end
end
