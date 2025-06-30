# Development Workflows

This guide covers common development patterns and workflows for building applications with Azu CLI. Learn how to structure your development process, from initial setup to deployment.

## Overview

Azu CLI provides a comprehensive set of tools and workflows to streamline your development process. This guide covers:

- **Rapid Prototyping** - Quick iteration and experimentation
- **API-First Development** - Building APIs before frontend
- **Domain-Driven Design** - Organizing code around business domains
- **Test-Driven Development** - Writing tests first
- **Component-Based Workflows** - Building reusable components
- **Development Environment Workflows** - Local development setup
- **Database Workflows** - Managing database changes
- **Testing Workflows** - Comprehensive testing strategies
- **Deployment Workflows** - Getting to production

## Rapid Prototyping

### Quick Start Workflow

```bash
# 1. Create new project
azu new my_app --database sqlite

# 2. Navigate to project
cd my_app

# 3. Start development server
azu serve

# 4. Generate your first resource
azu generate scaffold Post title:string content:text

# 5. Setup database
azu db:create
azu db:migrate
azu db:seed

# 6. Visit your app
# http://localhost:3000/posts
```

### Iterative Development

```bash
# Add new features quickly
azu generate model Comment content:text post:references
azu generate endpoint posts/comments
azu generate page posts/show

# Test changes immediately
azu serve

# Refactor and improve
azu generate service PostService
azu generate middleware AuthMiddleware
```

### Prototype to Production

```bash
# Start with SQLite for prototyping
azu new prototype --database sqlite

# Switch to PostgreSQL for production
azu new production --database postgres

# Migrate data and code
# (See migration guides for details)
```

## API-First Development

### API Development Workflow

```bash
# 1. Create API-only project
azu new my_api --type api --database postgres

# 2. Generate API models
azu generate model User name:string email:string --validations
azu generate model Post title:string content:text user:references

# 3. Generate API endpoints
azu generate endpoint api/v1/users --api
azu generate endpoint api/v1/posts --api

# 4. Test API endpoints
curl http://localhost:3000/api/v1/users
curl -X POST http://localhost:3000/api/v1/posts \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","content":"Content"}'
```

### API Versioning Strategy

```bash
# Generate versioned APIs
azu generate endpoint api/v1/users --api
azu generate endpoint api/v2/users --api

# Maintain backward compatibility
# v1 endpoints remain stable
# v2 endpoints can introduce breaking changes
```

### API Documentation

```bash
# Generate OpenAPI documentation
azu generate docs api

# Serve API documentation
azu serve --docs

# Visit: http://localhost:3000/docs
```

## Domain-Driven Design (DDD)

### Domain Structure

```
src/
├── domains/
│   ├── users/
│   │   ├── models/
│   │   ├── services/
│   │   ├── contracts/
│   │   └── endpoints/
│   ├── posts/
│   │   ├── models/
│   │   ├── services/
│   │   ├── contracts/
│   │   └── endpoints/
│   └── comments/
│       ├── models/
│       ├── services/
│       ├── contracts/
│       └── endpoints/
```

### Domain Generation

```bash
# Generate complete domain
azu generate domain users
# Creates: models, services, contracts, endpoints

# Generate domain with specific components
azu generate domain posts --skip-services
azu generate domain comments --api-only
```

### Domain Services

```crystal
# src/domains/users/services/user_registration_service.cr
class UserRegistrationService
  def self.register(attributes : Hash)
    user = User.new(attributes)

    if user.save
      UserMailer.welcome_email(user).deliver
      UserAnalytics.track_registration(user)
      user
    else
      user
    end
  end
end
```

## Test-Driven Development (TDD)

### TDD Workflow

```bash
# 1. Write failing test
# spec/models/user_spec.cr
describe User do
  it "requires email" do
    user = User.new(name: "John")
    user.valid?.should be_false
    user.errors[:email].should contain("can't be blank")
  end
end

# 2. Run test (should fail)
crystal spec spec/models/user_spec.cr

# 3. Generate model with minimal implementation
azu generate model user name:string email:string

# 4. Add validation to make test pass
# src/models/user.cr
validates :email, presence: true

# 5. Run test (should pass)
crystal spec spec/models/user_spec.cr

# 6. Refactor and repeat
```

### Test Structure

```bash
# Generate tests for all components
azu generate model user --skip-tests=false
azu generate endpoint users --skip-tests=false
azu generate service UserService --skip-tests=false

# Run specific test suites
crystal spec spec/models/
crystal spec spec/endpoints/
crystal spec spec/services/

# Run with coverage
crystal spec --coverage
```

