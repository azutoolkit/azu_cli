# Appendices

This section contains supplementary information, reference materials, and additional resources for Azu CLI.

## Available Appendices

### 1. [Changelog](changelog.md)

Complete history of changes, features, and bug fixes for all Azu CLI versions.

**Includes:**

- Version history and release notes
- Breaking changes and migrations
- Feature additions and improvements
- Bug fixes and security updates
- Deprecation notices

### 2. [Migration Guides](migration-guides.md)

Step-by-step guides for upgrading between major versions of Azu CLI.

**Includes:**

- Version upgrade procedures
- Breaking change migrations
- Configuration updates
- Database migration steps
- Code compatibility changes

### 3. [FAQ](faq.md)

Frequently asked questions and their answers.

**Includes:**

- Common questions and solutions
- Troubleshooting tips
- Best practices
- Performance optimization
- Security considerations

### 4. [Glossary](glossary.md)

Definitions and explanations of terms used throughout the Azu CLI documentation.

**Includes:**

- Technical terminology
- Framework-specific terms
- Crystal language concepts
- Database terminology
- Web development terms

## Quick Reference

### Version Compatibility

| Azu CLI Version | Crystal Version | Azu Framework | CQL ORM |
| --------------- | --------------- | ------------- | ------- |
| 0.0.1+13        | 1.16.0+         | 0.1.0+        | 0.1.0+  |
| 0.0.1+12        | 1.15.0+         | 0.1.0+        | 0.1.0+  |
| 0.0.1+11        | 1.14.0+         | 0.1.0+        | 0.1.0+  |

### Common Commands Quick Reference

```bash
# Project Management
azu new <name>                      # Create new project
azu init                            # Initialize project
azu serve                           # Start development server

# Code Generation
azu generate model <name>           # Generate model
azu generate endpoint <name>        # Generate endpoint
azu generate scaffold <name>        # Generate complete resource

# Database Operations
azu db:create                       # Create database
azu db:migrate                      # Run migrations
azu db:rollback                     # Rollback migrations
azu db:seed                         # Seed database

# Development
azu dev                             # Development tools
azu test                            # Run tests
azu build                           # Build application
```

### Environment Variables Reference

```bash
# Required
DATABASE_URL=postgresql://localhost/db_name
APP_SECRET=your-secret-key

# Optional
APP_ENV=development|test|production
HOST=0.0.0.0
PORT=3000
LOG_LEVEL=debug|info|warn|error
```

### Configuration File Structure

```yaml
# config/application.yml
app:
  name: <%= ENV["APP_NAME"] || "My App" %>
  environment: <%= ENV["APP_ENV"] || "development" %>
  secret: <%= ENV["APP_SECRET"] %>

database:
  url: <%= ENV["DATABASE_URL"] %>
  pool_size: <%= ENV["DB_POOL_SIZE"] || 10 %>

server:
  host: <%= ENV["HOST"] || "0.0.0.0" %>
  port: <%= ENV["PORT"] || 3000 %>
```

## Troubleshooting Quick Reference

### Common Issues

| Issue                      | Solution                                   |
| -------------------------- | ------------------------------------------ |
| `command not found: azu`   | Install Azu CLI: `shards install`          |
| Database connection failed | Check `DATABASE_URL` and database status   |
| Port already in use        | Use `--port` flag or kill existing process |
| Compilation failed         | Check Crystal version and dependencies     |
| Template not found         | Verify template files exist                |

### Debug Commands

```bash
# Enable debug mode
export AZU_DEBUG=true

# Verbose output
azu serve --verbose

# Check configuration
azu config:show

# Validate setup
azu doctor
```

## Performance Reference

### Compilation Optimization

```bash
# Production build
crystal build --release src/main.cr

# Parallel compilation
crystal build --release --threads 4 src/main.cr

# Static linking
crystal build --release --static src/main.cr
```

### Runtime Optimization

```crystal
# Use appropriate data structures
users = Set(User).new              # For unique collections
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

## Database Reference

### Migration Patterns

```crystal
# Create table
create_table :users do |t|
  t.string :name, null: false
  t.string :email, null: false, unique: true
  t.timestamps
end

# Add column
add_column :users, :age, :integer

# Add index
add_index :users, :email, unique: true

# Foreign key
add_foreign_key :posts, :users, column: :author_id
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
export APP_ENV=production
export DATABASE_URL=postgresql://user:pass@host/db
export APP_SECRET=your-secret-key
export HOST=0.0.0.0
export PORT=3000
```

## Community Resources

### Official Resources

- [GitHub Repository](https://github.com/azutoolkit/azu_cli) - Source code and issues
- [Documentation](README.md) - Comprehensive guides
- [Discord Server](https://discord.gg/azutoolkit) - Community chat
- [Examples](examples/README.md) - Code examples and tutorials

### Third-Party Resources

- [Crystal Language](https://crystal-lang.org/) - Official Crystal documentation
- [Azu Framework](https://github.com/azutoolkit/azu) - Web framework documentation
- [CQL ORM](https://github.com/azutoolkit/cql) - Database ORM documentation
- [Topia CLI](https://github.com/azutoolkit/topia) - CLI framework documentation

### Learning Resources

- [Crystal Book](https://crystal-lang.org/docs/) - Official Crystal language guide
- [Crystal API Reference](https://crystal-lang.org/api/) - API documentation
- [Crystal Style Guide](https://crystal-lang.org/reference/conventions/coding_style.html) - Coding conventions
- [Crystal Community](https://crystal-lang.org/community/) - Community resources

## Support and Help

### Getting Help

1. **Check Documentation** - Start with the [main documentation](README.md)
2. **Search Issues** - Look for similar issues on [GitHub](https://github.com/azutoolkit/azu_cli/issues)
3. **Ask Community** - Join the [Discord server](https://discord.gg/azutoolkit)
4. **Create Issue** - Report bugs or request features on GitHub

### Contributing

- [Contributing Guide](contributing/README.md) - How to contribute
- [Development Setup](contributing/development-setup.md) - Setting up development environment
- [Code of Conduct](contributing/code-of-conduct.md) - Community guidelines

### Reporting Issues

When reporting issues, include:

- Crystal version: `crystal --version`
- Azu CLI version: `azu version`
- Operating system and version
- Steps to reproduce
- Expected vs actual behavior
- Error messages and stack traces

## Related Documentation

- [Getting Started](getting-started/quick-start.md) - Quick start guide
- [Command Reference](commands/README.md) - CLI commands
- [Generators](generators/README.md) - Code generation
- [Workflows](examples/README.md) - Development workflows
- [Architecture](architecture/README.md) - System architecture
- [Configuration](configuration/README.md) - Configuration management
- [Examples](examples/README.md) - Code examples
- [Reference](reference/README.md) - Technical reference
- [Contributing](contributing/README.md) - Contribution guidelines
