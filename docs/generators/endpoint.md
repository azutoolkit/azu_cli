# Endpoint Generator

The endpoint generator creates HTTP request handlers for your Azu application. Endpoints are the controllers that handle incoming HTTP requests and return responses.

## Overview

```bash
azu generate endpoint <name> [options]
```

## Basic Usage

### Generate a Simple Endpoint

```bash
# Generate a basic endpoint
azu generate endpoint users

# Generate with namespace
azu generate endpoint admin/users

# Generate API endpoint
azu generate endpoint api/v1/users --api
```

### Generate CRUD Endpoints

```bash
# Generate full CRUD operations
azu generate endpoint posts --actions index,show,create,update,destroy

# Generate specific actions only
azu generate endpoint comments --actions index,create
```

## Command Options

| Option             | Description                                      | Default          |
| ------------------ | ------------------------------------------------ | ---------------- |
| `--api`            | Generate API-only endpoints (no pages/templates) | false            |
| `--actions <list>` | Specify which actions to generate                | all CRUD actions |
| `--skip-tests`     | Don't generate test files                        | false            |
| `--skip-routes`    | Don't register routes automatically              | false            |
| `--force`          | Overwrite existing files                         | false            |

## Generated Files

### Basic Endpoint Structure

```
src/endpoints/
└── users/
    ├── index_endpoint.cr      # List all users
    ├── show_endpoint.cr       # Show single user
    ├── new_endpoint.cr        # New user form
    ├── create_endpoint.cr     # Create user
    ├── edit_endpoint.cr       # Edit user form
    ├── update_endpoint.cr     # Update user
    └── destroy_endpoint.cr    # Delete user
```

### API Endpoint Structure

```
src/endpoints/
└── api/
    └── v1/
        └── users/
            ├── index_endpoint.cr      # GET /api/v1/users
            ├── show_endpoint.cr       # GET /api/v1/users/:id
            ├── create_endpoint.cr     # POST /api/v1/users
            ├── update_endpoint.cr     # PUT /api/v1/users/:id
            └── destroy_endpoint.cr    # DELETE /api/v1/users/:id
```

## Endpoint Types

### Web Endpoints (Default)

Full-stack endpoints that render HTML pages and handle form submissions.

**Generated Files:**

- Endpoint classes with HTML rendering
- Associated page components
- Form handling and validation
- Flash messages and redirects

**Example:**

```crystal
# src/endpoints/users/index_endpoint.cr
class Users::IndexEndpoint < Azu::Endpoint
  def call
    users = User.all
    render "users/index_page", users: users
  end
end
```

### API Endpoints (`--api`)

JSON API endpoints for building APIs, mobile backends, or microservices.

**Generated Files:**

- Endpoint classes with JSON responses
- Request/response contracts
- Status codes and error handling
- No HTML templates

**Example:**

```crystal
# src/endpoints/api/v1/users/index_endpoint.cr
class Api::V1::Users::IndexEndpoint < Azu::Endpoint
  def call
    users = User.all
    json users: users.map(&.to_json)
  end
end
```

## Action Types

### Index Action

Lists all resources.

```bash
# Generate index action
azu generate endpoint users --actions index
```

**Generated Code:**

```crystal
# src/endpoints/users/index_endpoint.cr
class Users::IndexEndpoint < Azu::Endpoint
  def call
    users = User.all
    render "users/index_page", users: users
  end
end
```

**Route:** `GET /users`

### Show Action

Displays a single resource.

```bash
# Generate show action
azu generate endpoint users --actions show
```

**Generated Code:**

```crystal
# src/endpoints/users/show_endpoint.cr
class Users::ShowEndpoint < Azu::Endpoint
  def call
    user = User.find(params["id"])
    render "users/show_page", user: user
  rescue CQL::RecordNotFound
    not_found
  end
end
```

**Route:** `GET /users/:id`

### New Action

Displays form for creating a new resource.

```bash
# Generate new action
azu generate endpoint users --actions new
```

**Generated Code:**

```crystal
# src/endpoints/users/new_endpoint.cr
class Users::NewEndpoint < Azu::Endpoint
  def call
    user = User.new
    render "users/new_page", user: user
  end
end
```

**Route:** `GET /users/new`

### Create Action

Handles form submission to create a new resource.

```bash
# Generate create action
azu generate endpoint users --actions create
```

**Generated Code:**

```crystal
# src/endpoints/users/create_endpoint.cr
class Users::CreateEndpoint < Azu::Endpoint
  def call
    user = User.new(user_params)

    if user.save
      redirect_to "/users/#{user.id}", flash: { success: "User created successfully" }
    else
      render "users/new_page", user: user, status: :unprocessable_entity
    end
  end

  private def user_params
    params.require(:user).permit(:name, :email)
  end
end
```

**Route:** `POST /users`

