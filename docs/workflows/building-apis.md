# Building APIs

This guide covers building RESTful APIs with Azu, including endpoint design, authentication, validation, and best practices.

## Overview

Azu provides a robust foundation for building APIs with Crystal. You can create both JSON APIs and GraphQL APIs, with built-in support for authentication, validation, serialization, and testing.

## Quick Start

### 1. Create an API Project

```bash
azu new my-api --template api
cd my-api
```

### 2. Generate Your First Endpoint

```bash
azu generate endpoint Users::Index
```

### 3. Start the Development Server

```bash
azu serve
```

Your API is now running at `http://localhost:3000`!

## API Design Principles

### RESTful Design

Follow REST principles for consistent API design:

```crystal
# Resource-based URLs
GET    /users          # List users
GET    /users/:id      # Get specific user
POST   /users          # Create user
PUT    /users/:id      # Update user
DELETE /users/:id      # Delete user

# Nested resources
GET    /users/:id/posts     # Get user's posts
POST   /users/:id/posts     # Create post for user
```

### HTTP Status Codes

Use appropriate HTTP status codes:

```crystal
# Success responses
200 OK              # Successful GET, PUT, PATCH
201 Created         # Successful POST
204 No Content      # Successful DELETE

# Client errors
400 Bad Request     # Invalid request
401 Unauthorized    # Authentication required
403 Forbidden       # Authorization failed
404 Not Found       # Resource not found
422 Unprocessable   # Validation errors

# Server errors
500 Internal Error  # Server error
```

## Creating Endpoints

### Basic Endpoint Structure

```crystal
class Users::IndexEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    @users = User.all

    render "endpoints/users/index.json"
  end
end
```

### Endpoint with Parameters

```crystal
class Users::ShowEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    user_id = context.params["id"]
    @user = User.find(user_id)

    unless @user
      return Azu::Response.new(
        status: 404,
        body: {error: "User not found"}.to_json
      )
    end

    render "endpoints/users/show.json"
  end
end
```

### Creating Resources

```crystal
class Users::CreateEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    contract = UserContract.new(context.params.to_h)

    unless contract.valid?
      return Azu::Response.new(
        status: 422,
        body: {errors: contract.errors}.to_json
      )
    end

    @user = User.create(contract.valid_data)

    render "endpoints/users/create.json", status: 201
  end
end
```

### Updating Resources

```crystal
class Users::UpdateEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    user_id = context.params["id"]
    @user = User.find(user_id)

    unless @user
      return Azu::Response.new(
        status: 404,
        body: {error: "User not found"}.to_json
      )
    end

    contract = UserContract.new(context.params.to_h)

    unless contract.valid?
      return Azu::Response.new(
        status: 422,
        body: {errors: contract.errors}.to_json
      )
    end

    @user.update(contract.valid_data)

    render "endpoints/users/update.json"
  end
end
```

### Deleting Resources

```crystal
class Users::DestroyEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    user_id = context.params["id"]
    @user = User.find(user_id)

    unless @user
      return Azu::Response.new(
        status: 404,
        body: {error: "User not found"}.to_json
      )
    end

    @user.delete

    Azu::Response.new(status: 204)
  end
end
```

## JSON Templates

### Basic JSON Response

```json
{
  "id": 1,
  "name": "John Doe",
  "email": "john@example.com",
  "created_at": "2024-01-15T10:30:00Z"
}
```

### Collection Response

```json
{
  "users": [
    {
      "id": 1,
      "name": "John Doe",
      "email": "john@example.com"
    },
    {
      "id": 2,
      "name": "Jane Smith",
      "email": "jane@example.com"
    }
  ],
  "meta": {
    "total": 2,
    "page": 1,
    "per_page": 20
  }
}
```

### Error Response

```json
{
  "error": "User not found",
  "code": "USER_NOT_FOUND",
  "details": {
    "user_id": "123"
  }
}
```

### Validation Error Response

```json
{
  "errors": {
    "email": ["is required", "must be a valid email"],
    "name": ["must be at least 2 characters"]
  }
}
```

## Authentication & Authorization

### Basic Authentication

