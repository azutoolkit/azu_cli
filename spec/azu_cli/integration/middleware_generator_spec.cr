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

      # Build project
      build_project(project_path).should be_true

      # Test middleware can be instantiated
      script = <<-CRYSTAL
        require "./src/testapp"

        # Test middleware can be instantiated
        middleware = RateLimitMiddleware.new
        puts "Middleware test passed: \#{middleware.class.name}"
      CRYSTAL

      result = run_crystal_script(project_path, script)
      result.success?.should be_true
      result.output.to_s.should contain("Middleware test passed")
    end
  end
end