### Edit Action

Displays form for editing an existing resource.

```bash
# Generate edit action
azu generate endpoint users --actions edit
```

**Generated Code:**

```crystal
# src/endpoints/users/edit_endpoint.cr
class Users::EditEndpoint < Azu::Endpoint
  def call
    user = User.find(params["id"])
    render "users/edit_page", user: user
  rescue CQL::RecordNotFound
    not_found
  end
end
```

**Route:** `GET /users/:id/edit`

### Update Action

Handles form submission to update an existing resource.

```bash
# Generate update action
azu generate endpoint users --actions update
```

**Generated Code:**

```crystal
# src/endpoints/users/update_endpoint.cr
class Users::UpdateEndpoint < Azu::Endpoint
  def call
    user = User.find(params["id"])

    if user.update(user_params)
      redirect_to "/users/#{user.id}", flash: { success: "User updated successfully" }
    else
      render "users/edit_page", user: user, status: :unprocessable_entity
    end
  rescue CQL::RecordNotFound
    not_found
  end

  private def user_params
    params.require(:user).permit(:name, :email)
  end
end
```

**Route:** `PUT /users/:id` or `PATCH /users/:id`

### Destroy Action

Deletes a resource.

```bash
# Generate destroy action
azu generate endpoint users --actions destroy
```

**Generated Code:**

```crystal
# src/endpoints/users/destroy_endpoint.cr
class Users::DestroyEndpoint < Azu::Endpoint
  def call
    user = User.find(params["id"])
    user.destroy

    redirect_to "/users", flash: { success: "User deleted successfully" }
  rescue CQL::RecordNotFound
    not_found
  end
end
```

**Route:** `DELETE /users/:id`

## Examples

### Blog Application

```bash
# Generate blog endpoints
azu generate endpoint posts
azu generate endpoint comments
azu generate endpoint categories

# Generate admin endpoints
azu generate endpoint admin/dashboard
azu generate endpoint admin/users
```

### API Service

```bash
# Generate API endpoints
azu generate endpoint api/v1/users --api
azu generate endpoint api/v1/posts --api
azu generate endpoint api/v1/comments --api

# Generate specific actions
azu generate endpoint api/v1/auth --api --actions create
```

### Nested Resources

```bash
# Generate nested endpoints
azu generate endpoint posts/comments
azu generate endpoint users/posts
```

## Generated Code Examples

### Web Endpoint (Full CRUD)

```crystal
# src/endpoints/users/index_endpoint.cr
class Users::IndexEndpoint < Azu::Endpoint
  def call
    users = User.all
    render "users/index_page", users: users
  end
end

# src/endpoints/users/show_endpoint.cr
class Users::ShowEndpoint < Azu::Endpoint
  def call
    user = User.find(params["id"])
    render "users/show_page", user: user
  rescue CQL::RecordNotFound
    not_found
  end
end

# src/endpoints/users/create_endpoint.cr
class Users::CreateEndpoint < Azu::Endpoint
  def call
    user = User.new(user_params)

    if user.save
      redirect_to "/users/#{user.id}", flash: { success: "User created successfully" }
    else
      render "users/new_page", user: user, status: :unprocessable_entity
    end
  end

  private def user_params
    params.require(:user).permit(:name, :email, :password)
  end
end
```

### API Endpoint

```crystal
# src/endpoints/api/v1/users/index_endpoint.cr
class Api::V1::Users::IndexEndpoint < Azu::Endpoint
  def call
    users = User.all
    json users: users.map(&.to_json)
  end
end

# src/endpoints/api/v1/users/show_endpoint.cr
class Api::V1::Users::ShowEndpoint < Azu::Endpoint
  def call
    user = User.find(params["id"])
    json user: user.to_json
  rescue CQL::RecordNotFound
    json error: "User not found", status: :not_found
  end
end

# src/endpoints/api/v1/users/create_endpoint.cr
class Api::V1::Users::CreateEndpoint < Azu::Endpoint
  def call
    user = User.new(user_params)

    if user.save
      json user: user.to_json, status: :created
    else
      json errors: user.errors, status: :unprocessable_entity
    end
  end

  private def user_params
    params.require(:user).permit(:name, :email, :password)
  end
end
```

## Route Registration

### Automatic Route Registration

By default, endpoints are automatically registered in your routes:

```crystal
# src/server.cr (auto-generated)
require "./endpoints/**"

# Routes are automatically registered based on endpoint structure
# GET /users -> Users::IndexEndpoint
# GET /users/:id -> Users::ShowEndpoint
# GET /users/new -> Users::NewEndpoint
# POST /users -> Users::CreateEndpoint
# GET /users/:id/edit -> Users::EditEndpoint
# PUT /users/:id -> Users::UpdateEndpoint
# DELETE /users/:id -> Users::DestroyEndpoint
```

