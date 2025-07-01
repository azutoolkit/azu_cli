# Azu Web Framework Integration

The Azu CLI provides native integration with the Azu web framework, offering seamless development experience and powerful code generation capabilities.

## Overview

Azu framework integration provides:

- **Native Code Generation**: Framework-aware code generation
- **Project Structure**: Standardized Azu project layout
- **Development Tools**: Hot reloading and debugging support
- **Deployment**: Framework-optimized deployment strategies
- **Testing**: Integrated testing with framework patterns

## Framework Architecture

### Azu Framework Components

```
Azu Framework
├── Web Layer (HTTP/HTTPS)
├── Routing System
├── Middleware Stack
├── Template Engine (Jinja)
├── Database Layer (CQL)
├── Authentication (Authly)
├── Background Jobs (JoobQ)
└── Configuration System
```

### CLI Integration Points

```
Azu CLI
├── Project Generation
├── Code Generators
├── Database Management
├── Development Server
├── Testing Framework
├── Deployment Tools
└── Configuration Management
```

## Project Structure

### Standard Azu Project Layout

```
myapp/
├── azu.yml                 # Azu CLI configuration
├── shard.yml              # Crystal dependencies
├── src/
│   ├── main.cr            # Application entry point
│   ├── server.cr          # Server configuration
│   ├── contracts/         # Request/response contracts
│   ├── endpoints/         # HTTP endpoints
│   ├── models/            # CQL models
│   ├── pages/             # Jinja templates
│   ├── services/          # Business logic
│   ├── middlewares/       # HTTP middlewares
│   ├── components/        # Reusable components
│   ├── initializers/      # Application initialization
│   └── db/
│       ├── migrations/    # Database migrations
│       ├── schema.cr      # Database schema
│       └── seed.cr        # Seed data
├── public/                # Static assets
├── spec/                  # Tests
└── docs/                  # Documentation
```

## Framework-Specific Commands

### Project Management

```bash
# Create new Azu project
azu new myapp --framework=azu

# Initialize existing project
azu init --framework=azu

# Update framework dependencies
azu framework update
```

### Code Generation

```bash
# Generate endpoint with framework patterns
azu generate endpoint users --framework=azu

# Generate model with CQL integration
azu generate model User --framework=azu

# Generate service with framework conventions
azu generate service UserService --framework=azu
```

### Development

```bash
# Start development server with hot reload
azu serve --framework=azu --reload

# Run tests with framework patterns
azu test --framework=azu

# Debug application
azu debug --framework=azu
```

## Framework Configuration

### Azu-Specific Settings

```yaml
# azu.yml
framework:
  name: "azu"
  version: "latest"

  # Framework components
  components:
    template_engine: "jinja"
    orm: "cql"
    authentication: "authly"
    background_jobs: "joobq"

  # Development settings
  development:
    hot_reload: true
    debug_mode: true
    log_level: "debug"

  # Production settings
  production:
    workers: 4
    log_level: "warn"
    ssl: true
```

### Environment Configuration

```crystal
# src/initializers/config.cr
Azu.configure do |config|
  # Database configuration
  config.database_url = ENV["AZU_DATABASE_URL"]? || "postgresql://localhost/myapp"

  # Template engine
  config.template_engine = :jinja

  # Authentication
  config.auth.provider = :authly
  config.auth.secret_key = ENV["AZU_AUTH_SECRET"]

  # Background jobs
  config.jobs.provider = :joobq
  config.jobs.redis_url = ENV["AZU_REDIS_URL"]
end
```

## Code Generation Patterns

### Endpoint Generation

```crystal
# Generated endpoint with Azu patterns
class UsersEndpoint < Azu::Endpoint
  # Framework-specific imports
  include Azu::Contracts
  include Azu::Authentication

  # Route definition
  route "/users", methods: [:get, :post]

  # Contract validation
  contract CreateUserContract

  # Authentication
  authenticate :user

  # Authorization
  authorize :can_manage_users

  # Handler methods
  def index
    users = User.all
    render json: users
  end

  def create
    user = User.create(contract.data)
    render json: user, status: 201
  end
end
```

