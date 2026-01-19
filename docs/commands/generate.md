# azu generate

The `azu generate` command is one of the most powerful features of Azu CLI. It creates various components for your application, following Azu conventions and best practices. This command helps you rapidly develop applications by generating boilerplate code, tests, and associated files.

## Overview

```bash
azu generate <generator_type> <name> [attributes] [options]
```

## Available Generators

| Generator    | Alias             | Description                                         |
| ------------ | ----------------- | --------------------------------------------------- |
| `endpoint`   | `e`, `controller` | HTTP endpoints with full CRUD operations            |
| `model`      | `m`               | CQL ORM models with validations                     |
| `service`    | `s`               | Business logic services following DDD patterns      |
| `middleware` | `mw`              | HTTP middleware components                          |
| `contract`   | `c`               | Request/response validation contracts               |
| `page`       | `p`               | Page components for rendering HTML                  |
| `component`  | `comp`            | Live interactive components with real-time features |
| `validator`  | `v`, `val`        | Custom validation logic                             |
| `migration`  | `mig`             | Database migration files                            |
| `scaffold`   |                   | Complete CRUD resource (all of the above)           |

## Global Options

| Option          | Description                                | Default |
| --------------- | ------------------------------------------ | ------- |
| `--force`       | Overwrite existing files without prompting | false   |
| `--skip-tests`  | Don't generate test files                  | false   |
| `--skip-routes` | Don't register routes automatically        | false   |
| `--help`        | Show help for the generator                |         |

## Endpoint Generator

Generates HTTP endpoints (controllers) for handling web requests.

### Usage

```bash
azu generate endpoint <name> [actions] [options]
```

### Examples

```bash
# Generate basic endpoint with all CRUD actions
azu generate endpoint users

# Generate endpoint with specific actions
azu generate endpoint posts index show create

# Generate API endpoint
azu generate endpoint api/v1/posts --api

# Skip test generation
azu generate endpoint users --skip-tests
```

### Generated Files

```
src/endpoints/users/
├── index_endpoint.cr      # GET /users
├── show_endpoint.cr       # GET /users/:id
├── new_endpoint.cr        # GET /users/new
├── create_endpoint.cr     # POST /users
├── edit_endpoint.cr       # GET /users/:id/edit
├── update_endpoint.cr     # PUT/PATCH /users/:id
└── destroy_endpoint.cr    # DELETE /users/:id

src/contracts/users/
├── index_contract.cr
├── show_contract.cr
├── create_contract.cr
└── update_contract.cr

src/pages/users/
├── index_page.cr
├── show_page.cr
├── new_page.cr
└── edit_page.cr

public/templates/users/
├── index_page.jinja
├── show_page.jinja
├── new_page.jinja
└── edit_page.jinja

spec/endpoints/users_spec.cr
```

### Example Generated Endpoint

```crystal
# src/endpoints/users/index_endpoint.cr
class Users::IndexEndpoint
  include Azu::Endpoint

  def call(request)
    users = User.all
    contract = Users::IndexContract.new(request)

    if contract.valid?
      index_page = Users::IndexPage.new(users: users)
      index_page.render
    else
      render_errors(contract.errors)
    end
  end
end
```

### Options

| Option             | Description                                      |
| ------------------ | ------------------------------------------------ |
| `--api`            | Generate API-only endpoints (no pages/templates) |
| `--actions <list>` | Specify which actions to generate                |

## Model Generator

Generates CQL ORM models with validations and relationships.

### Usage

```bash
azu generate model <name> [field:type] [options]
```

### Examples

```bash
# Basic model
azu generate model User

# Model with attributes
azu generate model User name:string email:string age:integer

# Model with different field types
azu generate model Post title:string content:text published:boolean author_id:integer

# Model with validations
azu generate model User name:string email:string --validations
```

### Field Types

