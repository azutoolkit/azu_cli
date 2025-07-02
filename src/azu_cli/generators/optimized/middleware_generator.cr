require "../core/abstract_generator"

module AzuCLI::Generator
  # Optimized Middleware Generator following SOLID principles
  # Uses configuration-driven approach with Template Method pattern
  class MiddlewareGenerator < Core::AbstractGenerator
    property middleware_type : String

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @middleware_type = options.custom_options["type"]? || "custom"
      super(name, project_name, options.force, options.skip_tests)
    end

    # Concrete implementation of abstract method
    def generator_type : String
      "middleware"
    end

    # Concrete implementation of abstract method
    def generate_files : Nil
      generate_middleware_file
    end

    # Override to add middleware-specific directory creation
    def create_directories : Nil
      super

      # Create middleware-specific directories from configuration
      middleware_dir = config.get("directories.source") || "src/middleware"
      file_strategy.create_directory(middleware_dir)

      unless skip_tests
        spec_dir = config.get("directories.spec") || "spec/middleware"
        file_strategy.create_directory(spec_dir)
      end
    end

    # Override to generate middleware tests
    def generate_tests : Nil
      return if skip_tests

      test_template = config.get("templates.spec") || "middleware/middleware_spec.cr.ecr"
      test_path = "spec/middleware/#{snake_case_name}_spec.cr"

      test_variables = generate_test_variables

      create_file_from_template(
        test_template,
        test_path,
        test_variables,
        "middleware test"
      )
    end

    # Generate the main middleware file
    private def generate_middleware_file : Nil
      template = config.get("templates.main") || "middleware/middleware.cr.ecr"
      output_path = "src/middleware/#{snake_case_name}.cr"

      middleware_variables = generate_middleware_variables

      create_file_from_template(
        template,
        output_path,
        middleware_variables,
        "middleware"
      )
    end

    # Generate template variables specific to middleware
    private def generate_middleware_variables : Hash(String, String)
      default_template_variables.merge({
        "middleware_implementation" => generate_middleware_implementation,
        "middleware_type"           => @middleware_type,
        "helper_methods"            => generate_helper_methods,
      })
    end

    # Generate test-specific template variables
    private def generate_test_variables : Hash(String, String)
      default_template_variables.merge({
        "test_methods"      => generate_test_methods,
        "middleware_type"   => @middleware_type,
        "mock_helpers"      => generate_mock_helpers,
      })
    end

    # Generate middleware implementation based on type
    private def generate_middleware_implementation : String
      middleware_types = config.get_hash("middleware_types.#{@middleware_type}")

      case @middleware_type
      when "authentication"
        generate_authentication_middleware
      when "authorization"
        generate_authorization_middleware
      when "cors"
        generate_cors_middleware
      when "rate_limiting"
        generate_rate_limiting_middleware
      when "logging"
        generate_logging_middleware
      when "security"
        generate_security_middleware
      else
        generate_custom_middleware
      end
    end

    # Generate authentication middleware
    private def generate_authentication_middleware : String
      <<-CRYSTAL
      def call(context : HTTP::Server::Context)
        # Extract authentication token
        token = extract_token(context)

        # Validate authentication
        unless authenticated?(token)
          return unauthorized_response(context)
        end

        # Set current user in context
        if user = get_user_from_token(token)
          context.set("current_user", user)
        end

        call_next(context)
      end

      private def extract_token(context : HTTP::Server::Context) : String?
        auth_header = context.request.headers["Authorization"]?
        return nil unless auth_header

        if auth_header.starts_with?("Bearer ")
          auth_header[7..]
        else
          nil
        end
      end

      private def authenticated?(token : String?) : Bool
        return false unless token
        # TODO: Implement token validation
        true
      end

      private def get_user_from_token(token : String) : User?
        # TODO: Implement user lookup from token
        nil
      end

      private def unauthorized_response(context : HTTP::Server::Context)
        context.response.status = HTTP::Status::UNAUTHORIZED
        context.response.content_type = "application/json"
        context.response.print({error: "Authentication required"}.to_json)
      end
      CRYSTAL
    end

    # Generate CORS middleware
    private def generate_cors_middleware : String
      <<-CRYSTAL
      def call(context : HTTP::Server::Context)
        # Set CORS headers
        set_cors_headers(context)

        # Handle preflight OPTIONS requests
        if context.request.method == "OPTIONS"
          context.response.status = HTTP::Status::OK
          return
        end

        call_next(context)
      end

      private def set_cors_headers(context : HTTP::Server::Context)
        headers = context.response.headers
        headers["Access-Control-Allow-Origin"] = "*"
        headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
        headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
        headers["Access-Control-Allow-Credentials"] = "true"
        headers["Access-Control-Max-Age"] = "86400"
      end
      CRYSTAL
    end

    # Generate rate limiting middleware
    private def generate_rate_limiting_middleware : String
      <<-CRYSTAL
      @rate_limits = {} of String => Array(Time)

      def call(context : HTTP::Server::Context)
        client_ip = get_client_ip(context)

        if rate_limited?(client_ip)
          return rate_limit_response(context)
        end

        record_request(client_ip)
        call_next(context)
      end

      private def get_client_ip(context : HTTP::Server::Context) : String
        forwarded = context.request.headers["X-Forwarded-For"]?
        return forwarded.split(",").first.strip if forwarded

        context.request.remote_address.try(&.address) || "unknown"
      end

      private def rate_limited?(client_ip : String) : Bool
        now = Time.utc
        window_start = now - 1.hour

        requests = @rate_limits[client_ip]? || [] of Time
        recent_requests = requests.select { |time| time > window_start }

        @rate_limits[client_ip] = recent_requests
        recent_requests.size >= 100
      end

      private def record_request(client_ip : String)
        @rate_limits[client_ip] ||= [] of Time
        @rate_limits[client_ip] << Time.utc
      end

      private def rate_limit_response(context : HTTP::Server::Context)
        context.response.status = HTTP::Status::TOO_MANY_REQUESTS
        context.response.content_type = "application/json"
        context.response.headers["Retry-After"] = "3600"
        context.response.print({error: "Rate limit exceeded"}.to_json)
      end
      CRYSTAL
    end

    # Generate custom middleware
    private def generate_custom_middleware : String
      <<-CRYSTAL
      def call(context : HTTP::Server::Context)
        # Pre-processing logic
        before_request(context)

        # Call the next handler in the chain
        call_next(context)

        # Post-processing logic
        after_response(context)
      end

      private def before_request(context : HTTP::Server::Context)
        # Add logic to execute before the request is processed
        log_request(context)
      end

      private def after_response(context : HTTP::Server::Context)
        # Add logic to execute after the response is generated
        log_response(context)
      end
      CRYSTAL
    end

    # Generate authorization, logging, and security middleware (simplified for brevity)
    private def generate_authorization_middleware : String
      generate_custom_middleware
    end

    private def generate_logging_middleware : String
      generate_custom_middleware
    end

    private def generate_security_middleware : String
      generate_custom_middleware
    end

    # Generate helper methods
    private def generate_helper_methods : String
      <<-CRYSTAL

      private def log_request(context : HTTP::Server::Context)
        Log.info { "#{self.class.name}: #{context.request.method} #{context.request.path}" }
      end

      private def log_response(context : HTTP::Server::Context)
        Log.info { "#{self.class.name}: Response #{context.response.status_code}" }
      end

      private def json_response(context : HTTP::Server::Context, data : Hash, status : HTTP::Status = HTTP::Status::OK)
        context.response.status = status
        context.response.content_type = "application/json"
        context.response.print(data.to_json)
      end
      CRYSTAL
    end

    # Generate test methods
    private def generate_test_methods : String
      case @middleware_type
      when "authentication"
        generate_auth_tests
      when "cors"
        generate_cors_tests
      when "rate_limiting"
        generate_rate_limit_tests
      else
        generate_custom_tests
      end
    end

    # Generate authentication tests
    private def generate_auth_tests : String
      <<-CRYSTAL
      it "allows requests with valid authentication" do
        context = create_test_context("GET", "/", headers: {"Authorization" => "Bearer valid_token"})
        middleware.call(context)
        context.response.status_code.should eq(200)
      end

      it "rejects requests without authentication" do
        context = create_test_context("GET", "/")
        middleware.call(context)
        context.response.status_code.should eq(401)
      end
      CRYSTAL
    end

    # Generate CORS tests
    private def generate_cors_tests : String
      <<-CRYSTAL
      it "sets CORS headers" do
        context = create_test_context("GET", "/")
        middleware.call(context)
        context.response.headers.should have_key("Access-Control-Allow-Origin")
      end

      it "handles OPTIONS preflight requests" do
        context = create_test_context("OPTIONS", "/")
        middleware.call(context)
        context.response.status_code.should eq(200)
      end
      CRYSTAL
    end

    # Generate rate limit tests
    private def generate_rate_limit_tests : String
      <<-CRYSTAL
      it "allows requests within rate limit" do
        context = create_test_context("GET", "/")
        middleware.call(context)
        context.response.status_code.should_not eq(429)
      end
      CRYSTAL
    end

    # Generate custom tests
    private def generate_custom_tests : String
      <<-CRYSTAL
      it "processes requests through the middleware chain" do
        context = create_test_context("GET", "/")
        middleware.call(context)
        # Add assertions
      end
      CRYSTAL
    end

    # Generate mock helpers
    private def generate_mock_helpers : String
      <<-CRYSTAL

      private def create_test_context(method : String, path : String, headers : Hash(String, String) = {} of String => String)
        io = IO::Memory.new
        request = HTTP::Request.new(method, path, headers)
        response = HTTP::Server::Response.new(io)
        HTTP::Server::Context.new(request, response)
      end
      CRYSTAL
    end

    # Override success message to include middleware-specific information
    def success_message : String
      base_message = super
      "#{base_message} of type '#{@middleware_type}'"
    end

    # Override to show middleware-specific next steps
    def post_generation_tasks : Nil
      super
      show_middleware_usage_info
    end

    # Show middleware usage information
    private def show_middleware_usage_info
      puts
      puts "🛠️  Middleware Usage:".colorize(:yellow).bold
      puts "  1. Add to your application handlers:"
      puts "     MyApp.start ["
      puts "       #{class_name}.new,"
      puts "       # ... other handlers"
      puts "     ]"
      puts
      puts "  2. Middleware type: #{@middleware_type.capitalize}"

      middleware_type_info = config.get_hash("middleware_types.#{@middleware_type}")
      unless middleware_type_info.empty?
        description = config.get("middleware_types.#{@middleware_type}.description")
        puts "     #{description}" if description
      end

      puts
      puts "📚 Learn more: https://azutopia.gitbook.io/azu/middleware".colorize(:cyan)
    end
  end
end
