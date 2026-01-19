# Project Structure

This guide explains the directory structure and file organization of Azu projects created with the CLI. Understanding this structure will help you navigate and develop your applications more effectively.

## Overview

Azu follows a convention-over-configuration approach with a well-defined directory structure that promotes maintainability, testability, and scalability.

## Complete Project Structure

When you create a new Azu project with `azu new my_app`, you get this structure:

```
my_app/
├── 📁 src/                           # Application source code
│   ├── 📄 my_app.cr                  # Main application module
│   ├── 📄 server.cr                  # HTTP server configuration
│   ├── 📁 endpoints/                 # HTTP endpoints (controllers)
│   │   └── 📁 welcome/
│   │       └── 📄 index_endpoint.cr
│   ├── 📁 models/                    # Database models (CQL/Jennifer)
│   │   └── 📄 your_models_goes_here.txt
│   ├── 📁 contracts/                 # Request/response contracts
│   │   └── 📁 welcome/
│   │       └── 📄 index_contract.cr
│   ├── 📁 pages/                     # Page components (views)
│   │   └── 📁 welcome/
│   │       └── 📄 index_page.cr
│   ├── 📁 services/                  # Business logic services
│   ├── 📁 middleware/                # HTTP middleware components
│   ├── 📁 components/                # Reusable live components
│   ├── 📁 validators/                # Custom validation logic
│   ├── 📁 initializers/              # Application startup configuration
│   │   ├── 📄 database.cr
│   │   └── 📄 logger.cr
│   └── 📁 db/                        # Database-related files
│       ├── 📄 schema.cr              # Database schema definition
│       ├── 📄 seed.cr                # Sample data seeding
│       ├── 📁 migrations/            # Database migrations
│       └── 📄 README.md
├── 📁 spec/                          # Test files
│   ├── 📄 my_app_spec.cr             # Main application tests
│   ├── 📄 spec_helper.cr             # Test configuration
│   ├── 📁 endpoints/                 # Endpoint tests
│   ├── 📁 models/                    # Model tests
│   ├── 📁 services/                  # Service tests
│   └── 📁 support/                   # Test support files
├── 📁 public/                        # Static assets
│   ├── 📁 assets/                    # CSS, JS, images
│   │   ├── 📁 css/
│   │   │   ├── 📄 bootstrap.min.css
│   │   │   └── 📄 cover.css
│   │   └── 📁 js/
│   │       └── 📄 bootstrap.min.js
│   └── 📁 templates/                 # Jinja2 templates
│       ├── 📄 layout.jinja           # Base layout template
│       ├── 📁 helpers/               # Partial templates
│       │   └── 📄 _nav.jinja
│       └── 📁 welcome/
│           └── 📄 index_page.jinja
├── 📁 tasks/                         # Custom task definitions
│   └── 📄 taskfile.cr
├── 📁 config/                        # Configuration files
├── 📄 shard.yml                      # Crystal dependencies
├── 📄 README.md                      # Project documentation
└── 📄 LICENSE                        # License file
```

## Directory Details

### `/src` - Application Source Code

The heart of your application where all Crystal source code lives.

#### **Main Files**

- **`my_app.cr`**: Main application module that defines routes, middleware, and configuration
- **`server.cr`**: HTTP server startup and configuration

#### **`/src/endpoints`** - HTTP Endpoints (Controllers)

Contains the HTTP request handlers, similar to controllers in other frameworks.

**Structure:**

```
endpoints/
├── users/
│   ├── index_endpoint.cr     # GET /users
│   ├── show_endpoint.cr      # GET /users/:id
│   ├── new_endpoint.cr       # GET /users/new
│   ├── create_endpoint.cr    # POST /users
│   ├── edit_endpoint.cr      # GET /users/:id/edit
│   ├── update_endpoint.cr    # PUT/PATCH /users/:id
│   └── destroy_endpoint.cr   # DELETE /users/:id
└── api/
    └── v1/
        └── users/
            └── index_endpoint.cr
```

**Example Endpoint:**

```crystal
class Users::IndexEndpoint
  include Azu::Endpoint

  def call(request)
    users = User.all
    index_page = Users::IndexPage.new(users: users)
    index_page.render
  end
end
```

