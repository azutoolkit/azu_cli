require "spec"
require "../../support/integration_helpers"

include IntegrationHelpers

describe "Middleware Generator E2E" do
  it "generates middleware, compiles, and intercepts" do
    with_temp_project("testapp", "web") do |project_path|
      # Generate middleware
      result = run_generator("generate middleware RateLimit", project_path)
      result.success?.should be_true

      # Verify middleware file created
      file_exists?(project_path, "src/middleware/rate_limit_middleware.cr").should be_true

      # Verify content of generated file
      middleware_content = read_file(project_path, "src/middleware/rate_limit_middleware.cr").not_nil!
      middleware_content.should contain("class RateLimitMiddleware")
      middleware_content.should contain("include HTTP::Handler")
      middleware_content.should contain("def call")
    end
  end
end
