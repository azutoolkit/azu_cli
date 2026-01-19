# Reference Documentation

This section provides comprehensive reference documentation for Azu CLI, including CLI options, template variables, naming conventions, and other technical details.

## Available References

### 1. [CLI Options Reference](cli-options.md)

Complete reference for all Azu CLI commands, options, and flags.

**Includes:**

- Command syntax and usage
- Available options and flags
- Environment variables
- Exit codes
- Examples for each command

### 2. [Template Variables](template-variables.md)

Reference for all variables available in ECR templates.

**Includes:**

- Built-in template variables
- Custom variable definitions
- Variable scoping and context
- Template helper methods
- Conditional logic examples

### 3. [File Naming Conventions](naming-conventions.md)

Conventions and rules for naming files, classes, and methods.

**Includes:**

- File naming patterns
- Class naming conventions
- Method naming standards
- Database naming rules
- URL and route naming

### 4. [Directory Structure](directory-structure.md)

Complete reference for Azu project directory structure.

**Includes:**

- Standard directory layout
- File organization rules
- Custom directory configurations
- Asset management
- Configuration file locations

### 5. [Crystal Language Guide](crystal-guide.md)

Crystal language-specific patterns and best practices for Azu development.

**Includes:**

- Crystal syntax patterns
- Type system usage
- Memory management
- Performance optimization
- Common idioms

## Quick Reference

### Common Commands

```bash
# Project management
azu new <project-name>              # Create new project
azu init                            # Initialize existing project
azu serve                           # Start development server

# Code generation
azu generate model <name>           # Generate model
azu generate endpoint <name>        # Generate endpoint
azu generate scaffold <name>        # Generate complete resource

# Database operations
azu db create                       # Create database
azu db migrate                      # Run migrations
azu db rollback                     # Rollback migrations
azu db seed                         # Seed database

# Development
azu dev                             # Development tools
azu help                            # Show help
azu version                         # Show version
```

### Available Generators

```bash
# Core generators
azu generate endpoint <name>        # HTTP endpoint with contract and page
azu generate model <name>           # CQL Active Record model
azu generate service <name>         # DDD application service
azu generate middleware <name>      # HTTP middleware component
azu generate contract <name>        # Request/response contract
azu generate page <name>            # Page component (view)
azu generate component <name>       # Live interactive component with real-time features
azu generate validator <name>       # Custom CQL validator with validation logic
azu generate migration <name>       # Database migration file
azu generate scaffold <name>        # Complete resource with CRUD operations

# Generator aliases
azu generate e <name>               # Alias for endpoint
azu generate m <name>               # Alias for model
azu generate s <name>               # Alias for service
azu generate mw <name>              # Alias for middleware
azu generate c <name>               # Alias for contract
azu generate p <name>               # Alias for page
azu generate comp <name>            # Alias for component
azu generate val <name>             # Alias for validator
azu generate v <name>               # Alias for validator
azu generate mig <name>             # Alias for migration
```

### Template Variables

```crystal
# Common template variables
@name                               # Resource name (e.g., "user")
@name.camelcase                     # CamelCase (e.g., "User")
@name.underscore                    # snake_case (e.g., "user")
@name.pluralize                     # Plural form (e.g., "users")
@name.humanize                      # Human readable (e.g., "User")

# Generator-specific variables
@attributes                         # Array of attributes
@description                        # Resource description
@template                          # Template type
@options                           # Generator options
```

### File Naming Patterns

```
# Models
src/models/user.cr                  # User model
src/models/post.cr                  # Post model

# Endpoints
src/endpoints/users/index_endpoint.cr
src/endpoints/users/show_endpoint.cr
src/endpoints/users/create_endpoint.cr

# Pages
src/pages/users/index_page.cr
src/pages/users/show_page.cr

# Contracts
src/contracts/users/contract.cr

# Migrations
src/db/migrations/20240115000000_create_users.cr
```

### Directory Structure

```
project/
├── src/
│   ├── models/                    # Database models
│   ├── endpoints/                 # API endpoints
│   ├── pages/                     # Web pages
│   ├── contracts/                 # Validation contracts
│   ├── services/                  # Business logic
│   ├── middleware/                # HTTP middleware
│   ├── components/                # UI components
│   ├── db/                        # Database files
│   │   ├── migrations/            # Migration files
│   │   ├── schema.cr              # Database schema
│   │   └── seed.cr                # Seed data
│   └── initializers/              # App initialization
├── public/                        # Static assets
├── spec/                          # Test files
├── config/                        # Configuration
└── docs/                          # Documentation
```

## Environment Variables

### Required Variables