#### **`/src/models`** - Database Models

Contains your data models using CQL ORM or Jennifer ORM.

**Example Model:**

```crystal
require "cql"

class User < CQL::Model
  db_table "users"

  field name : String
  field email : String
  field created_at : Time = Time.utc

  validate :name, presence: true
  validate :email, presence: true, format: EMAIL_REGEX

  has_many :posts, dependent: :destroy
end
```

#### **`/src/contracts`** - Request/Response Contracts

Type-safe request validation and response formatting.

**Example Contract:**

```crystal
struct Users::CreateContract
  include Azu::Request

  validate name, presence: true, length: {min: 2, max: 50}
  validate email, presence: true, format: EMAIL_REGEX
  validate age, numericality: {greater_than: 0, less_than: 150}
end
```

#### **`/src/pages`** - Page Components (Views)

Render HTML responses using templates.

**Example Page:**

```crystal
class Users::IndexPage
  include Azu::Page

  def initialize(@users : Array(User))
  end

  def render
    template("users/index_page.jinja", {
      "users" => @users.map(&.to_h),
      "title" => "All Users"
    })
  end
end
```

#### **`/src/services`** - Business Logic Services

Encapsulate complex business logic following Domain-Driven Design principles.

**Example Service:**

```crystal
class UserRegistrationService
  def initialize(@email : String, @name : String)
  end

  def call
    return Result.error("Email already exists") if User.exists?(email: @email)

    user = User.create!(name: @name, email: @email)
    EmailService.send_welcome_email(user)

    Result.success(user)
  end
end
```

#### **`/src/middleware`** - HTTP Middleware

Custom middleware for request/response processing.

**Example Middleware:**

```crystal
class AuthenticationMiddleware
  include HTTP::Handler

  def call(context)
    if authenticated?(context)
      call_next(context)
    else
      context.response.status = HTTP::Status::UNAUTHORIZED
      context.response.print("Authentication required")
    end
  end

  private def authenticated?(context)
    context.request.headers["Authorization"]?.try(&.starts_with?("Bearer "))
  end
end
```

#### **`/src/components`** - Live Components

Real-time interactive components for dynamic user interfaces.

**Example Component:**

```crystal
class CounterComponent
  include Azu::Component

  def initialize(@count : Int32 = 0)
  end

  def increment
    @count += 1
    update_element("counter-value", @count.to_s)
    broadcast_update({type: "counter_updated", count: @count})
  end

  def render
    %(<div id="counter">
        <span id="counter-value">#{@count}</span>
        <button onclick="counter.increment()">+</button>
      </div>)
  end
end
```

#### **`/src/validators`** - Custom Validators

Reusable validation logic for models and contracts.

**Example Validator:**

```crystal
class EmailValidator < CQL::Validator
  def validate(record, attribute, value)
    unless value.to_s.matches?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
      record.errors.add(attribute, "is not a valid email address")
    end
  end
end
```

#### **`/src/initializers`** - Application Initializers

Configure various aspects of your application during startup.

**Database Initializer (`database.cr`):**

```crystal
require "cql"

CQL.setup do |config|
  config.database_url = ENV.fetch("DATABASE_URL", "postgres://localhost/my_app_development")
  config.log_level = :debug
end
```

#### **`/src/db`** - Database Files

- **`schema.cr`**: Database schema definition
- **`seed.cr`**: Sample data for development
- **`migrations/`**: Database migration files

### `/spec` - Test Files

Mirror the structure of `/src` for organized testing.

**Example Test:**

```crystal
require "./spec_helper"

describe User do
  describe "#valid?" do
    it "is valid with valid attributes" do
      user = User.new(name: "John Doe", email: "john@example.com")
      user.valid?.should be_true
    end

    it "is invalid without a name" do
      user = User.new(email: "john@example.com")
      user.valid?.should be_false
    end
  end
end
```

### `/public` - Static Assets

- **`/assets`**: CSS, JavaScript, images, fonts
- **`/templates`**: Jinja2 templates for HTML rendering

**Template Structure:**