```crystal
class AuthenticatedEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    token = context.request.headers["Authorization"]?

    unless token && valid_token?(token)
      return Azu::Response.new(
        status: 401,
        body: {error: "Unauthorized"}.to_json
      )
    end

    @current_user = get_user_from_token(token)
    call_next(context)
  end

  private def valid_token?(token : String) : Bool
    token.starts_with?("Bearer ")
  end

  private def get_user_from_token(token : String) : User?
    # Token validation logic
    User.find_by(token: token)
  end
end
```

### JWT Authentication

```crystal
class JwtAuthEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    token = extract_token(context.request)

    unless token && valid_jwt?(token)
      return Azu::Response.new(
        status: 401,
        body: {error: "Invalid token"}.to_json
      )
    end

    @current_user = decode_user(token)
    call_next(context)
  end

  private def extract_token(request : HTTP::Request) : String?
    auth_header = request.headers["Authorization"]?
    return nil unless auth_header

    if auth_header.starts_with?("Bearer ")
      auth_header[7..-1]
    end
  end

  private def valid_jwt?(token : String) : Bool
    # JWT validation logic
    JWT.decode(token, ENV["JWT_SECRET"])
    true
  rescue JWT::Error
    false
  end
end
```

### Role-Based Authorization

```crystal
class AdminOnlyEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    user = context.current_user

    unless user && user.admin?
      return Azu::Response.new(
        status: 403,
        body: {error: "Admin access required"}.to_json
      )
    end

    call_next(context)
  end
end
```

## Validation

### Using Contracts

```crystal
class UserContract < Azu::Contract
  field :name, String, required: true, min_length: 2, max_length: 50
  field :email, String, required: true, format: /^[^@]+@[^@]+\.[^@]+$/
  field :age, Int32, min: 18, max: 120
end

class Users::CreateEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    contract = UserContract.new(context.params.to_h)

    unless contract.valid?
      return Azu::Response.new(
        status: 422,
        body: {errors: contract.errors}.to_json
      )
    end

    @user = User.create(contract.valid_data)
    render "endpoints/users/create.json", status: 201
  end
end
```

### Custom Validations

```crystal
class UserContract < Azu::Contract
  field :email, String, required: true

  def validate_unique_email
    return unless email

    if User.find_by(email: email)
      errors.add(:email, "is already taken")
    end
  end
end
```

## Pagination

### Basic Pagination

```crystal
class Users::IndexEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    page = context.params["page"]?.try(&.to_i) || 1
    per_page = context.params["per_page"]?.try(&.to_i) || 20

    @users = User.all.offset((page - 1) * per_page).limit(per_page)
    @total_count = User.count
    @current_page = page
    @per_page = per_page

    render "endpoints/users/index.json"
  end
end
```

### Cursor-Based Pagination

```crystal
class Posts::IndexEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    cursor = context.params["cursor"]?
    limit = context.params["limit"]?.try(&.to_i) || 20

    query = Post.all.order(created_at: :desc)

    if cursor
      query = query.where("created_at < ?", cursor)
    end

    @posts = query.limit(limit + 1)
    @has_next = @posts.size > limit

    if @has_next
      @posts = @posts[0...limit]
      @next_cursor = @posts.last.created_at.to_s
    end

    render "endpoints/posts/index.json"
  end
end
```

## Filtering & Sorting

### Query Parameters

```crystal
class Users::IndexEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    @users = User.all

    # Filter by status
    if status = context.params["status"]?
      @users = @users.where(status: status)
    end

    # Filter by role
    if role = context.params["role"]?
      @users = @users.where(role: role)
    end

    # Search by name
    if search = context.params["search"]?
      @users = @users.where("name ILIKE ?", "%#{search}%")
    end

    # Sort
    sort_by = context.params["sort_by"]? || "created_at"
    sort_order = context.params["sort_order"]? || "desc"

    @users = @users.order("#{sort_by} #{sort_order}")

    render "endpoints/users/index.json"
  end
end
```

## Error Handling

### Global Error Handler

```crystal
class ErrorHandlingMiddleware
  include Azu::Middleware

  def call(context : Azu::Context) : Azu::Context
    call_next(context)
  rescue ex : Exception
    Log.error { "Unhandled error: #{ex.message}" }

    context.response.status_code = 500
    context.response.content_type = "application/json"
    context.response.print({
      error: "Internal server error",
      code: "INTERNAL_ERROR"
    }.to_json)

    context
  end
end
```

