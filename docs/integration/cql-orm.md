# CQL ORM Integration

The Azu CLI provides comprehensive integration with CQL (Crystal Query Language), a powerful Object-Relational Mapping library for Crystal. This integration enables seamless database management, model generation, and migration handling.

## Overview

CQL ORM integration provides:

- **Model Generation**: Automatic CQL model creation with proper field types
- **Migration Management**: Database schema evolution and version control
- **Query Building**: Type-safe database queries and relationships
- **Validation**: Built-in validation system for model data
- **Performance**: Optimized database operations and connection pooling

## CQL ORM Architecture

### Core Components

```
CQL ORM
├── Model Layer
│   ├── Field Definitions
│   ├── Validations
│   ├── Associations
│   └── Callbacks
├── Query Builder
│   ├── Type-safe Queries
│   ├── Relationship Loading
│   └── Aggregations
├── Migration System
│   ├── Schema Changes
│   ├── Version Control
│   └── Rollback Support
└── Connection Management
    ├── Connection Pooling
    ├── Transaction Support
    └── Multiple Adapters
```

### CLI Integration Points

```
Azu CLI + CQL
├── Model Generation
├── Migration Commands
├── Database Setup
├── Seed Data Management
├── Schema Inspection
└── Query Optimization
```

## Database Configuration

### Basic Configuration

```yaml
# azu.yml
database:
  adapter: "postgresql"
  url: "postgresql://localhost/myapp"
  pool_size: 5
  timeout: 5
  log_queries: false
```

### Environment-Specific Configuration

```yaml
# azu.yml
database:
  development:
    adapter: "postgresql"
    url: "postgresql://localhost/myapp_dev"
    pool_size: 3
    log_queries: true

  test:
    adapter: "postgresql"
    url: "postgresql://localhost/myapp_test"
    pool_size: 1
    log_queries: false

  production:
    adapter: "postgresql"
    url: "${AZU_DATABASE_URL}"
    pool_size: 10
    timeout: 10
    log_queries: false
```

### Connection Setup

```crystal
# src/initializers/database.cr
require "cql"

CQL.configure do |config|
  config.adapter = :postgresql
  config.url = ENV["AZU_DATABASE_URL"]? || "postgresql://localhost/myapp"
  config.pool_size = ENV["AZU_DATABASE_POOL_SIZE"]?.try(&.to_i) || 5
  config.timeout = ENV["AZU_DATABASE_TIMEOUT"]?.try(&.to_i) || 5
  config.log_queries = ENV["AZU_LOG_QUERIES"]? == "true"
end
```

## Model Generation

### Basic Model Generation

```bash
# Generate a simple model
azu generate model User email:string name:string age:integer

# Generate model with associations
azu generate model Post title:string content:text user:belongs_to
```

### Generated Model Structure

```crystal
# Generated User model
class User < CQL::Model
  # Table configuration
  table "users"

  # Field definitions
  field id : UUID = UUID.random
  field email : String
  field name : String
  field age : Int32
  field created_at : Time = Time.utc
  field updated_at : Time = Time.utc

  # Validations
  validates :email, presence: true, format: :email, uniqueness: true
  validates :name, presence: true, length: {min: 2, max: 100}
  validates :age, numericality: {greater_than: 0, less_than: 150}

  # Associations
  has_many :posts
  has_many :comments

  # Scopes
  scope :adults, -> { where("age >= ?", 18) }
  scope :by_name, ->(name : String) { where("name ILIKE ?", "%#{name}%") }

  # Callbacks
  before_save :normalize_email

  private def normalize_email
    self.email = email.downcase.strip
  end
end
```

### Advanced Model Generation

```bash
# Generate model with custom options
azu generate model Product \
  --fields="name:string,price:decimal,description:text,category:belongs_to" \
  --validations="name:presence,price:numericality" \
  --associations="has_many:reviews,belongs_to:category" \
  --scopes="active,featured" \
  --callbacks="before_save:normalize_name"
```

## Migration Management

### Migration Generation

```bash
# Generate migration for new table
azu db new_migration create_users

# Generate migration for existing model
azu generate migration add_fields_to_users email:string name:string
```

### Generated Migration

```crystal
# Generated migration
class CreateUsers < CQL::Migration
  def up
    create_table :users do |t|
      t.uuid :id, primary_key: true
      t.string :email, unique: true, null: false
      t.string :name, null: false
      t.integer :age
      t.timestamps
    end

    # Add indexes
    add_index :users, :email
    add_index :users, :name
  end

  def down
    drop_table :users
  end
end
```

