# Middleware Generator

The Middleware Generator creates middleware components that can be used to process HTTP requests and responses in your Azu application.

## Usage

```bash
azu generate middleware MIDDLEWARE_NAME [OPTIONS]
```

## Description

Middleware in Azu applications provides a way to process HTTP requests and responses before they reach your endpoints or after they leave them. Common uses include authentication, logging, CORS handling, and request/response transformation.

## Options

- `MIDDLEWARE_NAME` - Name of the middleware to generate (required)
- `-d, --description DESCRIPTION` - Description of the middleware
- `-t, --template TEMPLATE` - Template to use (default: basic)
- `-f, --force` - Overwrite existing files
- `-h, --help` - Show help message

## Examples

### Generate a basic middleware

```bash
azu generate middleware AuthMiddleware
```

This creates:

- `src/middleware/auth_middleware.cr` - The middleware class
- `spec/middleware/auth_middleware_spec.cr` - Test file

### Generate middleware with description

```bash
azu generate middleware CorsMiddleware --description "Handles CORS headers for cross-origin requests"
```

### Generate specific middleware types

```bash
azu generate middleware LoggingMiddleware --template logging
azu generate middleware RateLimitMiddleware --template rate_limit
```

## Generated Files

### Middleware Class (`src/middleware/MIDDLEWARE_NAME.cr`)

```crystal
# <%= @description || @name.underscore.humanize %> middleware
class <%= @name %>Middleware
  include Azu::Middleware

  def initialize
  end

  def call(context : Azu::Context) : Azu::Context
    # Process the request before it reaches the endpoint
    # You can modify the context here

    # Call the next middleware or endpoint
    context = call_next(context)

    # Process the response after it leaves the endpoint
    # You can modify the response here

    context
  end
end
```

### Test File (`spec/middleware/MIDDLEWARE_NAME_spec.cr`)

```crystal
require "../spec_helper"

describe <%= @name %>Middleware do
  describe "#call" do
    it "processes the request and response" do
      middleware = <%= @name %>Middleware.new
      context = Azu::Context.new

      result = middleware.call(context)

      result.should be_a(Azu::Context)
    end
  end
end
```

## Middleware Patterns

### Basic Middleware Pattern

```crystal
class LoggingMiddleware
  include Azu::Middleware

  def call(context : Azu::Context) : Azu::Context
    start_time = Time.utc

    # Process request
    context = call_next(context)

    # Log response
    duration = Time.utc - start_time
    Log.info { "Request processed in #{duration.total_milliseconds}ms" }

    context
  end
end
```

### Authentication Middleware

```crystal
class AuthMiddleware
  include Azu::Middleware

  def call(context : Azu::Context) : Azu::Context
    token = context.request.headers["Authorization"]?

    unless token && valid_token?(token)
      context.response.status_code = 401
      context.response.content_type = "application/json"
      context.response.print({error: "Unauthorized"}.to_json)
      return context
    end

    call_next(context)
  end

  private def valid_token?(token : String) : Bool
    # Token validation logic
    token.starts_with?("Bearer ")
  end
end
```

### CORS Middleware

```crystal
class CorsMiddleware
  include Azu::Middleware

  def initialize(@allowed_origins : Array(String) = ["*"])
  end

  def call(context : Azu::Context) : Azu::Context
    origin = context.request.headers["Origin"]?

    if origin && @allowed_origins.includes?("*") || @allowed_origins.includes?(origin)
      context.response.headers["Access-Control-Allow-Origin"] = origin
    end

    context.response.headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE, OPTIONS"
    context.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"

    if context.request.method == "OPTIONS"
      context.response.status_code = 200
      return context
    end

    call_next(context)
  end
end
```

### Rate Limiting Middleware

```crystal
class RateLimitMiddleware
  include Azu::Middleware

  def initialize(@requests_per_minute : Int32 = 100)
    @requests = {} of String => Array(Time)
  end

  def call(context : Azu::Context) : Azu::Context
    client_ip = context.request.remote_address.try(&.address) || "unknown"

    if rate_limited?(client_ip)
      context.response.status_code = 429
      context.response.content_type = "application/json"
      context.response.print({error: "Rate limit exceeded"}.to_json)
      return context
    end

    record_request(client_ip)
    call_next(context)
  end

  private def rate_limited?(client_ip : String) : Bool
    requests = @requests[client_ip]? || [] of Time
    requests.select { |time| time > 1.minute.ago }.size >= @requests_per_minute
  end

  private def record_request(client_ip : String)
    @requests[client_ip] ||= [] of Time
    @requests[client_ip] << Time.utc
  end
end
```

## Using Middleware

### Global Middleware

