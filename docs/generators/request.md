# Request Generator

The Request Generator creates request structs that define the structure and validation rules for incoming data in your Azu application. These align with the `Azu::Request` convention.

> **Deprecation Notice**: The `contract` generator is deprecated. Use `request` instead. Running `azu generate contract` will automatically redirect to `request`.

## Usage

```bash
azu generate request REQUEST_NAME [attr:type...] [OPTIONS]
```

## Description

Requests in Azu applications provide a way to validate and structure incoming data from HTTP requests, API calls, or form submissions. They ensure data integrity and provide clear error messages when validation fails.

## Options

- `REQUEST_NAME` - Name of the request to generate (required)
- `attr:type` - Field definitions (e.g., `name:string email:string age:int32`)
- `--force` - Overwrite existing files
- `--help` - Show help message

## Examples

### Generate a basic request

```bash
azu generate request User name:string email:string
```

This creates:
- `src/requests/user/index_request.cr` - The request struct

### Generate request for specific action

```bash
azu generate request User create name:string email:string password:string
```

### Generate request with various field types

```bash
azu generate request Post title:string content:text published:bool views:int32
```

## Field Types

The request generator supports these field types:

| Type | Crystal Type | Description |
|------|--------------|-------------|
| `string` | `String` | Text strings |
| `text` | `String` | Long text |
| `int32`, `integer` | `Int32` | 32-bit integers |
| `int64` | `Int64` | 64-bit integers |
| `float32` | `Float32` | 32-bit floats |
| `float64`, `float` | `Float64` | 64-bit floats |
| `bool`, `boolean` | `Bool` | Boolean values |
| `time`, `datetime` | `Time` | Date and time |
| `date` | `Date` | Date only |
| `json` | `JSON::Any` | JSON data |
| `reference`, `belongs_to` | `Int64` | Foreign key reference |

## Generated File Structure

```
src/requests/
└── user/
    ├── index_request.cr
    ├── show_request.cr
    ├── create_request.cr
    ├── update_request.cr
    └── destroy_request.cr
```

## Generated Code Example

### Request Struct (`src/requests/user/create_request.cr`)

```crystal
module App::User
  struct CreateRequest
    include Azu::Request

    getter name : String
    getter email : String
    getter age : Int32?
  end
end
```

## Using Requests in Endpoints

### Basic Usage

```crystal
struct Users::CreateEndpoint
  include Azu::Endpoint(User::CreateRequest, User::CreateResponse)

  post "/users"

  def call : User::CreateResponse
    # Access validated request data
    user = Models::User.create!(
      name: request.name,
      email: request.email
    )

    User::CreateResponse.new(user: user)
  end
end
```

### With Validation

```crystal
module App::User
  struct CreateRequest
    include Azu::Request

    getter name : String
    getter email : String

    def valid? : Bool
      !name.empty? && email.includes?("@")
    end

    def errors : Array(String)
      errors = [] of String
      errors << "Name is required" if name.empty?
      errors << "Invalid email format" unless email.includes?("@")
      errors
    end
  end
end
```

## Request Patterns

### Basic Request Pattern

```crystal
module App::User
  struct IndexRequest
    include Azu::Request

    getter page : Int32 = 1
    getter per_page : Int32 = 25
    getter sort : String = "created_at"
    getter order : String = "desc"
  end
end
```

### Request with Optional Fields

```crystal
module App::User
  struct UpdateRequest
    include Azu::Request

    getter name : String?
    getter email : String?
    getter bio : String?
  end
end
```

### Request with Nested Data

```crystal
module App::Order
  struct CreateRequest
    include Azu::Request

    getter customer_id : Int64
    getter items : Array(OrderItem)

    struct OrderItem
      getter product_id : Int64
      getter quantity : Int32
    end
  end
end
```

## Best Practices

### 1. Keep Requests Focused

Each request should validate a specific use case:

```crystal
# Good: Separate requests for different operations
struct CreateUserRequest
  include Azu::Request
  getter name : String
  getter email : String
  getter password : String
end

struct UpdateUserRequest
  include Azu::Request
  getter name : String?
  getter email : String?
  # No password field for updates
end
```

### 2. Use Type-Safe Fields

```crystal
# Good: Explicit types
struct UserRequest
  include Azu::Request
  getter age : Int32
  getter active : Bool
  getter rating : Float64
end
```

### 3. Provide Default Values

```crystal
struct PaginationRequest
  include Azu::Request
  getter page : Int32 = 1
  getter per_page : Int32 = 25
end
```

### 4. Document Expected Formats

```crystal
struct DateRangeRequest
  include Azu::Request

  # Expected format: YYYY-MM-DD
  getter start_date : String

  # Expected format: YYYY-MM-DD
  getter end_date : String
end
```

## Testing Requests

### Unit Testing

```crystal
describe User::CreateRequest do
  it "parses valid request data" do
    params = HTTP::Params.parse("name=John&email=john@example.com")
    request = User::CreateRequest.from_params(params)

    request.name.should eq("John")
    request.email.should eq("john@example.com")
  end

  it "handles missing optional fields" do
    params = HTTP::Params.parse("name=John")
    request = User::UpdateRequest.from_params(params)

    request.name.should eq("John")
    request.email.should be_nil
  end
end
```

## Related Commands

- `azu generate endpoint` - Generate API endpoints
- `azu generate model` - Generate data models
- `azu generate service` - Generate business logic services
- `azu generate scaffold` - Generate complete CRUD resources

## Migration from Contract

If you're migrating from the deprecated `contract` generator:

1. Rename `contract` to `request` in your generator commands
2. Update class inheritance from `Azu::Contract` to `include Azu::Request`
3. Replace validation methods with the request pattern

```crystal
# Old (Contract pattern)
class UserContract < Azu::Contract
  field :name, String, required: true
end

# New (Request pattern)
struct UserRequest
  include Azu::Request
  getter name : String
end
```
