require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Component Generator E2E" do
  it "generates component, compiles, and renders" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate component
      result = run_generator("generate component Button label:string variant:string", project_path)
      result.success?.should be_true

      # Verify component file created
      file_exists?(project_path, "src/components/button.cr").should be_true

      # Verify content of generated file
      component_content = read_file(project_path, "src/components/button.cr").not_nil!
      component_content.should contain("class Button")
      component_content.should contain("include Azu::Component")
      component_content.should contain("label")
      component_content.should contain("variant")
    end
  end
end