### Custom Error Classes

```crystal
class ApiError < Exception
  getter status_code : Int32
  getter code : String

  def initialize(@message : String, @status_code : Int32 = 500, @code : String = "API_ERROR")
    super(@message)
  end
end

class NotFoundError < ApiError
  def initialize(message : String = "Resource not found")
    super(message, 404, "NOT_FOUND")
  end
end

class ValidationError < ApiError
  getter errors : Hash(String, Array(String))

  def initialize(@errors : Hash(String, Array(String)))
    super("Validation failed", 422, "VALIDATION_ERROR")
  end
end
```

## API Versioning

### URL Versioning

```crystal
class Application < Azu::Application
  # Version 1 API
  group "/api/v1" do
    get "/users", Users::V1::IndexEndpoint
    get "/users/:id", Users::V1::ShowEndpoint
  end

  # Version 2 API
  group "/api/v2" do
    get "/users", Users::V2::IndexEndpoint
    get "/users/:id", Users::V2::ShowEndpoint
  end
end
```

### Header Versioning

```crystal
class VersionedEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    version = context.request.headers["API-Version"]? || "v1"

    case version
    when "v1"
      handle_v1(context)
    when "v2"
      handle_v2(context)
    else
      Azu::Response.new(
        status: 400,
        body: {error: "Unsupported API version"}.to_json
      )
    end
  end
end
```

## Testing APIs

### Endpoint Testing

```crystal
describe Users::IndexEndpoint do
  it "returns all users" do
    user = User.create(name: "John Doe", email: "john@example.com")

    get "/users"

    response.status_code.should eq(200)
    response.body.should contain("John Doe")
  end

  it "handles pagination" do
    # Create multiple users
    25.times { |i| User.create(name: "User #{i}", email: "user#{i}@example.com") }

    get "/users?page=2&per_page=10"

    response.status_code.should eq(200)
    json = JSON.parse(response.body)
    json["meta"]["page"].should eq(2)
  end
end
```

### Authentication Testing

```crystal
describe AuthenticatedEndpoint do
  it "requires authentication" do
    get "/protected"

    response.status_code.should eq(401)
  end

  it "accepts valid token" do
    user = User.create(name: "John Doe", email: "john@example.com")
    token = generate_token(user)

    get "/protected", headers: {"Authorization" => "Bearer #{token}"}

    response.status_code.should eq(200)
  end
end
```

## API Documentation

### OpenAPI Specification

```yaml
openapi: 3.0.0
info:
  title: My API
  version: 1.0.0
  description: API for managing users and posts

paths:
  /users:
    get:
      summary: List users
      parameters:
        - name: page
          in: query
          schema:
            type: integer
            default: 1
        - name: per_page
          in: query
          schema:
            type: integer
            default: 20
      responses:
        "200":
          description: List of users
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/UserList"

    post:
      summary: Create user
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/UserCreate"
      responses:
        "201":
          description: User created
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/User"

components:
  schemas:
    User:
      type: object
      properties:
        id:
          type: integer
        name:
          type: string
        email:
          type: string
        created_at:
          type: string
          format: date-time
```

## Best Practices

### 1. Consistent Response Format

```crystal
# Always return consistent JSON structure
{
  "data": {
    "id": 1,
    "name": "John Doe"
  },
  "meta": {
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

### 2. Proper Error Handling

```crystal
# Use appropriate HTTP status codes
# Provide meaningful error messages
# Include error codes for programmatic handling
```

### 3. Input Validation

```crystal
# Always validate input data
# Use contracts for validation
# Return detailed validation errors
```

### 4. Rate Limiting

```crystal
# Implement rate limiting
# Use appropriate headers
# Document rate limits
```

### 5. Caching

```crystal
# Use ETags for caching
# Implement conditional requests
# Set appropriate cache headers
```

## Related Documentation

- [Endpoint Generator](generators/endpoint.md) - Creating endpoints with generators
- [Contract Generator](generators/contract.md) - Input validation
- [Model Generator](generators/model.md) - Database models
- [Testing Your Application](testing.md) - API testing strategies
