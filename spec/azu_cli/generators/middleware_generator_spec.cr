require "../../spec_helper"

describe AzuCLI::Generate::Middleware do
  describe "#initialize" do
    it "creates a middleware generator with basic configuration" do
      generator = AzuCLI::Generate::Middleware.new("Authentication")

      generator.name.should eq("Authentication")
      generator.middleware_type.should eq("authentication")
      generator.skip_paths.should eq([] of String)
      generator.context_vars.should eq({} of String => String)
      generator.snake_case_name.should eq("authentication")
      generator.middleware_class_name.should eq("AuthenticationMiddleware")
    end

    it "creates a middleware generator with custom configuration" do
      skip_paths = ["/api/public", "/health"]
      context_vars = {"user" => "User", "role" => "String"}
      generator = AzuCLI::Generate::Middleware.new("Authorization", "authorization", skip_paths, context_vars)

      generator.name.should eq("Authorization")
      generator.middleware_type.should eq("authorization")
      generator.skip_paths.should eq(skip_paths)
      generator.context_vars.should eq(context_vars)
      generator.snake_case_name.should eq("authorization")
      generator.middleware_class_name.should eq("AuthorizationMiddleware")
    end
  end

  describe "#default_skip_paths" do
    it "returns authentication skip paths" do
      generator = AzuCLI::Generate::Middleware.new("Auth", "authentication")
      paths = generator.default_skip_paths

      paths.should contain("/")
      paths.should contain("/login")
      paths.should contain("/register")
      paths.should contain("/health")
      paths.should contain("/assets")
    end

    it "returns authorization skip paths" do
      generator = AzuCLI::Generate::Middleware.new("Auth", "authorization")
      paths = generator.default_skip_paths

      paths.should contain("/")
      paths.should contain("/health")
      paths.should contain("/assets")
    end

    it "returns logging skip paths" do
      generator = AzuCLI::Generate::Middleware.new("Log", "logging")
      paths = generator.default_skip_paths

      paths.should contain("/health")
      paths.should contain("/assets")
    end

    it "returns empty array for CORS" do
      generator = AzuCLI::Generate::Middleware.new("CORS", "cors")
      paths = generator.default_skip_paths

      paths.should eq([] of String)
    end

    it "returns rate limiting skip paths" do
      generator = AzuCLI::Generate::Middleware.new("Rate", "rate_limiting")
      paths = generator.default_skip_paths

      paths.should contain("/health")
    end
  end

  describe "#get_skip_paths" do
    it "returns custom skip paths when provided" do
      custom_paths = ["/api/public", "/docs"]
      generator = AzuCLI::Generate::Middleware.new("Auth", "authentication", custom_paths)

      generator.get_skip_paths.should eq(custom_paths)
    end

    it "returns default skip paths when none provided" do
      generator = AzuCLI::Generate::Middleware.new("Auth", "authentication")

      generator.get_skip_paths.should eq(generator.default_skip_paths)
    end
  end

  describe "#crystal_type" do
    it "maps variable types to Crystal types" do
      generator = AzuCLI::Generate::Middleware.new("Test")

      generator.crystal_type("string").should eq("String")
      generator.crystal_type("text").should eq("String")
      generator.crystal_type("int32").should eq("Int32")
      generator.crystal_type("integer").should eq("Int32")
      generator.crystal_type("int64").should eq("Int64")
      generator.crystal_type("float32").should eq("Float32")
      generator.crystal_type("float64").should eq("Float64")
      generator.crystal_type("float").should eq("Float64")
      generator.crystal_type("bool").should eq("Bool")
      generator.crystal_type("boolean").should eq("Bool")
      generator.crystal_type("time").should eq("Time")
      generator.crystal_type("datetime").should eq("Time")
      generator.crystal_type("date").should eq("Date")
      generator.crystal_type("user").should eq("User")
      generator.crystal_type("model").should eq("User")
      generator.crystal_type("array").should eq("Array(String)")
      generator.crystal_type("hash").should eq("Hash(String, String)")
      generator.crystal_type("json").should eq("JSON::Any")
      generator.crystal_type("unknown").should eq("String")
    end
  end

  describe "#context_vars_string" do
    it "generates context variables string" do
      context_vars = {
        "user"        => "User",
        "role"        => "String",
        "permissions" => "Array",
      }
      generator = AzuCLI::Generate::Middleware.new("Auth", context_vars: context_vars)

      expected = "user : User, role : String, permissions : Array(String)"
      generator.context_vars_string.should eq(expected)
    end

    it "returns empty string for no context variables" do
      generator = AzuCLI::Generate::Middleware.new("Simple")
      generator.context_vars_string.should eq("")
    end
  end

  describe "#middleware_logic" do
    it "generates authentication logic" do
      generator = AzuCLI::Generate::Middleware.new("Auth", "authentication")
      logic = generator.middleware_logic

      logic.should contain("Check for authentication token")
      logic.should contain("extract_token(context.request)")
      logic.should contain("valid_token?(token)")
      logic.should contain("HTTP::Status::UNAUTHORIZED")
      logic.should contain("get_user_from_token(token)")
      logic.should contain("context.set(\"current_user\", user)")
    end

    it "generates authorization logic" do
      generator = AzuCLI::Generate::Middleware.new("Auth", "authorization")
      logic = generator.middleware_logic

      logic.should contain("Check if user has required permissions")
      logic.should contain("context.get?(\"current_user\")")
      logic.should contain("has_permission?")
      logic.should contain("HTTP::Status::FORBIDDEN")
    end

    it "generates logging logic" do
      generator = AzuCLI::Generate::Middleware.new("Log", "logging")
      logic = generator.middleware_logic

      logic.should contain("Log request details")
      logic.should contain("Time.monotonic")
      logic.should contain("Log.info")
      logic.should contain("Log response details")
    end

    it "generates CORS logic" do
      generator = AzuCLI::Generate::Middleware.new("CORS", "cors")
      logic = generator.middleware_logic

      logic.should contain("Handle preflight requests")
      logic.should contain("OPTIONS")
      logic.should contain("Access-Control-Allow-Origin")
      logic.should contain("Access-Control-Allow-Methods")
    end

    it "generates rate limiting logic" do
      generator = AzuCLI::Generate::Middleware.new("Rate", "rate_limiting")
      logic = generator.middleware_logic

      logic.should contain("Check rate limits")
      logic.should contain("remote_address")
      logic.should contain("within_rate_limit?")
      logic.should contain("HTTP::Status::TOO_MANY_REQUESTS")
    end

    it "generates custom logic for unknown type" do
      generator = AzuCLI::Generate::Middleware.new("Custom", "unknown")
      logic = generator.middleware_logic

      logic.should contain("TODO: Implement custom middleware logic")
    end
  end

  describe "#private_methods" do
    it "generates authentication private methods" do
      generator = AzuCLI::Generate::Middleware.new("Auth", "authentication")
      methods = generator.private_methods

      methods.should contain("public_path?")
      methods.should contain("extract_token")
      methods.should contain("valid_token?")
      methods.should contain("get_user_from_token")
    end

    it "generates authorization private methods" do
      generator = AzuCLI::Generate::Middleware.new("Auth", "authorization")
      methods = generator.private_methods

      methods.should contain("has_permission?")
    end

    it "generates logging private methods" do
      generator = AzuCLI::Generate::Middleware.new("Log", "logging")
      methods = generator.private_methods

      methods.should contain("should_log?")
    end

    it "generates CORS private methods" do
      generator = AzuCLI::Generate::Middleware.new("CORS", "cors")
      methods = generator.private_methods

      methods.should contain("allowed_origin?")
    end

    it "generates rate limiting private methods" do
      generator = AzuCLI::Generate::Middleware.new("Rate", "rate_limiting")
      methods = generator.private_methods

      methods.should contain("within_rate_limit?")
    end

    it "generates custom private methods for unknown type" do
      generator = AzuCLI::Generate::Middleware.new("Custom", "unknown")
      methods = generator.private_methods

      methods.should contain("custom_validation?")
    end
  end

  describe "#has_context_vars?" do
    it "returns true when middleware has context variables" do
      context_vars = {"user" => "User"}
      generator = AzuCLI::Generate::Middleware.new("Auth", context_vars: context_vars)
      generator.has_context_vars?.should be_true
    end

    it "returns false when middleware has no context variables" do
      generator = AzuCLI::Generate::Middleware.new("Simple")
      generator.has_context_vars?.should be_false
    end
  end

  describe "template rendering" do
    it "generates an authentication middleware" do
      generator = AzuCLI::Generate::Middleware.new("Authentication", "authentication")

      temp_dir = File.join(Dir.tempdir, "middleware_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      begin
        generator.render(temp_dir)

        middleware_file = File.join(temp_dir, "authentication_middleware.cr")
        File.exists?(middleware_file).should be_true

        content = File.read(middleware_file)
        content.should contain("class AuthenticationMiddleware")
        content.should contain("include HTTP::Handler")
        content.should contain("def call(context)")
        content.should contain("public_path?(context.request.path)")
        content.should contain("call_next(context)")
        content.should contain("Check for authentication token")
        content.should contain("extract_token(context.request)")
        content.should contain("valid_token?(token)")
        content.should contain("get_user_from_token(token)")
      ensure
        FileUtils.rm_rf(temp_dir)
      end
    end

    it "generates an authorization middleware with custom skip paths" do
      skip_paths = ["/api/public", "/docs"]
      generator = AzuCLI::Generate::Middleware.new("Authorization", "authorization", skip_paths)

      temp_dir = File.join(Dir.tempdir, "middleware_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      begin
        generator.render(temp_dir)

        middleware_file = File.join(temp_dir, "authorization_middleware.cr")
        File.exists?(middleware_file).should be_true

        content = File.read(middleware_file)
        content.should contain("class AuthorizationMiddleware")
        content.should contain("Check if user has required permissions")
        content.should contain("has_permission?")
        content.should contain("/api/public")
        content.should contain("/docs")
      ensure
        FileUtils.rm_rf(temp_dir)
      end
    end

    it "generates a logging middleware" do
      generator = AzuCLI::Generate::Middleware.new("RequestLogging", "logging")

      temp_dir = File.join(Dir.tempdir, "middleware_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      begin
        generator.render(temp_dir)

        middleware_file = File.join(temp_dir, "request_logging_middleware.cr")
        File.exists?(middleware_file).should be_true

        content = File.read(middleware_file)
        content.should contain("class RequestLoggingMiddleware")
        content.should contain("Log request details")
        content.should contain("Time.monotonic")
        content.should contain("Log.info")
        content.should contain("should_log?")
      ensure
        FileUtils.rm_rf(temp_dir)
      end
    end

    it "generates a CORS middleware" do
      generator = AzuCLI::Generate::Middleware.new("CORS", "cors")

      temp_dir = File.join(Dir.tempdir, "middleware_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      begin
        generator.render(temp_dir)

        middleware_file = File.join(temp_dir, "cors_middleware.cr")
        File.exists?(middleware_file).should be_true

        content = File.read(middleware_file)
        content.should contain("class CORSMiddleware")
        content.should contain("Handle preflight requests")
        content.should contain("OPTIONS")
        content.should contain("Access-Control-Allow-Origin")
        content.should contain("allowed_origin?")
      ensure
        FileUtils.rm_rf(temp_dir)
      end
    end

    it "generates a rate limiting middleware" do
      generator = AzuCLI::Generate::Middleware.new("RateLimiting", "rate_limiting")

      temp_dir = File.join(Dir.tempdir, "middleware_generator_test_#{Random::Secure.hex(8)}")
      Dir.mkdir_p(temp_dir)
      begin
        generator.render(temp_dir)

        middleware_file = File.join(temp_dir, "rate_limiting_middleware.cr")
        File.exists?(middleware_file).should be_true

        content = File.read(middleware_file)
        content.should contain("class RateLimitingMiddleware")
        content.should contain("Check rate limits")
        content.should contain("remote_address")
        content.should contain("within_rate_limit?")
        content.should contain("HTTP::Status::TOO_MANY_REQUESTS")
      ensure
        FileUtils.rm_rf(temp_dir)
      end
    end
  end
end