Register middleware globally in your application:

```crystal
class Application < Azu::Application
  middleware LoggingMiddleware.new
  middleware CorsMiddleware.new
  middleware AuthMiddleware.new

  # Your routes here
end
```

### Route-Specific Middleware

Apply middleware to specific routes:

```crystal
class Application < Azu::Application
  # Public routes
  get "/", WelcomeController, :index
  get "/login", AuthController, :login

  # Protected routes
  group middleware: [AuthMiddleware.new] do
    get "/dashboard", DashboardController, :index
    get "/profile", ProfileController, :show
  end
end
```

### Conditional Middleware

Apply middleware conditionally:

```crystal
class Application < Azu::Application
  middleware LoggingMiddleware.new

  # Only apply auth middleware in production
  if ENV["ENV"]? == "production"
    middleware RateLimitMiddleware.new
  end
end
```

## Best Practices

### 1. Keep Middleware Focused

Each middleware should have a single responsibility:

```crystal
# Good: Focused on logging
class LoggingMiddleware
  def call(context : Azu::Context) : Azu::Context
    # Only handle logging
  end
end

# Good: Focused on authentication
class AuthMiddleware
  def call(context : Azu::Context) : Azu::Context
    # Only handle authentication
  end
end
```

### 2. Handle Errors Gracefully

```crystal
class ErrorHandlingMiddleware
  include Azu::Middleware

  def call(context : Azu::Context) : Azu::Context
    call_next(context)
  rescue ex : Exception
    Log.error { "Unhandled error: #{ex.message}" }

    context.response.status_code = 500
    context.response.content_type = "application/json"
    context.response.print({error: "Internal server error"}.to_json)

    context
  end
end
```

### 3. Use Configuration

Make middleware configurable:

```crystal
class ConfigurableMiddleware
  include Azu::Middleware

  def initialize(@config : Hash(String, String))
  end

  def call(context : Azu::Context) : Azu::Context
    # Use configuration
    context
  end
end

# Usage
middleware ConfigurableMiddleware.new({
  "timeout" => "30s",
  "retries" => "3"
})
```

### 4. Performance Considerations

```crystal
class PerformanceMiddleware
  include Azu::Middleware

  def call(context : Azu::Context) : Azu::Context
    # Avoid expensive operations in middleware
    # Use caching when appropriate
    # Keep middleware lightweight

    call_next(context)
  end
end
```

## Testing Middleware

### Unit Testing

```crystal
describe LoggingMiddleware do
  describe "#call" do
    it "logs request information" do
      middleware = LoggingMiddleware.new
      context = Azu::Context.new

      # Mock logging
      Log.should_receive(:info).with(/Request processed/)

      middleware.call(context)
    end
  end
end
```

### Integration Testing

```crystal
describe "Middleware integration" do
  it "applies middleware in correct order" do
    app = Application.new

    # Test that middleware is applied correctly
    response = app.handle_request("GET", "/")

    response.headers["X-Processed-By"].should eq("LoggingMiddleware")
  end
end
```

## Common Middleware Types

### 1. Authentication & Authorization

```crystal
class JwtAuthMiddleware
  include Azu::Middleware

  def call(context : Azu::Context) : Azu::Context
    token = extract_token(context.request)

    if token && valid_jwt?(token)
      context.current_user = decode_user(token)
      call_next(context)
    else
      unauthorized_response(context)
    end
  end
end
```

### 2. Request/Response Transformation

```crystal
class JsonMiddleware
  include Azu::Middleware

  def call(context : Azu::Context) : Azu::Context
    # Parse JSON request body
    if context.request.content_type.try(&.includes?("application/json"))
      body = context.request.body.try(&.gets_to_end)
      context.params = JSON.parse(body).as_h if body
    end

    call_next(context)
  end
end
```

### 3. Monitoring & Metrics

```crystal
class MetricsMiddleware
  include Azu::Middleware

  def call(context : Azu::Context) : Azu::Context
    start_time = Time.utc

    context = call_next(context)

    duration = Time.utc - start_time
    record_metric(context.request.path, context.response.status_code, duration)

    context
  end
end
```

## Related Commands

- `azu generate endpoint` - Generate API endpoints
- `azu generate service` - Generate business logic services
- `azu generate contract` - Generate validation contracts
- `azu generate model` - Generate data models

## Templates

The middleware generator supports different templates:

- `basic` - Simple middleware with basic structure
- `auth` - Authentication middleware template
- `cors` - CORS handling middleware
- `logging` - Request/response logging middleware
- `rate_limit` - Rate limiting middleware

To use a specific template:

```bash
azu generate middleware ApiKeyAuth --template auth
```
