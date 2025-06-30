# Examples Overview

This section provides comprehensive examples and tutorials for building different types of applications with Azu CLI. Each example demonstrates real-world patterns and best practices.

## Available Examples

### 1. [Blog Application Tutorial](blog-tutorial.md)

A complete blog application with user authentication, posts, comments, and admin interface.

**Features:**

- User registration and authentication
- CRUD operations for blog posts
- Comment system
- Admin dashboard
- SEO optimization
- Image uploads

**Technologies:**

- Azu Web Framework
- CQL ORM
- Jinja2 templates
- Bootstrap CSS

### 2. [API-Only Application](api-tutorial.md)

A RESTful API for a task management system with authentication and real-time updates.

**Features:**

- RESTful API endpoints
- JWT authentication
- Task management
- User permissions
- API documentation
- Rate limiting

**Technologies:**

- Azu API Framework
- CQL ORM
- JWT tokens
- OpenAPI documentation

### 3. [Real-time Chat Application](chat-tutorial.md)

A real-time chat application with WebSocket support and user presence.

**Features:**

- Real-time messaging
- User presence indicators
- Private and group chats
- File sharing
- Message history
- Push notifications

**Technologies:**

- Azu Web Framework
- WebSocket support
- CQL ORM
- Redis for presence

### 4. [E-commerce Application](ecommerce-tutorial.md)

A full-featured e-commerce platform with product management and payment processing.

**Features:**

- Product catalog
- Shopping cart
- User accounts
- Order management
- Payment integration
- Inventory tracking

**Technologies:**

- Azu Web Framework
- CQL ORM
- Payment gateways
- Inventory management

### 5. [Microservices with Azu](microservices-tutorial.md)

Building a microservices architecture using Azu for different services.

**Features:**

- Service discovery
- API gateway
- User service
- Product service
- Order service
- Event-driven communication

**Technologies:**

- Multiple Azu applications
- Message queues
- Service mesh
- Container orchestration

## Getting Started with Examples

### Prerequisites

Before running any example, ensure you have:

```bash
# Install Crystal (1.16.0 or later)
# Follow instructions at https://crystal-lang.org/install/

# Install Azu CLI
shards install

# Install database (PostgreSQL recommended)
# Follow your OS-specific instructions
```

### Running Examples

Each example includes step-by-step instructions:

```bash
# Clone the example repository
git clone https://github.com/azutoolkit/examples.git
cd examples

# Navigate to specific example
cd blog-application

# Install dependencies
shards install

# Set up database
azu db:create
azu db:migrate
azu db:seed

# Start the application
azu serve
```

### Example Structure

Each example follows this structure:

```
example-name/
├── README.md                 # Example documentation
├── shard.yml                 # Dependencies
├── src/
│   ├── models/              # Database models
│   ├── endpoints/           # API endpoints
│   ├── pages/              # Web pages
│   ├── contracts/          # Validation contracts
│   ├── services/           # Business logic
│   └── db/
│       ├── migrations/     # Database migrations
│       └── seed.cr         # Seed data
├── public/                 # Static assets
├── spec/                   # Tests
└── config/                 # Configuration
```

## Learning Path

### Beginner Level

Start with these examples if you're new to Azu:

1. **Blog Application** - Learn basic CRUD operations
2. **API Tutorial** - Understand RESTful API design

### Intermediate Level

Move to these examples for more advanced concepts:

1. **Chat Application** - Real-time features and WebSockets
2. **E-commerce Application** - Complex business logic

### Advanced Level

For experienced developers:

1. **Microservices Tutorial** - Distributed systems
2. **Custom Generators** - Extending Azu CLI

## Example Patterns

### 1. Model-View-Controller (MVC)

```crystal
# Model (src/models/user.cr)
class User < CQL::Model
  table :users

  column :name, String
  column :email, String
  column :password_digest, String

  validates :name, presence: true
  validates :email, presence: true, format: /^[^@]+@[^@]+\.[^@]+$/
end

# Controller (src/endpoints/users/index_endpoint.cr)
class Users::IndexEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    @users = User.all
    render "endpoints/users/index.json"
  end
end

# View (src/endpoints/users/index.json.ecr)
{
  "users": [
    <% @users.each do |user| %>
    {
      "id": <%= user.id %>,
      "name": "<%= user.name %>",
      "email": "<%= user.email %>"
    }<% unless user == @users.last %>,<% end %>
    <% end %>
  ]
}
```

### 2. Service Layer Pattern

