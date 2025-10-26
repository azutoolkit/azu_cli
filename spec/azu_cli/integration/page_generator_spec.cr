require "spec"
require "../support/integration_helpers"

include IntegrationHelpers

describe "Page Generator E2E" do
  it "generates page response, compiles, and renders" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate page
      result = run_generator("generate page Posts index", project_path)
      result.success?.should be_true

      # Verify page files created
      file_exists?(project_path, "src/pages/posts/index_page.cr").should be_true
      file_exists?(project_path, "public/templates/posts/index_page.jinja").should be_true

      # Build project
      build_project(project_path).should be_true

      # Test page can be instantiated
      script = <<-CRYSTAL
        require "./src/testapp"

        # Test page can be instantiated
        page = Posts::IndexPage.new
        puts "Page test passed: \#{page.class.name}"
      CRYSTAL

      result = run_crystal_script(project_path, script)
      result.success?.should be_true
      result.output.to_s.should contain("Page test passed")
    end
  end
end