```
templates/
├── layout.jinja              # Base layout
├── helpers/
│   ├── _nav.jinja           # Navigation partial
│   ├── _footer.jinja        # Footer partial
│   └── _flash.jinja         # Flash messages
└── users/
    ├── index_page.jinja     # Users listing
    ├── show_page.jinja      # User details
    └── form.jinja           # User form partial
```

### `/tasks` - Custom Tasks

Define custom command-line tasks for your application.

**Example Task:**

```crystal
# tasks/data_import.cr
task "data:import", "Import data from CSV file" do |args|
  CSV.each_row(File.open("data.csv")) do |row|
    User.create!(name: row[0], email: row[1])
  end
  puts "Data imported successfully!"
end
```

## File Naming Conventions

### General Rules

- **Files**: `snake_case.cr`
- **Classes**: `PascalCase`
- **Methods/Variables**: `snake_case`
- **Constants**: `SCREAMING_SNAKE_CASE`

### Specific Conventions

#### **Endpoints**

- File: `src/endpoints/users/index_endpoint.cr`
- Class: `Users::IndexEndpoint`

#### **Models**

- File: `src/models/user.cr`
- Class: `User`

#### **Services**

- File: `src/services/user_registration_service.cr`
- Class: `UserRegistrationService`

#### **Contracts**

- File: `src/contracts/users/create_contract.cr`
- Struct: `Users::CreateContract`

#### **Pages**

- File: `src/pages/users/index_page.cr`
- Class: `Users::IndexPage`

#### **Components**

- File: `src/components/counter_component.cr`
- Class: `CounterComponent`

#### **Middleware**

- File: `src/middleware/authentication_middleware.cr`
- Class: `AuthenticationMiddleware`

#### **Tests**

- File: `spec/models/user_spec.cr`
- Describes: `User`

## Configuration Files

### `shard.yml` - Dependencies

```yaml
name: my_app
version: 0.1.0

dependencies:
  azu:
    github: azutoolkit/azu
    version: ~> 1.0.0
  cql:
    github: azutoolkit/cql
    version: ~> 0.8.0

development_dependencies:
  ameba:
    github: crystal-ameba/ameba
    version: ~> 1.4.0
```

### Environment Configuration

Create environment-specific configuration:

```crystal
# config/environments/development.cr
Azu.configure do |config|
  config.debug = true
  config.log_level = :debug
  config.host = "localhost"
  config.port = 3000
end

# config/environments/production.cr
Azu.configure do |config|
  config.debug = false
  config.log_level = :info
  config.host = "0.0.0.0"
  config.port = ENV.fetch("PORT", "8080").to_i
end
```

## Best Practices

### Organization

1. **Group related files** in subdirectories
2. **Mirror test structure** in `/spec`
3. **Use descriptive names** for files and classes
4. **Keep files focused** on single responsibilities

### Dependencies

1. **Explicit imports** in each file
2. **Group imports** by source (stdlib, shards, local)
3. **Avoid circular dependencies**

### Example Import Organization:

```crystal
# Standard library imports
require "json"
require "uuid"

# Third-party shard imports
require "cql"
require "azu"

# Local imports
require "../models/user"
require "../contracts/base_contract"
```

### Testing

1. **Test files mirror source structure**
2. **Use descriptive test names**
3. **Group related tests** in nested `describe` blocks
4. **Test both success and failure scenarios**

## Working with the Structure

### Adding New Features

1. **Generate scaffolding**: `azu generate scaffold Feature name:string`
2. **Implement business logic** in services
3. **Add validations** in models and contracts
4. **Create custom middleware** for cross-cutting concerns
5. **Write comprehensive tests**

### Refactoring

1. **Extract shared logic** into services
2. **Create reusable components** for common UI patterns
3. **Use modules** for shared behavior
4. **Keep controllers thin** by moving logic to services

---

This structure provides a solid foundation for building maintainable, testable, and scalable Azu applications. The conventions help maintain consistency across projects and make it easier for team members to navigate the codebase.

**Next Steps:**

- [Command Reference](../commands/README.md) - Learn about CLI commands
- [Generators Guide](../generators/README.md) - Generate code efficiently
- [Examples](../examples/README.md) - Common development patterns