| Type      | Crystal Type | Database Type |
| --------- | ------------ | ------------- |
| `string`  | `String`     | VARCHAR/TEXT  |
| `text`    | `String`     | TEXT          |
| `integer` | `Int32`      | INTEGER       |
| `bigint`  | `Int64`      | BIGINT        |
| `float`   | `Float64`    | FLOAT         |
| `decimal` | `BigDecimal` | DECIMAL       |
| `boolean` | `Bool`       | BOOLEAN       |
| `date`    | `Date`       | DATE          |
| `time`    | `Time`       | TIMESTAMP     |
| `json`    | `JSON::Any`  | JSON/JSONB    |
| `uuid`    | `UUID`       | UUID          |

### Generated Files

```
src/models/user.cr
spec/models/user_spec.cr
```

### Example Generated Model

```crystal
# src/models/user.cr
require "cql"

class User < CQL::Model
  db_table "users"

  field id : Int64, primary: true, auto_increment: true
  field name : String
  field email : String
  field age : Int32?
  field created_at : Time = Time.utc
  field updated_at : Time = Time.utc

  validate :name, presence: true, length: {min: 2, max: 50}
  validate :email, presence: true, format: EMAIL_REGEX, uniqueness: true
  validate :age, numericality: {greater_than: 0, less_than: 150}

  before_save :update_timestamps

  private def update_timestamps
    self.updated_at = Time.utc
  end
end
```

### Options

| Option          | Description                      |
| --------------- | -------------------------------- |
| `--validations` | Add common validations           |
| `--timestamps`  | Add created_at/updated_at fields |
| `--uuid`        | Use UUID as primary key          |

## Service Generator

Generates service classes for encapsulating business logic.

### Usage

```bash
azu generate service <name> [methods] [options]
```

### Examples

```bash
# Basic service
azu generate service UserRegistration

# Service with specific methods
azu generate service EmailNotification send deliver

# Service with dependencies
azu generate service PaymentProcessor --dependencies user_repo,payment_gateway
```

### Generated Files

```
src/services/user_registration_service.cr
spec/services/user_registration_service_spec.cr
```

### Example Generated Service

```crystal
# src/services/user_registration_service.cr
class UserRegistrationService
  def initialize(@email : String, @password : String)
  end

  def call
    return failure("Email already exists") if User.exists?(email: @email)

    user = User.create!(
      email: @email,
      password: hash_password(@password)
    )

    EmailService.send_welcome_email(user)
    success(user)
  rescue ex
    failure("Registration failed: #{ex.message}")
  end

  private def hash_password(password)
    # Password hashing logic
  end

  private def success(data)
    {success: true, data: data}
  end

  private def failure(message)
    {success: false, error: message}
  end
end
```

## Component Generator

Generates live, interactive components for real-time features.

### Usage

```bash
azu generate component <name> [attributes] [options]
```

### Examples

```bash
# Basic component
azu generate component Counter

# Component with attributes
azu generate component Counter count:integer step:integer

# Real-time component with WebSocket
azu generate component ChatMessage --websocket

# Component with events
azu generate component TodoItem completed:boolean --events toggle,delete
```

### Generated Files

```
src/components/counter_component.cr
spec/components/counter_component_spec.cr
```

### Example Generated Component

```crystal
# src/components/counter_component.cr
class CounterComponent
  include Azu::Component

  def initialize(@count : Int32 = 0, @step : Int32 = 1)
  end

  def increment
    @count += @step
    update_element("counter-value", @count.to_s)
    broadcast_update({
      type: "counter_updated",
      count: @count,
      timestamp: Time.utc
    })
  end

  def decrement
    @count -= @step
    update_element("counter-value", @count.to_s)
    broadcast_update({
      type: "counter_updated",
      count: @count,
      timestamp: Time.utc
    })
  end

  def reset
    @count = 0
    update_element("counter-value", "0")
    broadcast_update({
      type: "counter_reset",
      timestamp: Time.utc
    })
  end

  def render
    <<-HTML
    <div id="counter-component" class="counter">
      <h3>Counter Component</h3>
      <div class="counter-display">
        <span id="counter-value">#{@count}</span>
      </div>
      <div class="counter-controls">
        <button onclick="counter.decrement()">-</button>
        <button onclick="counter.reset()">Reset</button>
        <button onclick="counter.increment()">+</button>
      </div>
    </div>
    HTML
  end
end
```