### Migration Commands

```bash
# Run all pending migrations
azu db migrate

# Run specific migration
azu db migrate --version=20231201000000

# Rollback last migration
azu db rollback

# Rollback to specific version
azu db rollback --version=20231101000000

# Show migration status
azu db status

# Reset database (drop and recreate)
azu db reset
```

## Database Commands

### Database Setup

```bash
# Create database
azu db create

# Drop database
azu db drop

# Create and setup database
azu db setup
```

### Schema Management

```bash
# Generate schema file
azu db schema

# Load schema from file
azu db schema:load

# Dump current schema
azu db schema:dump
```

### Seed Data

```bash
# Run seed data
azu db seed

# Generate seed file
azu generate seed

# Run specific seed file
azu db seed --file=users
```

## Query Building

### Basic Queries

```crystal
# Find all users
users = User.all

# Find by ID
user = User.find(user_id)

# Find by conditions
user = User.find_by(email: "user@example.com")
users = User.where("age > ?", 18)

# Complex queries
users = User
  .joins(:posts)
  .where("posts.created_at > ?", 1.week.ago)
  .group("users.id")
  .having("COUNT(posts.id) > ?", 5)
```

### Relationship Queries

```crystal
# Eager loading
users = User.includes(:posts, :comments)

# Nested includes
users = User.includes(posts: :comments)

# Conditional includes
users = User.includes(:posts).where("posts.published = ?", true)
```

### Aggregations

```crystal
# Count
user_count = User.count
active_users = User.where(active: true).count

# Sum
total_age = User.sum(:age)
average_age = User.average(:age)

# Group by
users_by_age = User.group(:age).count
```

## Validation System

### Built-in Validations

```crystal
class User < CQL::Model
  # Presence validation
  validates :email, presence: true
  validates :name, presence: true

  # Format validation
  validates :email, format: :email
  validates :phone, format: /\A\+?\d{10,15}\z/

  # Length validation
  validates :name, length: {min: 2, max: 100}
  validates :bio, length: {max: 1000}

  # Numericality validation
  validates :age, numericality: {greater_than: 0, less_than: 150}
  validates :score, numericality: {greater_than_or_equal_to: 0}

  # Uniqueness validation
  validates :email, uniqueness: true
  validates :username, uniqueness: {scope: :organization_id}

  # Inclusion validation
  validates :status, inclusion: %w[active inactive pending]

  # Exclusion validation
  validates :username, exclusion: %w[admin root system]
end
```

### Custom Validations

```crystal
class User < CQL::Model
  validate :password_strength
  validate :email_domain_allowed

  private def password_strength
    return unless password_changed?

    unless password =~ /\A(?=.*[a-z])(?=.*[A-Z])(?=.*\d).{8,}\z/
      errors.add(:password, "must be at least 8 characters with uppercase, lowercase, and number")
    end
  end

  private def email_domain_allowed
    allowed_domains = %w[gmail.com yahoo.com hotmail.com]
    domain = email.split("@").last

    unless allowed_domains.includes?(domain)
      errors.add(:email, "domain not allowed")
    end
  end
end
```

## Association Management

### Association Types

```crystal
class User < CQL::Model
  # One-to-many
  has_many :posts
  has_many :comments

  # One-to-one
  has_one :profile
  has_one :avatar

  # Many-to-one
  belongs_to :organization
  belongs_to :manager, class_name: "User"

  # Many-to-many
  has_many :followers, through: :follows, source: :follower
  has_many :following, through: :follows, source: :followed
end

class Post < CQL::Model
  belongs_to :user
  has_many :comments
  has_many :tags, through: :post_tags
end
```

### Association Options

```crystal
class User < CQL::Model
  # With options
  has_many :posts, dependent: :destroy
  has_many :comments, dependent: :nullify

  belongs_to :organization, optional: true
  belongs_to :manager, class_name: "User", foreign_key: "manager_id"

  # Polymorphic associations
  has_many :notifications, as: :notifiable
end
```

## Performance Optimization

### Connection Pooling

```crystal
# Configure connection pool
CQL.configure do |config|
  config.pool_size = 10
  config.pool_timeout = 5
  config.pool_checkout_timeout = 5
end
```

### Query Optimization

