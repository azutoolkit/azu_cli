# Endpoint Generator

The endpoint generator creates HTTP request handlers for your Azu application. Endpoints handle incoming HTTP requests and return typed responses.

## Overview

```bash
azu generate endpoint <name> [options]
```

## Basic Usage

```bash
# Generate endpoint with default index action
azu generate endpoint users

# Generate with namespace
azu generate endpoint admin/users

# Generate API endpoint
azu generate endpoint api/v1/users --api

# Generate with specific actions
azu generate endpoint posts --actions index,show,create,update,destroy
```

## Command Options

| Option             | Description                         | Default |
| ------------------ | ----------------------------------- | ------- |
| `--api`            | Generate API-only endpoints         | false   |
| `--actions <list>` | Comma-separated actions to generate | index   |
| `--force`          | Overwrite existing files            | false   |

## Generated Files

```text
src/endpoints/
└── users/
    ├── user_index_endpoint.cr
    ├── user_show_endpoint.cr
    ├── user_create_endpoint.cr
    ├── user_update_endpoint.cr
    └── user_destroy_endpoint.cr
```

## Endpoint Structure

Endpoints use `include Azu::Endpoint(RequestType, ResponseType)` with HTTP verb macros.

### Index Endpoint

```crystal
# src/endpoints/users/user_index_endpoint.cr
module App::Users
  struct IndexEndpoint
    include Azu::Endpoint(Users::IndexRequest, Users::IndexResponse)

    get "/users"

    def call : Users::IndexResponse
      result = IndexService.new.call

      if result.success?
        users = result.data.not_nil!
        Users::IndexResponse.new(users: users)
      else
        Users::IndexResponse.new(users: [] of Users::User)
      end
    end
  end
end
```

### Show Endpoint

```crystal
module App::Users
  struct ShowEndpoint
    include Azu::Endpoint(Users::ShowRequest, Users::ShowResponse)

    get "/users/:id"

    def call : Users::ShowResponse
      id = path_params["id"].to_i64
      result = ShowService.new.call(id)

      if result.success?
        user = result.data.not_nil!
        Users::ShowResponse.new(user: user)
      else
        raise Azu::Response::NotFoundError.new("User not found")
      end
    end
  end
end
```

### Create Endpoint

```crystal
module App::Users
  struct CreateEndpoint
    include Azu::Endpoint(Users::CreateRequest, Users::CreateResponse)

    post "/users"

    def call : Users::CreateResponse
      result = CreateService.new.call(request)

      if result.success?
        user = result.data.not_nil!
        Users::CreateResponse.new(user: user)
      else
        raise Azu::Response::ValidationError.new("Validation failed")
      end
    end
  end
end
```

### Update Endpoint

```crystal
module App::Users
  struct UpdateEndpoint
    include Azu::Endpoint(Users::UpdateRequest, Users::UpdateResponse)

    patch "/users/:id"

    def call : Users::UpdateResponse
      id = path_params["id"].to_i64
      result = UpdateService.new.call(id, request)

      if result.success?
        user = result.data.not_nil!
        Users::UpdateResponse.new(user: user)
      else
        raise Azu::Response::ValidationError.new("Validation failed")
      end
    end
  end
end
```

### Destroy Endpoint

```crystal
module App::Users
  struct DestroyEndpoint
    include Azu::Endpoint(Users::DestroyRequest, Users::DestroyResponse)

    delete "/users/:id"

    def call : Users::DestroyResponse
      id = path_params["id"].to_i64
      result = DestroyService.new.call(id)

      if result.success?
        Users::DestroyResponse.new(success: true)
      else
        raise Azu::Response::NotFoundError.new("User not found")
      end
    end
  end
end
```

## Request Types

Requests use `include Azu::Request` with validation.

```crystal
# src/requests/users/create_request.cr
struct Users::CreateRequest
  include Azu::Request
  include JSON::Serializable

  getter name : String
  getter email : String
  getter age : Int32?

  def initialize(@name = "", @email = "", @age = nil)
  end

  validate :name, presence: true, size: 2..50
  validate :email, presence: true
end
```

## Response Types

Responses use `include Azu::Response` with JSON serialization.

```crystal
# src/responses/users/user_response.cr
struct Users::UserResponse
  include Azu::Response
  include JSON::Serializable

  getter id : Int64
  getter name : String
  getter email : String

  def initialize(user : User)
    @id = user.id.not_nil!
    @name = user.name
    @email = user.email
  end

  def render
    to_json
  end
end
```

## Page Types (Web Endpoints)

Pages use `include Azu::Response` with template rendering.

```crystal
# src/pages/users/index_page.cr
struct Users::IndexPage
  include Azu::Response
  include Azu::Templates::Renderable

  getter users : Array(User)

  def initialize(@users : Array(User))
  end

  def render
    view "users/index.html", {
      "users" => users.map { |u| {"id" => u.id, "name" => u.name} },
      "title" => "All Users"
    }
  end
end
```

## HTTP Verb Macros

| Macro    | HTTP Method | Example                |
| -------- | ----------- | ---------------------- |
| `get`    | GET         | `get "/users"`         |
| `post`   | POST        | `post "/users"`        |
| `put`    | PUT         | `put "/users/:id"`     |
| `patch`  | PATCH       | `patch "/users/:id"`   |
| `delete` | DELETE      | `delete "/users/:id"`  |

## Accessing Request Data

```crystal
def call : Response
  # Path parameters
  id = path_params["id"].to_i64

  # Query parameters
  page = query_params["page"]?.try(&.to_i) || 1

  # Request body (from typed request)
  name = request.name
  email = request.email

  # Headers
  token = headers["Authorization"]?
end
```

## Error Handling

```crystal
def call : UserResponse
  user = UserService.find(id)

  unless user
    raise Azu::Response::NotFoundError.new("User not found")
  end

  UserResponse.new(user)
rescue ex : Azu::Response::ValidationError
  raise ex
rescue ex
  raise Azu::Response::InternalServerError.new(ex.message)
end
```

## Examples

### API Endpoints

```bash
azu generate endpoint api/v1/users --api --actions index,show,create,update,destroy
```

### Nested Resources

```bash
azu generate endpoint posts/comments --actions index,create
```

Generated path: `/posts/:post_id/comments`

---

**Next Steps:**

- [Request Generator](request.md) - Create request validation
- [Page Generator](page.md) - Create response pages
- [Service Generator](service.md) - Create business logic