### Continuous Testing

```bash
# Watch for changes and run tests
crystal spec --watch

# Run tests in parallel
crystal spec --parallel

# Generate test reports
crystal spec --format=json > test-results.json
```

## Component-Based Workflows

### Component Development

```bash
# Generate reusable components
azu generate component UserCard
azu generate component PostList
azu generate component CommentForm

# Generate with props
azu generate component UserCard --props user:User,show_actions:bool
```

### Component Structure

```crystal
# src/components/user_card_component.cr
class UserCardComponent < Azu::Component
  prop user : User
  prop show_actions : Bool = false

  def render
    div class: "user-card" do
      h3 user.name
      p user.email

      if show_actions
        div class: "actions" do
          link_to "Edit", "/users/#{user.id}/edit"
          link_to "Delete", "/users/#{user.id}", method: :delete
        end
      end
    end
  end
end
```

### Component Testing

```crystal
# spec/components/user_card_component_spec.cr
describe UserCardComponent do
  it "renders user information" do
    user = User.new(name: "John", email: "john@example.com")
    component = UserCardComponent.new(user: user)

    html = component.render
    html.should contain("John")
    html.should contain("john@example.com")
  end

  it "shows actions when show_actions is true" do
    user = User.new(name: "John", email: "john@example.com")
    component = UserCardComponent.new(user: user, show_actions: true)

    html = component.render
    html.should contain("Edit")
    html.should contain("Delete")
  end
end
```

## Development Environment Workflows

### Local Development Setup

```bash
# 1. Install dependencies
shards install

# 2. Setup database
azu db:setup

# 3. Start development server
azu serve

# 4. In another terminal, run tests
crystal spec --watch

# 5. In another terminal, run linter
crystal tool format --check
ameba
```

### Environment Configuration

```bash
# Development environment
export AZU_ENV=development
export DATABASE_URL="postgres://localhost/my_app_development"

# Test environment
export AZU_ENV=test
export DATABASE_URL="postgres://localhost/my_app_test"

# Staging environment
export AZU_ENV=staging
export DATABASE_URL="postgres://staging-server/my_app_staging"
```

### Development Tools Integration

```bash
# VS Code integration
# .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Azu Server",
      "type": "crystal",
      "request": "launch",
      "program": "${workspaceFolder}/src/main.cr",
      "args": ["serve", "--port", "3000"]
    }
  ]
}

# Git hooks
# .git/hooks/pre-commit
#!/bin/sh
crystal tool format --check
crystal spec
```

## Database Workflows

### Schema Evolution

```bash
# 1. Make changes to model
# src/models/user.cr
column phone : String?

# 2. Generate migration
azu generate migration add_phone_to_users phone:string

# 3. Review migration
cat db/migrations/*_add_phone_to_users.cr

# 4. Run migration
azu db:migrate

# 5. Test changes
crystal spec spec/models/user_spec.cr
```

### Data Migration

```bash
# Generate data migration
azu generate migration update_user_emails

# Edit migration
# db/migrations/*_update_user_emails.cr
def up
  execute "UPDATE users SET email = LOWER(email)"
end

def down
  # Cannot safely reverse this operation
end
```

### Database Rollback

```bash
# Rollback last migration
azu db:rollback

# Rollback multiple migrations
azu db:rollback --steps 3

# Rollback to specific version
azu db:rollback --version 20231201000001
```

## Testing Workflows

### Test Organization

```bash
spec/
├── models/
│   ├── user_spec.cr
│   ├── post_spec.cr
│   └── comment_spec.cr
├── endpoints/
│   ├── users/
│   │   ├── index_endpoint_spec.cr
│   │   └── create_endpoint_spec.cr
│   └── posts/
│       ├── index_endpoint_spec.cr
│       └── show_endpoint_spec.cr
├── services/
│   ├── user_service_spec.cr
│   └── post_service_spec.cr
└── integration/
    ├── api_spec.cr
    └── web_spec.cr
```

### Test Types

```bash
# Unit tests (fast, isolated)
crystal spec spec/models/
crystal spec spec/services/

# Integration tests (slower, with database)
crystal spec spec/endpoints/
crystal spec spec/integration/

# System tests (slowest, full stack)
crystal spec spec/system/
```

### Test Data Management

