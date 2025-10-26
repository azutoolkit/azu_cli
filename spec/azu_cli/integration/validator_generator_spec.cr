require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Validator Generator E2E" do
  it "generates validator, compiles, and validates" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate validator
      result = run_generator("generate validator Email", project_path)
      result.success?.should be_true

      # Verify validator file created
      file_exists?(project_path, "src/validators/email.cr").should be_true

      # Build project
      build_project(project_path).should be_true

      # Test validator can be used
      script = <<-CRYSTAL
        require "./src/testapp"

        # Test validator can be instantiated
        validator = EmailValidator.new
        puts "Validator test passed: \#{validator.class.name}"
      CRYSTAL

      result = run_crystal_script(project_path, script)
      result.success?.should be_true
      result.output.to_s.should contain("Validator test passed")
    end
  end
end
