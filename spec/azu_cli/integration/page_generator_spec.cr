require "spec"
require "../../support/integration_helpers"

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

      # Verify content of generated files
      page_content = read_file(project_path, "src/pages/posts/index_page.cr").not_nil!
      page_content.should contain("module Testapp")
      page_content.should contain("Posts::IndexPage")
      page_content.should contain("include Azu::Response")

      template_content = read_file(project_path, "public/templates/posts/index_page.jinja").not_nil!
      template_content.should contain("posts")
    end
  end
end