### Model Generation

```crystal
# Generated model with CQL integration
class User < CQL::Model
  # Framework-specific configuration
  table "users"

  # Field definitions
  field id : UUID = UUID.random
  field email : String
  field name : String
  field created_at : Time = Time.utc
  field updated_at : Time = Time.utc

  # Validations
  validates :email, presence: true, format: :email
  validates :name, presence: true, length: {min: 2, max: 100}

  # Associations
  has_many :posts
  belongs_to :organization

  # Framework-specific methods
  def self.authenticate(email : String, password : String)
    # Authentication logic
  end
end
```

### Service Generation

```crystal
# Generated service with framework patterns
class UserService < Azu::Service
  # Dependency injection
  inject :user_repository
  inject :email_service

  # Service methods
  def create_user(data : CreateUserData) : User
    user = User.new(data)

    if user.save
      @email_service.send_welcome_email(user)
      user
    else
      raise Azu::ValidationError.new(user.errors)
    end
  end

  def update_user(id : UUID, data : UpdateUserData) : User
    user = User.find(id)
    user.assign_attributes(data)

    if user.save
      user
    else
      raise Azu::ValidationError.new(user.errors)
    end
  end
end
```

## Development Workflow

### Hot Reloading

```bash
# Start development server with hot reload
azu serve --reload --framework=azu

# Watch specific directories
azu serve --reload --watch=src/endpoints,src/models
```

### Debugging

```crystal
# Debug configuration
Azu.configure do |config|
  config.debug = true
  config.log_level = :debug
end

# Debug endpoints
class DebugEndpoint < Azu::Endpoint
  route "/debug"

  def index
    # Debug information
    debug_info = {
      environment: Azu.env,
      database: Azu.database.status,
      cache: Azu.cache.status
    }

    render json: debug_info
  end
end
```

### Testing

```crystal
# Framework-specific test helpers
require "azu/test"

class UserEndpointTest < Azu::Test
  # Test database setup
  setup do
    Database.clean
  end

  # Test endpoint
  test "creates user" do
    post "/users", json: {
      email: "test@example.com",
      name: "Test User"
    }

    assert_response 201
    assert User.find_by(email: "test@example.com")
  end
end
```

## Database Integration

### CQL ORM Integration

```crystal
# Database configuration
Azu.configure do |config|
  config.database do |db|
    db.adapter = :postgresql
    db.url = ENV["AZU_DATABASE_URL"]
    db.pool_size = 5
    db.timeout = 5
  end
end

# Migration generation
class CreateUsers < CQL::Migration
  def up
    create_table :users do |t|
      t.uuid :id, primary_key: true
      t.string :email, unique: true
      t.string :name
      t.timestamps
    end
  end

  def down
    drop_table :users
  end
end
```

### Database Commands

```bash
# Create database
azu db create --framework=azu

# Run migrations
azu db migrate --framework=azu

# Seed database
azu db seed --framework=azu

# Reset database
azu db reset --framework=azu
```

## Authentication Integration

### Authly Integration

```crystal
# Authentication configuration
Azu.configure do |config|
  config.auth do |auth|
    auth.provider = :authly
    auth.secret_key = ENV["AZU_AUTH_SECRET"]
    auth.session_timeout = 24.hours
  end
end

# Authentication middleware
class AuthMiddleware < Azu::Middleware
  def call(context)
    # Authentication logic
    user = Authly.authenticate(context.request)

    if user
      context.set(:current_user, user)
      call_next(context)
    else
      context.response.status = 401
      context.response.body = "Unauthorized"
    end
  end
end
```

## Background Jobs Integration

### JoobQ Integration

```crystal
# Background jobs configuration
Azu.configure do |config|
  config.jobs do |jobs|
    jobs.provider = :joobq
    jobs.redis_url = ENV["AZU_REDIS_URL"]
    jobs.workers = 4
  end
end

# Job definition
class SendWelcomeEmailJob < Azu::Job
  def perform(user_id : UUID)
    user = User.find(user_id)
    EmailService.send_welcome_email(user)
  end
end

# Enqueue job
SendWelcomeEmailJob.perform_async(user.id)
```