```crystal
# Service (src/services/user_service.cr)
class UserService
  def self.create_user(params : Hash(String, String)) : User
    contract = UserContract.new(params)

    unless contract.valid?
      raise ValidationError.new(contract.errors)
    end

    User.create(contract.valid_data)
  end

  def self.update_user(user : User, params : Hash(String, String)) : User
    contract = UserContract.new(params)

    unless contract.valid?
      raise ValidationError.new(contract.errors)
    end

    user.update(contract.valid_data)
    user
  end
end

# Endpoint using service
class Users::CreateEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    @user = UserService.create_user(context.params.to_h)
    render "endpoints/users/create.json", status: 201
  rescue ValidationError
    Azu::Response.new(
      status: 422,
      body: {errors: ex.errors}.to_json
    )
  end
end
```

### 3. Repository Pattern

```crystal
# Repository (src/repositories/user_repository.cr)
class UserRepository
  def self.find_by_email(email : String) : User?
    User.find_by(email: email)
  end

  def self.find_active_users : Array(User)
    User.where(active: true).order(created_at: :desc)
  end

  def self.create_user(attributes : Hash(String, String)) : User
    User.create(attributes)
  end
end

# Service using repository
class UserService
  def self.authenticate(email : String, password : String) : User?
    user = UserRepository.find_by_email(email)
    return nil unless user

    if user.authenticate(password)
      user
    end
  end
end
```

## Testing Examples

### Unit Testing

```crystal
# spec/models/user_spec.cr
describe User do
  describe "validations" do
    it "is valid with correct attributes" do
      user = User.new(
        name: "John Doe",
        email: "john@example.com",
        password_digest: "hashed_password"
      )

      user.valid?.should be_true
    end

    it "requires name" do
      user = User.new(email: "john@example.com")
      user.valid?.should be_false
      user.errors[:name].should contain("can't be blank")
    end
  end
end
```

### Integration Testing

```crystal
# spec/endpoints/users_spec.cr
describe Users::IndexEndpoint do
  it "returns all users" do
    user = User.create(name: "John Doe", email: "john@example.com")

    get "/users"

    response.status_code.should eq(200)
    response.body.should contain("John Doe")
  end
end
```

## Deployment Examples

### Docker Deployment

```dockerfile
# Dockerfile
FROM crystallang/crystal:1.16.0-alpine

WORKDIR /app

# Install dependencies
COPY shard.yml shard.lock ./
RUN shards install

# Copy source code
COPY . .

# Build application
RUN crystal build --release src/main.cr

# Run application
CMD ["./main"]
```

### Production Configuration

```yaml
# config/production.yml
app:
  environment: production
  secret: <%= ENV["APP_SECRET"] %>

database:
  url: <%= ENV["DATABASE_URL"] %>
  pool_size: 20

server:
  host: 0.0.0.0
  port: <%= ENV["PORT"] || 3000 %>
  workers: 4

logging:
  level: info
  format: json
  file_path: /var/log/app/app.log
```

## Contributing Examples

### Creating New Examples

To create a new example:

1. **Follow the structure** - Use the standard example structure
2. **Include documentation** - Comprehensive README with setup instructions
3. **Add tests** - Include unit and integration tests
4. **Use best practices** - Follow Azu conventions and patterns
5. **Keep it focused** - Each example should demonstrate specific concepts

### Example Guidelines

- **Complete and runnable** - Examples should work out of the box
- **Well-documented** - Clear setup and usage instructions
- **Tested** - Include comprehensive test coverage
- **Realistic** - Demonstrate real-world scenarios
- **Maintained** - Keep examples up to date with framework changes

## Community Examples

### Third-Party Examples

The community has created additional examples:

- **Authentication Examples** - OAuth, JWT, session-based auth
- **File Upload Examples** - Image processing, file storage
- **Background Job Examples** - Queue processing, scheduled tasks
- **Monitoring Examples** - Health checks, metrics collection

### Sharing Your Examples

To share your examples with the community:

1. **Create a repository** - Host your example on GitHub
2. **Add documentation** - Include setup and usage instructions
3. **Submit to examples list** - Add your example to the community examples
4. **Maintain regularly** - Keep your example up to date

## Related Documentation

- [Getting Started](getting-started/quick-start.md) - Quick start guide
- [Command Reference](commands/README.md) - CLI commands
- [Generators](generators/README.md) - Code generation
- [Workflows](workflows/README.md) - Development workflows
- [Architecture](architecture/README.md) - System architecture