### Options

| Option            | Description                                    |
| ----------------- | ---------------------------------------------- |
| `--websocket`     | Enable WebSocket support for real-time updates |
| `--events <list>` | Specify custom event handlers                  |

## Migration Generator

Generates database migration files.

### Usage

```bash
azu generate migration <name> [field:type] [options]
```

### Examples

```bash
# Create table migration
azu generate migration create_users_table name:string email:string

# Add column migration
azu generate migration add_age_to_users age:integer

# Remove column migration
azu generate migration remove_age_from_users age:integer

# Add index migration
azu generate migration add_index_to_users_email --index email
```

### Generated Files

```
db/migrations/20231214_120000_create_users_table.cr
```

### Example Generated Migration

```crystal
# db/migrations/20231214_120000_create_users_table.cr
class CreateUsersTable < CQL::Migration
  def up
    create_table "users" do |t|
      t.string "name", null: false
      t.string "email", null: false
      t.integer "age"
      t.timestamps
    end

    add_index "users", "email", unique: true
  end

  def down
    drop_table "users"
  end
end
```

### Migration Types

Based on the migration name, different templates are used:

- `create_*_table` - Creates a new table
- `add_*_to_*` - Adds columns to existing table
- `remove_*_from_*` - Removes columns from table
- `add_index_*` - Adds database index

## Scaffold Generator

Generates a complete CRUD resource with all associated files.

### Usage

```bash
azu generate scaffold <name> [field:type] [options]
```

### Examples

```bash
# Complete blog post resource
azu generate scaffold Post title:string content:text published:boolean

# User resource with validations
azu generate scaffold User name:string email:string --validations

# API-only scaffold
azu generate scaffold Product name:string price:decimal --api
```

### Generated Files

The scaffold generator creates:

- Model with validations
- All CRUD endpoints
- Request contracts
- Page components
- HTML templates
- Test files
- Database migration

```
src/models/post.cr
src/endpoints/posts/*.cr (7 files)
src/contracts/posts/*.cr (4 files)
src/pages/posts/*.cr (4 files)
public/templates/posts/*.jinja (4 files)
spec/models/post_spec.cr
spec/endpoints/posts_spec.cr
db/migrations/*_create_posts_table.cr
```

## Advanced Usage

### Custom Templates

You can create custom generator templates:

```bash
# Create custom template directory
mkdir -p ~/.azu/templates/generators/my_generator

# Create template files
echo "Custom template content" > ~/.azu/templates/generators/my_generator/file.cr.ecr
```

### Generator Hooks

Add custom logic before/after generation:

```crystal
# config/generators.cr
Azu::Generators.configure do |config|
  config.before_generate do |generator, options|
    puts "Generating #{generator.name}..."
  end

  config.after_generate do |generator, files|
    puts "Generated #{files.size} files"
  end
end
```

### Batch Generation

Generate multiple components at once:

```bash
# Generate related components
azu generate model User name:string email:string
azu generate endpoint users
azu generate service UserRegistration
azu generate migration create_users_table name:string email:string

# Or use scaffold for everything
azu generate scaffold User name:string email:string
```

## Troubleshooting

### Common Issues

#### File Already Exists

```bash
# Use --force to overwrite
azu generate model User --force

# Or remove existing files first
rm src/models/user.cr
azu generate model User
```

#### Invalid Attribute Syntax

```bash
# Correct format: name:type
azu generate model User name:string email:string

# Not: name=string or name string
```

#### Generator Not Found

```bash
# Check available generators
azu generate --help

# Use correct generator name
azu generate endpoint users  # not controller
```

### Best Practices

1. **Use descriptive names** for generators
2. **Plan your attributes** before generating
3. **Generate tests** alongside code
4. **Use scaffold for rapid prototyping**
5. **Customize generated code** to fit your needs

---

**Related Documentation:**

- [Generators Guide](../generators/README.md) - Detailed generator documentation
- [Project Structure](../getting-started/project-structure.md) - Understanding generated files
- [Development Workflows](../examples/README.md) - Using generators in development