## Deployment

### Production Configuration

```yaml
# azu.yml
framework:
  production:
    workers: 4
    log_level: "warn"
    ssl: true
    compression: true

  deployment:
    platform: "docker"
    build_optimization: true
    health_check: "/health"
```

### Docker Integration

```dockerfile
# Dockerfile
FROM crystallang/crystal:latest

WORKDIR /app
COPY . .

RUN shards install
RUN crystal build --release src/main.cr

ENV AZU_ENV=production
ENV AZU_WORKERS=4

EXPOSE 8080
CMD ["./main"]
```

### Health Checks

```crystal
# Health check endpoint
class HealthEndpoint < Azu::Endpoint
  route "/health"

  def index
    health_status = {
      status: "healthy",
      timestamp: Time.utc,
      database: database_healthy?,
      cache: cache_healthy?
    }

    render json: health_status
  end

  private def database_healthy?
    Database.connected?
  rescue
    false
  end
end
```

## Performance Optimization

### Framework Optimizations

```crystal
# Performance configuration
Azu.configure do |config|
  # Caching
  config.cache.provider = :redis
  config.cache.ttl = 1.hour

  # Compression
  config.compression.enabled = true
  config.compression.level = 6

  # Static assets
  config.static.enabled = true
  config.static.cache_control = "public, max-age=31536000"
end
```

### Monitoring

```crystal
# Performance monitoring
class PerformanceMiddleware < Azu::Middleware
  def call(context)
    start_time = Time.monotonic

    call_next(context)

    duration = Time.monotonic - start_time
    Azu.logger.info "Request completed in #{duration.total_milliseconds}ms"
  end
end
```

## Troubleshooting

### Common Issues

**Framework Version Mismatch**: Ensure CLI and framework versions are compatible.

**Database Connection Issues**: Verify database configuration and connectivity.

**Template Engine Errors**: Check Jinja template syntax and file paths.

**Authentication Problems**: Validate Authly configuration and secret keys.

### Debug Commands

```bash
# Check framework status
azu framework status

# Validate framework configuration
azu framework validate

# Test framework components
azu framework test

# Show framework information
azu framework info
```

## Best Practices

### Framework Usage

1. **Version Management**: Keep CLI and framework versions in sync
2. **Configuration**: Use environment-specific configurations
3. **Testing**: Write comprehensive tests for all endpoints
4. **Documentation**: Document custom framework extensions

### Performance

1. **Caching**: Implement appropriate caching strategies
2. **Database**: Optimize database queries and connections
3. **Assets**: Use asset compression and CDN for static files
4. **Monitoring**: Monitor application performance and errors

### Security

1. **Authentication**: Implement proper authentication and authorization
2. **Validation**: Validate all user inputs
3. **HTTPS**: Use HTTPS in production
4. **Secrets**: Manage secrets securely using environment variables

## Migration from Other Frameworks

### From Rails

```bash
# Generate migration plan
azu migration plan --from=rails --to=azu

# Convert models
azu migration convert --input=rails_models --output=azu_models

# Convert controllers
azu migration convert --input=rails_controllers --output=azu_endpoints
```

### From Other Crystal Frameworks

```bash
# Analyze existing project
azu analyze --framework=existing --target=azu

# Generate migration guide
azu migration guide --from=existing --to=azu
```

## Support and Resources

### Documentation

- [Azu Framework Documentation](https://github.com/azutoolkit/azu)
- [CQL ORM Documentation](https://github.com/azutoolkit/cql)
- [Authly Documentation](https://github.com/azutoolkit/authly)
- [JoobQ Documentation](https://github.com/azutoolkit/joobq)

### Community

- **Discord**: Join the Azu community
- **GitHub**: Report issues and contribute
- **Examples**: Sample projects and patterns
- **Tutorials**: Step-by-step guides

### Getting Help

- **Documentation**: Comprehensive framework guides
- **Community Support**: Ask questions in Discord
- **Issue Tracking**: Report bugs on GitHub
- **Contributing**: Contribute to framework development