### Manual Route Registration

If you use `--skip-routes`, register routes manually:

```crystal
# src/server.cr
require "./endpoints/**"

# Manual route registration
Azu::Router.draw do
  get "/users", Users::IndexEndpoint
  get "/users/:id", Users::ShowEndpoint
  get "/users/new", Users::NewEndpoint
  post "/users", Users::CreateEndpoint
  get "/users/:id/edit", Users::EditEndpoint
  put "/users/:id", Users::UpdateEndpoint
  delete "/users/:id", Users::DestroyEndpoint
end
```

## Testing

### Generated Test Files

```crystal
# spec/endpoints/users/index_endpoint_spec.cr
require "../spec_helper"

describe Users::IndexEndpoint do
  it "lists all users" do
    user1 = User.create!(name: "John", email: "john@example.com")
    user2 = User.create!(name: "Jane", email: "jane@example.com")

    response = get "/users"

    response.status_code.should eq(200)
    response.body.should contain("John")
    response.body.should contain("Jane")
  end
end
```

### API Endpoint Tests

```crystal
# spec/endpoints/api/v1/users/index_endpoint_spec.cr
require "../spec_helper"

describe Api::V1::Users::IndexEndpoint do
  it "returns users as JSON" do
    user = User.create!(name: "John", email: "john@example.com")

    response = get "/api/v1/users"

    response.status_code.should eq(200)
    response.headers["Content-Type"].should contain("application/json")

    json = JSON.parse(response.body)
    json["users"].as_a.size.should eq(1)
    json["users"][0]["name"].should eq("John")
  end
end
```

## Advanced Usage

### Custom Endpoint Logic

```bash
# Generate endpoint with custom actions
azu generate endpoint search --actions index
```

```crystal
# src/endpoints/search/index_endpoint.cr
class Search::IndexEndpoint < Azu::Endpoint
  def call
    query = params["q"]?
    results = if query
      User.where("name ILIKE ?", "%#{query}%")
    else
      User.none
    end

    render "search/index_page", results: results, query: query
  end
end
```

### Nested Resources

```bash
# Generate nested endpoints
azu generate endpoint posts/comments
```

```crystal
# src/endpoints/posts/comments/index_endpoint.cr
class Posts::Comments::IndexEndpoint < Azu::Endpoint
  def call
    post = Post.find(params["post_id"])
    comments = post.comments
    render "posts/comments/index_page", post: post, comments: comments
  rescue CQL::RecordNotFound
    not_found
  end
end
```

### API Versioning

```bash
# Generate versioned API endpoints
azu generate endpoint api/v1/users --api
azu generate endpoint api/v2/users --api
```

```crystal
# src/endpoints/api/v1/users/index_endpoint.cr
class Api::V1::Users::IndexEndpoint < Azu::Endpoint
  def call
    users = User.all
    json users: users.map(&.to_json_v1)
  end
end

# src/endpoints/api/v2/users/index_endpoint.cr
class Api::V2::Users::IndexEndpoint < Azu::Endpoint
  def call
    users = User.all
    json users: users.map(&.to_json_v2)
  end
end
```

## Best Practices

### 1. Naming Conventions

```bash
# Use plural names for resource endpoints
azu generate endpoint users        # Good
azu generate endpoint user         # Avoid

# Use descriptive names for action endpoints
azu generate endpoint search       # Good
azu generate endpoint dashboard    # Good
```

### 2. API Design

```bash
# Use consistent API structure
azu generate endpoint api/v1/users --api
azu generate endpoint api/v1/posts --api
azu generate endpoint api/v1/comments --api

# Use versioning for API changes
azu generate endpoint api/v2/users --api
```

### 3. Security

```crystal
# Always validate parameters
private def user_params
  params.require(:user).permit(:name, :email, :password)
end

# Handle errors gracefully
rescue CQL::RecordNotFound
  not_found
```

### 4. Testing

```bash
# Generate tests for all endpoints
azu generate endpoint users --skip-tests=false

# Test API endpoints with proper status codes
# Test web endpoints with proper redirects
```

## Troubleshooting

### Endpoint Not Found

```bash
# Check if endpoint was generated
ls -la src/endpoints/

# Check route registration
cat src/server.cr

# Restart server
azu serve
```

### Parameter Issues

```crystal
# Debug parameters
def call
  puts "Params: #{params.inspect}"
  # ... rest of endpoint
end
```

### Template Issues

```bash
# Check if templates exist
ls -la src/pages/

# Generate missing templates
azu generate page users/index
```

---

The endpoint generator creates the HTTP request handlers for your Azu application, providing both web and API endpoints with full CRUD operations.

**Next Steps:**

- [Model Generator](model.md) - Create database models
- [Contract Generator](contract.md) - Add request validation
- [Page Generator](page.md) - Create view templates
