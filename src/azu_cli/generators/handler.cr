require "./base"

module AzuCLI
  module Generator
    class Handler < Base
      getter handler_type : String
      getter with_auth : Bool

      def initialize(@name : String, @project_name : String, @handler_type = "custom", @with_auth = false, @force = false, @skip_tests = false)
        super(name, project_name, force, skip_tests)
        validate_name!
      end

      def generate!
        create_directories
        generate_handler
        generate_tests unless skip_tests

        puts "  🛠️  Generated #{class_name}Handler".colorize(:green)
        show_handler_usage_info
      end

      private def create_directories
        ensure_directory("src/handlers")
        ensure_directory("spec/handlers") unless skip_tests
      end

      private def generate_handler
        template_variables = {
          "handler_methods" => generate_handler_methods,
          "auth_methods"    => generate_auth_methods,
          "helper_methods"  => generate_helper_methods,
        }

        copy_template(
          "generators/handler/handler.cr.ecr",
          "src/handlers/#{snake_case_name}_handler.cr",
          template_variables
        )
      end

      private def generate_tests
        template_variables = {
          "test_methods"     => generate_test_methods,
          "mock_helpers"     => generate_mock_helpers,
          "auth_tests"       => generate_auth_tests,
        }

        copy_template(
          "generators/handler/handler_spec.cr.ecr",
          "spec/handlers/#{snake_case_name}_handler_spec.cr",
          template_variables
        )
      end

      private def generate_handler_methods : String
        case handler_type.downcase
        when "auth", "authentication"
          generate_auth_handler
        when "cors"
          generate_cors_handler
        when "rate_limit", "throttle"
          generate_rate_limit_handler
        when "logging"
          generate_logging_handler
        when "security"
          generate_security_handler
        else
          generate_custom_handler
        end
      end

      private def generate_auth_handler : String
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
          # Extract from Authorization header
          auth_header = context.request.headers["Authorization"]?
          return nil unless auth_header

          # Bearer token format
          if auth_header.starts_with?("Bearer ")
            auth_header[7..]
          else
            nil
          end
        end

        private def authenticated?(token : String?) : Bool
          return false unless token

          # TODO: Implement token validation
          # Example: JWT.decode(token) or User.find_by_token(token)
          true
        end

        private def get_user_from_token(token : String) : User?
          # TODO: Implement user lookup from token
          # User.find_by_auth_token(token)
          nil
        end

        private def unauthorized_response(context : HTTP::Server::Context)
          context.response.status = HTTP::Status::UNAUTHORIZED
          context.response.content_type = "application/json"
          context.response.print({error: "Authentication required"}.to_json)
        end
        CRYSTAL
      end

      private def generate_cors_handler : String
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

          # Allow specific origins or all origins
          headers["Access-Control-Allow-Origin"] = allowed_origins
          headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
          headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, X-Requested-With"
          headers["Access-Control-Allow-Credentials"] = "true"
          headers["Access-Control-Max-Age"] = "86400" # 24 hours
        end

        private def allowed_origins : String
          # TODO: Configure allowed origins
          # In production, specify exact origins: "https://yourdomain.com"
          "*"
        end
        CRYSTAL
      end

      private def generate_rate_limit_handler : String
        <<-CRYSTAL
        @rate_limits = {} of String => Array(Time)

        def call(context : HTTP::Server::Context)
          client_ip = get_client_ip(context)

          # Check rate limit
          if rate_limited?(client_ip)
            return rate_limit_response(context)
          end

          # Record request
          record_request(client_ip)

          call_next(context)
        end

        private def get_client_ip(context : HTTP::Server::Context) : String
          # Check X-Forwarded-For header first (for proxies)
          forwarded = context.request.headers["X-Forwarded-For"]?
          return forwarded.split(",").first.strip if forwarded

          # Fall back to remote address
          context.request.remote_address.try(&.address) || "unknown"
        end

        private def rate_limited?(client_ip : String) : Bool
          now = Time.utc
          window_start = now - 1.hour

          # Get recent requests for this IP
          requests = @rate_limits[client_ip]? || [] of Time
          recent_requests = requests.select { |time| time > window_start }

          # Update stored requests
          @rate_limits[client_ip] = recent_requests

          # Check if limit exceeded (100 requests per hour)
          recent_requests.size >= 100
        end

        private def record_request(client_ip : String)
          @rate_limits[client_ip] ||= [] of Time
          @rate_limits[client_ip] << Time.utc
        end

        private def rate_limit_response(context : HTTP::Server::Context)
          context.response.status = HTTP::Status::TOO_MANY_REQUESTS
          context.response.content_type = "application/json"
          context.response.headers["Retry-After"] = "3600" # 1 hour
          context.response.print({
            error: "Rate limit exceeded",
            message: "Too many requests. Please try again later."
          }.to_json)
        end
        CRYSTAL
      end

      private def generate_logging_handler : String
        <<-CRYSTAL
        def call(context : HTTP::Server::Context)
          start_time = Time.utc
          request_id = UUID.random.to_s

          # Log request start
          log_request_start(context, request_id)

          # Set request ID in context
          context.set("request_id", request_id)

          # Process request
          call_next(context)

          # Log request completion
          duration = Time.utc - start_time
          log_request_end(context, request_id, duration)
        rescue ex : Exception
          # Log error
          log_error(context, request_id, ex)
          raise ex
        end

        private def log_request_start(context : HTTP::Server::Context, request_id : String)
          Log.info {
            {
              event: "request_start",
              request_id: request_id,
              method: context.request.method,
              path: context.request.path,
              user_agent: context.request.headers["User-Agent"]?,
              ip: context.request.remote_address.try(&.address)
            }.to_json
          }
        end

        private def log_request_end(context : HTTP::Server::Context, request_id : String, duration : Time::Span)
          Log.info {
            {
              event: "request_end",
              request_id: request_id,
              status: context.response.status_code,
              duration_ms: duration.total_milliseconds.round(2),
              content_length: context.response.headers["Content-Length"]?
            }.to_json
          }
        end

        private def log_error(context : HTTP::Server::Context, request_id : String, error : Exception)
          Log.error(exception: error) {
            {
              event: "request_error",
              request_id: request_id,
              error_class: error.class.name,
              error_message: error.message
            }.to_json
          }
        end
        CRYSTAL
      end

      private def generate_security_handler : String
        <<-CRYSTAL
        def call(context : HTTP::Server::Context)
          # Set security headers
          set_security_headers(context)

          # Validate request
          unless valid_request?(context)
            return security_error_response(context)
          end

          call_next(context)
        end

        private def set_security_headers(context : HTTP::Server::Context)
          headers = context.response.headers

          # Prevent clickjacking
          headers["X-Frame-Options"] = "DENY"

          # Prevent MIME type sniffing
          headers["X-Content-Type-Options"] = "nosniff"

          # Enable XSS protection
          headers["X-XSS-Protection"] = "1; mode=block"

          # Force HTTPS (if applicable)
          # headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

          # Content Security Policy
          headers["Content-Security-Policy"] = content_security_policy
        end

        private def content_security_policy : String
          # TODO: Customize CSP for your application
          "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'"
        end

        private def valid_request?(context : HTTP::Server::Context) : Bool
          # Basic request validation
          return false if context.request.path.includes?("..")  # Path traversal
          return false if context.request.path.size > 2000     # Extremely long paths

          # TODO: Add more security validations
          true
        end

        private def security_error_response(context : HTTP::Server::Context)
          context.response.status = HTTP::Status::BAD_REQUEST
          context.response.content_type = "application/json"
          context.response.print({error: "Invalid request"}.to_json)
        end
        CRYSTAL
      end

      private def generate_custom_handler : String
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
          # Examples:
          # - Request validation
          # - Header processing
          # - Authentication checks
          # - Logging

          log_request(context)
        end

        private def after_response(context : HTTP::Server::Context)
          # Add logic to execute after the response is generated
          # Examples:
          # - Response logging
          # - Metrics collection
          # - Cleanup tasks
          # - Header modification

          log_response(context)
        end
        CRYSTAL
      end

      private def generate_auth_methods : String
        return "" unless with_auth

        <<-CRYSTAL

        # Authentication helpers
        private def current_user(context : HTTP::Server::Context) : User?
          context.get?("current_user").try(&.as(User))
        end

        private def authenticated?(context : HTTP::Server::Context) : Bool
          !current_user(context).nil?
        end

        private def require_authentication(context : HTTP::Server::Context) : Bool
          return true if authenticated?(context)

          unauthorized_response(context)
          false
        end
        CRYSTAL
      end

      private def generate_helper_methods : String
        <<-CRYSTAL

        # Helper methods
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

        private def error_response(context : HTTP::Server::Context, message : String, status : HTTP::Status = HTTP::Status::BAD_REQUEST)
          json_response(context, {error: message}, status)
        end
        CRYSTAL
      end

      private def generate_test_methods : String
        case handler_type.downcase
        when "auth", "authentication"
          generate_auth_tests
        when "cors"
          generate_cors_tests
        when "rate_limit", "throttle"
          generate_rate_limit_tests
        when "logging"
          generate_logging_tests
        when "security"
          generate_security_tests
        else
          generate_custom_tests
        end
      end

      private def generate_auth_tests : String
        <<-CRYSTAL
        it "allows requests with valid authentication" do
          context = create_test_context("GET", "/", headers: {"Authorization" => "Bearer valid_token"})
          handler.call(context)

          context.response.status_code.should eq(200)
        end

        it "rejects requests without authentication" do
          context = create_test_context("GET", "/")
          handler.call(context)

          context.response.status_code.should eq(401)
        end

        it "rejects requests with invalid tokens" do
          context = create_test_context("GET", "/", headers: {"Authorization" => "Bearer invalid_token"})
          handler.call(context)

          context.response.status_code.should eq(401)
        end
        CRYSTAL
      end

      private def generate_cors_tests : String
        <<-CRYSTAL
        it "sets CORS headers" do
          context = create_test_context("GET", "/")
          handler.call(context)

          context.response.headers.should have_key("Access-Control-Allow-Origin")
          context.response.headers.should have_key("Access-Control-Allow-Methods")
        end

        it "handles OPTIONS preflight requests" do
          context = create_test_context("OPTIONS", "/")
          handler.call(context)

          context.response.status_code.should eq(200)
        end
        CRYSTAL
      end

      private def generate_rate_limit_tests : String
        <<-CRYSTAL
        it "allows requests within rate limit" do
          context = create_test_context("GET", "/")
          handler.call(context)

          context.response.status_code.should_not eq(429)
        end

        it "blocks requests exceeding rate limit" do
          # Simulate multiple requests
          100.times do
            context = create_test_context("GET", "/")
            handler.call(context)
          end

          # The next request should be rate limited
          context = create_test_context("GET", "/")
          handler.call(context)
          context.response.status_code.should eq(429)
        end
        CRYSTAL
      end

      private def generate_logging_tests : String
        <<-CRYSTAL
        it "logs request start and end" do
          context = create_test_context("GET", "/")
          handler.call(context)

          # Test that appropriate log messages were created
          # You might want to use a mock logger here
        end

        it "logs errors" do
          context = create_test_context("GET", "/")

          # Simulate an error in the next handler
          handler.next = ->(ctx : HTTP::Server::Context) {
            raise "Test error"
          }

          expect { handler.call(context) }.to raise_error("Test error")
          # Test that error was logged
        end
        CRYSTAL
      end

      private def generate_security_tests : String
        <<-CRYSTAL
        it "sets security headers" do
          context = create_test_context("GET", "/")
          handler.call(context)

          context.response.headers.should have_key("X-Frame-Options")
          context.response.headers.should have_key("X-Content-Type-Options")
          context.response.headers.should have_key("X-XSS-Protection")
        end

        it "blocks path traversal attempts" do
          context = create_test_context("GET", "/../../etc/passwd")
          handler.call(context)

          context.response.status_code.should eq(400)
        end
        CRYSTAL
      end

      private def generate_custom_tests : String
        <<-CRYSTAL
        it "processes requests through the handler chain" do
          context = create_test_context("GET", "/")
          handler.call(context)

          # Add assertions specific to your handler logic
        end

        it "calls before_request and after_response methods" do
          context = create_test_context("GET", "/")
          handler.call(context)

          # Test that both lifecycle methods were called
        end
        CRYSTAL
      end

      private def generate_mock_helpers : String
        <<-CRYSTAL

        private def create_test_context(method : String, path : String, headers : Hash(String, String) = {} of String => String)
          # Create a mock HTTP context for testing
          io = IO::Memory.new
          request = HTTP::Request.new(method, path, headers)
          response = HTTP::Server::Response.new(io)
          HTTP::Server::Context.new(request, response)
        end
        CRYSTAL
      end

      private def show_handler_usage_info
        puts
        puts "🛠️  Handler Usage:".colorize(:yellow).bold
        puts "  1. Add to your application handlers:"
        puts "     MyApp.start ["
        puts "       #{class_name}Handler.new,"
        puts "       # ... other handlers"
        puts "     ]"
        puts
        puts "  2. Handler type: #{handler_type.capitalize}"
        case handler_type.downcase
        when "auth", "authentication"
          puts "     - Validates authentication tokens"
          puts "     - Sets current_user in context"
          puts "     - Returns 401 for unauthorized requests"
        when "cors"
          puts "     - Sets CORS headers for cross-origin requests"
          puts "     - Handles OPTIONS preflight requests"
        when "rate_limit", "throttle"
          puts "     - Implements rate limiting per IP address"
          puts "     - Returns 429 when limit exceeded"
        when "logging"
          puts "     - Logs request start/end with timing"
          puts "     - Includes request ID for tracing"
        when "security"
          puts "     - Sets security headers (XSS, clickjacking protection)"
          puts "     - Validates requests for security issues"
        else
          puts "     - Custom request/response processing"
          puts "     - Lifecycle hooks: before_request, after_response"
        end
        puts
        if with_auth
          puts "  3. Authentication features enabled:"
          puts "     - current_user(context) helper"
          puts "     - authenticated?(context) check"
          puts "     - require_authentication(context) method"
          puts
        end
        puts "💡 Handler Features:".colorize(:blue).bold
        puts "  - HTTP::Handler implementation"
        puts "  - Chain-of-responsibility pattern"
        puts "  - Request/response lifecycle hooks"
        puts "  - Error handling and logging"
        puts
        puts "📚 Learn more: https://azutopia.gitbook.io/azu/handlers".colorize(:cyan)
      end
    end
  end
end
