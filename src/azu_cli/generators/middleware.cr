require "teeplate"

module AzuCLI
  module Generate
    # Middleware generator that creates HTTP::Handler classes
    class Middleware < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/middleware"
      OUTPUT_DIR = "./src/middleware"

      property name : String
      property middleware_type : String
      property skip_paths : Array(String)
      property context_vars : Hash(String, String)
      property snake_case_name : String

      def initialize(@name : String, @middleware_type : String = "authentication", @skip_paths : Array(String) = [] of String, @context_vars : Hash(String, String) = {} of String => String)
        @snake_case_name = @name.underscore
      end

      # Convert name to middleware class name
      def middleware_class_name : String
        @name.camelcase + "Middleware"
      end

      # Get default skip paths based on middleware type
      def default_skip_paths : Array(String)
        case @middleware_type.downcase
        when "authentication"
          ["/", "/login", "/register", "/health", "/assets"]
        when "authorization"
          ["/", "/health", "/assets"]
        when "logging"
          ["/health", "/assets"]
        when "cors"
          [] of String
        when "rate_limiting"
          ["/health"]
        else
          ["/health", "/assets"]
        end
      end

      # Get skip paths (use provided or defaults)
      def get_skip_paths : Array(String)
        @skip_paths.empty? ? default_skip_paths : @skip_paths
      end

      # Get context variables string
      def context_vars_string : String
        @context_vars.map { |key, type| "#{key} : #{crystal_type(type)}" }.join(", ")
      end

      # Get Crystal type for context variable
      def crystal_type(var_type : String) : String
        case var_type.downcase
        when "string", "text"
          "String"
        when "int32", "integer"
          "Int32"
        when "int64"
          "Int64"
        when "float32"
          "Float32"
        when "float64", "float"
          "Float64"
        when "bool", "boolean"
          "Bool"
        when "time", "datetime"
          "Time"
        when "date"
          "Date"
        when "user", "model"
          "User"
        when "array"
          "Array(String)"
        when "hash"
          "Hash(String, String)"
        when "json"
          "JSON::Any"
        else
          "String"
        end
      end

      # Get middleware type specific logic
      def middleware_logic : String
        case @middleware_type.downcase
        when "authentication"
          authentication_logic
        when "authorization"
          authorization_logic
        when "logging"
          logging_logic
        when "cors"
          cors_logic
        when "rate_limiting"
          rate_limiting_logic
        else
          custom_logic
        end
      end

      # Authentication middleware logic
      private def authentication_logic : String
        <<-AUTH
            # Check for authentication token
            token = extract_token(context.request)

            unless token && valid_token?(token)
              context.response.status = HTTP::Status::UNAUTHORIZED
              context.response.content_type = "application/json"
              context.response.print({
                "error" => "Authentication required",
                "message" => "Please provide a valid authentication token"
              }.to_json)
              return
            end

            # Add user information to context
            if user = get_user_from_token(token)
              context.set("current_user", user)
            end
        AUTH
      end

      # Authorization middleware logic
      private def authorization_logic : String
        <<-AUTHZ
            # Check if user has required permissions
            user = context.get?("current_user")

            unless user && has_permission?(user, context.request.path, context.request.method)
              context.response.status = HTTP::Status::FORBIDDEN
              context.response.content_type = "application/json"
              context.response.print({
                "error" => "Access denied",
                "message" => "You don't have permission to access this resource"
              }.to_json)
              return
            end
        AUTHZ
      end

      # Logging middleware logic
      private def logging_logic : String
        <<-LOG
            # Log request details
            start_time = Time.monotonic
            Log.info { "Request: " + context.request.method + " " + context.request.path }

            call_next(context)

            # Log response details
            end_time = Time.monotonic
            duration = (end_time - start_time).total_milliseconds
            Log.info { "Response: " + context.response.status_code.to_s + " (" + duration.to_s + "ms)" }
        LOG
      end

      # CORS middleware logic
      private def cors_logic : String
        <<-CORS
            # Handle preflight requests
            if context.request.method == "OPTIONS"
              context.response.headers["Access-Control-Allow-Origin"] = "*"
              context.response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
              context.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
              context.response.status = HTTP::Status::OK
              return
            end

            # Add CORS headers to all responses
            context.response.headers["Access-Control-Allow-Origin"] = "*"
        CORS
      end

      # Rate limiting middleware logic
      private def rate_limiting_logic : String
        <<-RATE
            # Check rate limits
            client_ip = context.request.remote_address.try(&.address) || "unknown"

            unless within_rate_limit?(client_ip)
              context.response.status = HTTP::Status::TOO_MANY_REQUESTS
              context.response.content_type = "application/json"
              context.response.print({
                "error" => "Rate limit exceeded",
                "message" => "Too many requests, please try again later"
              }.to_json)
              return
            end
        RATE
      end

      # Custom middleware logic
      private def custom_logic : String
        <<-CUSTOM
            # TODO: Implement custom middleware logic
            # Example:
            # Log.info { "Processing request: " + context.request.method + " " + context.request.path }
            #
            # # Your custom logic here
            #
            # Log.info { "Request processed successfully" }
        CUSTOM
      end

      # Get private methods based on middleware type
      def private_methods : String
        case @middleware_type.downcase
        when "authentication"
          authentication_private_methods
        when "authorization"
          authorization_private_methods
        when "logging"
          logging_private_methods
        when "cors"
          cors_private_methods
        when "rate_limiting"
          rate_limiting_private_methods
        else
          custom_private_methods
        end
      end

      # Authentication private methods
      private def authentication_private_methods : String
        <<-AUTH_METHODS
          private def public_path?(path : String) : Bool
            public_paths = #{get_skip_paths.inspect}
            public_paths.any? { |public_path| path.starts_with?(public_path) }
          end

          private def extract_token(request : HTTP::Request) : String?
            # Try Authorization header first
            if auth_header = request.headers["Authorization"]?
              if auth_header.starts_with?("Bearer ")
                return auth_header[7..-1]
              end
            end

            # Try query parameter
            request.query_params["token"]?
          end

          private def valid_token?(token : String) : Bool
            # Implement your token validation logic
            # This could check JWT, database tokens, etc.
            token.size > 10 # Simple validation for demo
          end

          private def get_user_from_token(token : String) : User?
            # Implement user lookup from token
            # This would typically decode JWT or query database
            User.first? # Simple demo
          end
        AUTH_METHODS
      end

      # Authorization private methods
      private def authorization_private_methods : String
        <<-AUTHZ_METHODS
          private def public_path?(path : String) : Bool
            public_paths = #{get_skip_paths.inspect}
            public_paths.any? { |public_path| path.starts_with?(public_path) }
          end

          private def has_permission?(user : User, path : String, method : String) : Bool
            # Implement your permission checking logic
            # This could check user roles, permissions, etc.
            true # Simple demo - allow all authenticated users
          end
        AUTHZ_METHODS
      end

      # Logging private methods
      private def logging_private_methods : String
        <<-LOG_METHODS
          private def public_path?(path : String) : Bool
            public_paths = #{get_skip_paths.inspect}
            public_paths.any? { |public_path| path.starts_with?(public_path) }
          end

          private def should_log?(path : String) : Bool
            # Skip logging for certain paths
            skip_paths = #{get_skip_paths.inspect}
            !skip_paths.any? { |skip_path| path.starts_with?(skip_path) }
          end
        LOG_METHODS
      end

      # CORS private methods
      private def cors_private_methods : String
        <<-CORS_METHODS
          private def public_path?(path : String) : Bool
            public_paths = #{get_skip_paths.inspect}
            public_paths.any? { |public_path| path.starts_with?(public_path) }
          end

          private def allowed_origin?(origin : String) : Bool
            # Implement your CORS origin validation
            # This could check against a whitelist, etc.
            true # Simple demo - allow all origins
          end
        CORS_METHODS
      end

      # Rate limiting private methods
      private def rate_limiting_private_methods : String
        <<-RATE_METHODS
          private def public_path?(path : String) : Bool
            public_paths = #{get_skip_paths.inspect}
            public_paths.any? { |public_path| path.starts_with?(public_path) }
          end

          private def within_rate_limit?(client_ip : String) : Bool
            # Implement your rate limiting logic
            # This could use Redis, in-memory cache, etc.
            true # Simple demo - no rate limiting
          end
        RATE_METHODS
      end

      # Custom private methods
      private def custom_private_methods : String
        <<-CUSTOM_METHODS
          private def public_path?(path : String) : Bool
            public_paths = #{get_skip_paths.inspect}
            public_paths.any? { |public_path| path.starts_with?(public_path) }
          end

          private def custom_validation?(context : HTTP::Server::Context) : Bool
            # TODO: Implement custom validation logic
            true # Simple demo
          end
        CUSTOM_METHODS
      end

      # Check if middleware has context variables
      def has_context_vars? : Bool
        !@context_vars.empty?
      end
    end
  end
end