```bash
# Database
DATABASE_URL=postgresql://localhost/database_name

# Application
APP_SECRET=your-secret-key-here
APP_ENV=development|test|production
```

### Optional Variables

```bash
# Server
AZU_HOST=0.0.0.0
AZU_PORT=4000

# Database
AZU_DB_HOST=localhost
AZU_DB_PORT=5432
AZU_DB_USER=postgres
AZU_DB_PASSWORD=
AZU_DB_NAME=database_name

# Development
AZU_DEBUG=true|false
AZU_VERBOSE=true|false
AZU_QUIET=true|false
AZU_ENV=development|test|production

# Templates and Output
AZU_TEMPLATES_PATH=./src/azu_cli/templates
AZU_OUTPUT_PATH=.
```

## Configuration Reference

### Base Configuration

```yaml
# config/azu.yml
development:
  general:
    project_name: My App
    database_adapter: postgresql
    template_engine: jinja
    colored_output: true

  database:
    url: <%= ENV["DATABASE_URL"] %>
    host: <%= ENV["AZU_DB_HOST"] || "localhost" %>
    port: <%= ENV["AZU_DB_PORT"] || 5432 %>
    user: <%= ENV["AZU_DB_USER"] || "postgres" %>
    password: <%= ENV["AZU_DB_PASSWORD"] || "" %>

  server:
    host: <%= ENV["AZU_HOST"] || "localhost" %>
    port: <%= ENV["AZU_PORT"] || 4000 %>
    watch: true
    rebuild: true

  logging:
    level: info
    format: default
```

### Environment-Specific

```yaml
# config/azu.yml
development:
  logging:
    level: debug

production:
  logging:
    level: info
  server:
    watch: false
    rebuild: false
```

## Generator Reference

### Model Generator

```bash
# Basic model
azu generate model User name:string email:string

# Model with options
azu generate model Post title:string content:text author_id:integer --description "Blog post model"

# Model with validations
azu generate model Product name:string price:decimal active:boolean --validations "name:required,price:min:0"
```

### Endpoint Generator

```bash
# Basic endpoint
azu generate endpoint Users

# Endpoint with specific actions
azu generate endpoint Users index show create

# Endpoint with options
azu generate endpoint Users --skip-tests --skip-routes
```

### Component Generator

```bash
# Basic component
azu generate component Counter

# Component with attributes
azu generate component UserCard name:string email:string avatar:string

# Component with events and WebSocket
azu generate component ChatRoom --websocket event:message event:join
```

### Validator Generator

```bash
# Basic validator
azu generate validator EmailValidator

# Validator with type
azu generate validator EmailValidator type:email

# Validator for specific model
azu generate validator UserValidator model:User type:custom
```

### Scaffold Generator

```bash
# Basic scaffold
azu generate scaffold User name:string email:string

# Scaffold with attributes
azu generate scaffold Post title:string content:text author_id:integer published:boolean

# Scaffold with options
azu generate scaffold Product name:string price:decimal --skip-tests
```

## Database Reference

### Migration Commands

```bash
# Create migration
azu db new_migration CreateUsers

# Run migrations
azu db migrate

# Rollback migrations
azu db rollback --steps 1

# Check status
azu db status

# Reset database
azu db reset --force
```

### Migration Patterns

```crystal
# Create table
class CreateUsers < CQL::Migration(20240115000000)
  def up
    schema.create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.timestamps
    end
  end

  def down
    schema.drop_table :users
  end
end

# Add column
class AddPhoneToUsers < CQL::Migration(20240115000001)
  def up
    schema.alter_table :users do |t|
      t.add_column :phone, String, null: true
    end
  end

  def down
    schema.alter_table :users do |t|
      t.remove_column :phone
    end
  end
end
```

### Model Patterns

```crystal
# Basic model
class User < CQL::Model
  table :users

  column :name, String
  column :email, String

  validates :name, presence: true
  validates :email, presence: true, format: /^[^@]+@[^@]+\.[^@]+$/
end

# Model with associations
class Post < CQL::Model
  table :posts

  column :title, String
  column :content, Text
  column :author_id, Int64

  belongs_to :author, User
  has_many :comments, Comment
end
```

## Development Server Reference

### Serve Command

```bash
# Start development server
azu serve

# Custom host and port
azu serve --host 0.0.0.0 --port 4000

# Disable file watching
azu serve --no-watch

# Verbose output
azu serve --verbose
```

### File Watching

The development server watches for changes in:

- `src/**/*.cr` - Crystal source files
- `config/**/*.cr` - Configuration files
- `public/templates/**/*.jinja` - Jinja templates
- `public/templates/**/*.html` - HTML templates
- `public/assets/**/*.css` - CSS files
- `public/assets/**/*.js` - JavaScript files

### Hot Reloading

- **Crystal files**: Automatic rebuild and restart
- **Template files**: Manual browser refresh required
- **Static files**: Manual browser refresh required

## Testing Reference

### Test Structure

```crystal
# spec/models/user_spec.cr
describe User do
  describe "validations" do
    it "is valid with correct attributes" do
      user = User.new(name: "John", email: "john@example.com")
      user.valid?.should be_true
    end
  end
end

# spec/endpoints/users_spec.cr
describe Users::IndexEndpoint do
  it "returns all users" do
    user = User.create(name: "John", email: "john@example.com")

    get "/users"

    response.status_code.should eq(200)
    response.body.should contain("John")
  end
end
```

### Test Commands

```bash
# Run all tests
crystal spec

# Run specific test file
crystal spec spec/models/user_spec.cr

# Run with coverage
crystal spec --coverage

# Run with verbose output
crystal spec --verbose
```

## Deployment Reference

### Build Commands

```bash
# Development build
crystal build src/main.cr

# Production build
crystal build --release src/main.cr

# Build with specific target
crystal build --release --static src/main.cr
```

### Docker Reference

```dockerfile
# Dockerfile
FROM crystallang/crystal:1.16.0-alpine

WORKDIR /app

COPY shard.yml shard.lock ./
RUN shards install

COPY . .
RUN crystal build --release src/main.cr

CMD ["./main"]
```

### Environment Setup

```bash
# Production environment variables
export AZU_ENV=production
export DATABASE_URL=postgresql://user:pass@host/db
export APP_SECRET=your-secret-key
export AZU_HOST=0.0.0.0
export AZU_PORT=4000
```

## Performance Reference

### Compilation Optimization

```bash
# Optimize compilation
crystal build --release --no-debug src/main.cr

# Parallel compilation
crystal build --release --threads 4 src/main.cr

# Static linking
crystal build --release --static src/main.cr
```

### Runtime Optimization

```crystal
# Use appropriate data structures
users = Set(User).new  # For unique collections
user_map = Hash(String, User).new  # For lookups

# Minimize allocations
String.build do |str|
  str << "Hello, " << name
end

# Use lazy evaluation
users.select(&.active?).map(&.name)
```

## Security Reference

### Input Validation

```crystal
# Contract validation
class UserContract < Azu::Contract
  field :name, String, required: true, min_length: 2
  field :email, String, required: true, format: /^[^@]+@[^@]+\.[^@]+$/
  field :age, Int32, min: 18, max: 120
end

# Model validation
class User < CQL::Model
  validates :name, presence: true, length: {minimum: 2}
  validates :email, presence: true, format: /^[^@]+@[^@]+\.[^@]+$/
end
```

### Authentication

```crystal
# JWT authentication
class JwtAuthMiddleware
  def call(context : Azu::Context) : Azu::Context
    token = extract_token(context.request)

    unless valid_token?(token)
      context.response.status_code = 401
      return context
    end

    context.current_user = decode_user(token)
    call_next(context)
  end
end
```

## Troubleshooting Reference

### Common Issues

```bash
# Database connection
Error: Database connection failed
Solution: Check DATABASE_URL and database status

# Compilation errors
Error: Compilation failed
Solution: Check Crystal version and dependencies

# Port conflicts
Error: Port already in use
Solution: Use different port or kill existing process

# Missing dependencies
Error: Shard not found
Solution: Run shards install
```

### Debug Commands

```bash
# Enable debug mode
export AZU_DEBUG=true

# Verbose output
azu serve --verbose

# Check configuration
azu help

# Validate setup
azu init
```

## Dependencies

### Core Dependencies

```yaml
# shard.yml
dependencies:
  teeplate:
    github: amberframework/teeplate
    version: ~> 0.11.2

  topia:
    github: azutoolkit/topia

  cadmium_inflector:
    github: cadmiumcr/inflector

  pg:
    github: will/crystal-pg

  cql:
    github: azutoolkit/cql

  readline:
    github: crystal-lang/crystal-readline
```

### Development Dependencies

```yaml
development_dependencies:
  spec2:
    github: waterlink/spec2.cr
```

## Related Documentation

- [Getting Started](getting-started/quick-start.md) - Quick start guide
- [Command Reference](commands/README.md) - Detailed command documentation
- [Generators](generators/README.md) - Generator documentation
- [Workflows](examples/README.md) - Development workflows
- [Architecture](architecture/README.md) - System architecture