```crystal
# Use includes for N+1 prevention
users = User.includes(:posts, :comments)

# Use select for specific fields
users = User.select(:id, :name, :email)

# Use limit and offset for pagination
users = User.limit(20).offset(40)

# Use indexes effectively
users = User.where(email: "user@example.com") # Uses email index
```

### Caching

```crystal
# Model-level caching
class User < CQL::Model
  cache_by :email

  # Cache frequently accessed data
  def cached_posts_count
    Rails.cache.fetch("user_#{id}_posts_count") do
      posts.count
    end
  end
end
```

## Testing Integration

### Test Configuration

```crystal
# spec/spec_helper.cr
require "cql/test"

# Configure test database
CQL.configure do |config|
  config.adapter = :postgresql
  config.url = "postgresql://localhost/myapp_test"
  config.pool_size = 1
end
```

### Test Helpers

```crystal
# spec/support/database_helper.cr
module DatabaseHelper
  def self.clean
    # Clean database between tests
    CQL::Migration.run_all_down
    CQL::Migration.run_all_up
  end

  def self.seed
    # Seed test data
    User.create!(email: "test@example.com", name: "Test User")
  end
end
```

### Model Testing

```crystal
# spec/models/user_spec.cr
require "spec"
require "../support/database_helper"

describe User do
  before_each do
    DatabaseHelper.clean
  end

  describe "validations" do
    it "requires email" do
      user = User.new
      user.valid?.should be_false
      user.errors[:email].should contain("can't be blank")
    end

    it "requires valid email format" do
      user = User.new(email: "invalid-email")
      user.valid?.should be_false
      user.errors[:email].should contain("is invalid")
    end
  end

  describe "associations" do
    it "has many posts" do
      user = User.create!(email: "test@example.com", name: "Test User")
      post = Post.create!(title: "Test Post", user: user)

      user.posts.should contain(post)
    end
  end
end
```

## Troubleshooting

### Common Issues

**Connection Errors**: Verify database URL and connectivity.

**Migration Conflicts**: Check migration version conflicts and resolve manually.

**Performance Issues**: Use query optimization techniques and proper indexing.

**Validation Errors**: Review validation rules and data types.

### Debug Commands

```bash
# Check database connection
azu db ping

# Show database status
azu db status

# Validate schema
azu db validate

# Show slow queries
azu db slow_queries

# Analyze query performance
azu db analyze --query="SELECT * FROM users"
```

### Debugging Queries

```crystal
# Enable query logging
CQL.configure do |config|
  config.log_queries = true
end

# Use explain for query analysis
User.where("age > ?", 18).explain

# Profile specific queries
CQL.profile do
  User.includes(:posts).all
end
```

## Best Practices

### Model Design

1. **Use appropriate field types** for data storage
2. **Implement proper validations** for data integrity
3. **Use associations** to model relationships correctly
4. **Add indexes** for frequently queried fields

### Performance

1. **Use includes** to prevent N+1 queries
2. **Implement proper indexing** for query optimization
3. **Use connection pooling** for better resource management
4. **Monitor query performance** and optimize slow queries

### Migration Management

1. **Write reversible migrations** for easy rollbacks
2. **Test migrations** in development before production
3. **Use descriptive migration names** for better tracking
4. **Backup data** before running destructive migrations

### Testing

1. **Use test database** for isolated testing
2. **Clean database** between tests
3. **Test validations** and associations thoroughly
4. **Mock external dependencies** for faster tests

## Migration from Other ORMs

### From Jennifer

```bash
# Generate migration plan
azu migration plan --from=jennifer --to=cql

# Convert models
azu migration convert --input=jennifer_models --output=cql_models

# Convert migrations
azu migration convert --input=jennifer_migrations --output=cql_migrations
```

### From Manual SQL

```bash
# Analyze existing schema
azu db analyze --schema=existing_schema.sql

# Generate models from schema
azu generate models --from=schema.sql

# Generate migrations
azu generate migrations --from=schema.sql
```

## Support and Resources

### Documentation

- [CQL ORM Documentation](https://github.com/azutoolkit/cql)
- [Database Adapters](https://github.com/crystal-lang/crystal-db)
- [Migration Guide](https://github.com/azutoolkit/cql/blob/main/docs/migrations.md)

### Community

- **GitHub**: Report issues and contribute
- **Discord**: Join the CQL community
- **Examples**: Sample projects and patterns

### Getting Help

- **Documentation**: Comprehensive ORM guides
- **Community Support**: Ask questions in Discord
- **Issue Tracking**: Report bugs on GitHub
- **Contributing**: Contribute to CQL development
