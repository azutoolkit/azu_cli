# Scaffold Generator

The scaffold generator creates a complete set of files for a resource with full CRUD operations.

## Usage

```bash
azu generate scaffold <name> [field:type...] [options]
```

## Options

| Option       | Description              | Default |
| ------------ | ------------------------ | ------- |
| `--api-only` | Generate API components  | false   |
| `--web-only` | Generate web components  | false   |
| `--force`    | Overwrite existing files | false   |

## Examples

```bash
# Basic scaffold
azu generate scaffold User name:string email:string

# Blog post with relationships
azu generate scaffold Post title:string content:text user_id:references published:bool

# API-only scaffold
azu generate scaffold Product name:string price:float64 --api-only
```

## Generated Files

```text
src/
├── models/
│   └── user.cr
├── endpoints/
│   └── users/
│       ├── user_index_endpoint.cr
│       ├── user_show_endpoint.cr
│       ├── user_create_endpoint.cr
│       ├── user_update_endpoint.cr
│       └── user_destroy_endpoint.cr
├── requests/
│   └── users/
│       ├── index_request.cr
│       ├── show_request.cr
│       ├── create_request.cr
│       └── update_request.cr
├── pages/
│   └── users/
│       ├── index_page.cr
│       └── show_page.cr
├── services/
│   └── users/
│       ├── index_service.cr
│       ├── show_service.cr
│       ├── create_service.cr
│       ├── update_service.cr
│       └── destroy_service.cr
└── db/
    └── migrations/
        └── 20240115103045_create_users.cr
```

## Generated Code

### Model

```crystal
# src/models/user.cr
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users

  getter id : Int64?
  getter name : String
  getter email : String
  getter created_at : Time?
  getter updated_at : Time?

  validate :name, presence: true, size: 2..100
  validate :email, presence: true

  def initialize(@name : String, @email : String)
  end
end
```

### Migration

```crystal
# src/db/migrations/20240115103045_create_users.cr
class CreateUsers < CQL::Migration(20240115103045)
  def up
    schema.table :users do
      primary :id, Int64
      text :name
      text :email
      timestamps
    end
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
```

### Endpoint

```crystal
# src/endpoints/users/user_index_endpoint.cr
module App::Users
  struct IndexEndpoint
    include Azu::Endpoint(Users::IndexRequest, Users::IndexPage)

    get "/users"

    def call : Users::IndexPage
      result = IndexService.new.call

      if result.success?
        users = result.data.not_nil!
        Users::IndexPage.new(users: users)
      else
        Users::IndexPage.new(users: [] of User)
      end
    end
  end
end
```

### Request

```crystal
# src/requests/users/create_request.cr
struct Users::CreateRequest
  include Azu::Request
  include JSON::Serializable

  getter name : String
  getter email : String

  def initialize(@name = "", @email = "")
  end

  validate :name, presence: true, size: 2..100
  validate :email, presence: true
end
```

### Page (Response)

```crystal
# src/pages/users/index_page.cr
struct Users::IndexPage
  include Azu::Response
  include JSON::Serializable

  getter users : Array(User)

  def initialize(@users : Array(User))
  end

  def render
    to_json
  end
end
```

### Service

```crystal
# src/services/users/create_service.cr
module App::Users
  class CreateService
    def call(request : CreateRequest) : Result(User)
      user = User.new(
        name: request.name,
        email: request.email
      )

      if user.save
        Result(User).success(user)
      else
        Result(User).failure(user.errors)
      end
    end
  end
end
```

## Field Types

| Type         | Crystal Type | Description           |
| ------------ | ------------ | --------------------- |
| `string`     | `String`     | Text field            |
| `text`       | `String`     | Long text field       |
| `int32`      | `Int32`      | 32-bit integer        |
| `int64`      | `Int64`      | 64-bit integer        |
| `float64`    | `Float64`    | Decimal number        |
| `bool`       | `Bool`       | Boolean value         |
| `time`       | `Time`       | Timestamp             |
| `uuid`       | `UUID`       | UUID field            |
| `references` | `Int64`      | Foreign key reference |

## Common Patterns

### Blog Post

```bash
azu generate scaffold Post title:string content:text user_id:references published:bool
```

### E-commerce Product

```bash
azu generate scaffold Product name:string description:text price:float64 stock:int32
```

### User Management

```bash
azu generate scaffold User name:string email:string role:string active:bool
```

---

**Next Steps:**

- [Model Generator](model.md) - Create database models
- [Endpoint Generator](endpoint.md) - Create HTTP endpoints
- [Migration Generator](migration.md) - Create database migrations