```bash
# Use factories for test data
# spec/factories/user_factory.cr
class UserFactory
  def self.create(attributes = {} of String => String)
    User.create!({
      "name" => "Test User",
      "email" => "test@example.com"
    }.merge(attributes))
  end
end

# Use in tests
user = UserFactory.create(name: "John", email: "john@example.com")
```

## Deployment Workflows

### Production Preparation

```bash
# 1. Build for production
crystal build src/main.cr --release -o bin/my_app

# 2. Setup production database
azu db:create --env production
azu db:migrate --env production

# 3. Seed production data
azu db:seed --env production

# 4. Test production build
./bin/my_app serve --env production
```

### Deployment Strategies

```bash
# Blue-Green Deployment
# Deploy to staging first
azu deploy --env staging

# Test staging deployment
curl https://staging.myapp.com/health

# Deploy to production
azu deploy --env production

# Rollback if needed
azu deploy --env production --rollback
```

### Monitoring and Logging

```bash
# Enable production logging
export AZU_LOG_LEVEL=info
export AZU_LOG_FILE=/var/log/my_app.log

# Health checks
curl https://myapp.com/health

# Performance monitoring
curl https://myapp.com/metrics
```

## Performance Optimization

### Database Optimization

```crystal
# Use includes to avoid N+1 queries
posts = Post.includes(:user, :comments).all

# Use scopes for common queries
User.active.recent.limit(10)

# Use counter_cache for counts
belongs_to :user, User, counter_cache: :posts_count
```

### Caching Strategies

```crystal
# Fragment caching
def render
  cache "user_#{user.id}" do
    render "users/show_page", user: user
  end
end

# Query caching
def self.recent_posts
  cache "recent_posts" do
    Post.order(created_at: :desc).limit(10)
  end
end
```

### Background Jobs

```bash
# Generate background job
azu generate job SendWelcomeEmail

# Queue job
SendWelcomeEmail.perform_async(user_id: user.id)

# Process jobs
azu jobs:work
```

## Security Workflows

### Authentication Setup

```bash
# Generate authentication
azu generate auth

# Generate user model with authentication
azu generate model user email:string password_hash:string --validations

# Generate authentication endpoints
azu generate endpoint auth --actions login,logout,register
```

### Authorization

```crystal
# Generate authorization middleware
azu generate middleware AuthMiddleware

# Use in endpoints
class Admin::Users::IndexEndpoint < Azu::Endpoint
  before_action :require_admin

  private def require_admin
    unless current_user.admin?
      redirect_to "/", flash: { error: "Access denied" }
    end
  end
end
```

### Security Testing

```bash
# Generate security tests
azu generate spec security

# Run security tests
crystal spec spec/security/

# Check for vulnerabilities
azu security:audit
```

## Best Practices

### 1. Code Organization

```bash
# Keep related files together
src/
├── models/user.cr
├── endpoints/users/
├── services/user_service.cr
└── pages/users/

# Use consistent naming
azu generate model User
azu generate endpoint users
azu generate service UserService
```

### 2. Error Handling

```crystal
# Use proper error handling
def call
  user = User.find(params["id"])
  render "users/show_page", user: user
rescue CQL::RecordNotFound
  not_found
rescue ex : Exception
  log_error(ex)
  internal_server_error
end
```

### 3. Configuration Management

```bash
# Use environment variables
export DATABASE_URL="postgres://..."
export AZU_ENV="production"

# Use configuration files
# config/environments/production.cr
Azu.configure do |config|
  config.debug = false
  config.log_level = :info
end
```

### 4. Documentation

```bash
# Generate documentation
azu docs:generate

# Keep documentation updated
azu docs:update

# Serve documentation locally
azu docs:serve
```

## Troubleshooting

### Common Issues

```bash
# Database connection issues
azu db:create
azu db:migrate

# Compilation errors
crystal build src/main.cr

# Test failures
crystal spec --verbose

# Performance issues
crystal build src/main.cr --release
```

### Debug Workflows

```bash
# Enable debug mode
azu serve --debug

# Check logs
tail -f log/development.log

# Profile performance
crystal build src/main.cr --profile
```

---

These workflows provide a structured approach to developing applications with Azu CLI. Choose the workflows that best fit your project requirements and team preferences.

**Next Steps:**

- [Creating a New Project](new-project.md) - Start your first project
- [Building APIs](building-apis.md) - Create robust APIs
- [Working with Databases](database-workflow.md) - Master database operations
