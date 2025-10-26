require "spec"
require "../support/integration_helpers"

include IntegrationHelpers

describe "Component Generator E2E" do
  it "generates component, compiles, and renders" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate component
      result = run_generator("generate component Button label:string variant:string", project_path)
      result.success?.should be_true

      # Verify component file created
      file_exists?(project_path, "src/components/button.cr").should be_true

      # Build project
      build_project(project_path).should be_true

      # Test component can be instantiated
      script = <<-CRYSTAL
        require "./src/testapp"

        # Test component can be instantiated
        component = Button.new
        puts "Component test passed: \#{component.class.name}"
      CRYSTAL

      result = run_crystal_script(project_path, script)
      result.success?.should be_true
      result.output.to_s.should contain("Component test passed")
    end
  end
end
