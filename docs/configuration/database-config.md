# Database Configuration

Database configuration in Azu CLI manages database connections, CQL ORM settings, migration configurations, and database-specific options. This includes connection pooling, adapter settings, and environment-specific database configurations.

## Overview

Database configuration supports multiple database adapters and environments:

- **PostgreSQL**: Primary database adapter
- **MySQL**: Alternative database adapter
- **SQLite**: Development and testing database
- **Connection Pooling**: Configurable connection management
- **Migrations**: Database schema management
- **Seeds**: Database seeding configuration

## Database Configuration Structure

### Base Database Configuration

```yaml
# config/database.yml
database:
  # Connection settings
  url: <%= ENV["DATABASE_URL"] %>
  adapter: <%= ENV["DB_ADAPTER"] || "postgresql" %>
  host: <%= ENV["DB_HOST"] || "localhost" %>
  port: <%= ENV["DB_PORT"] || 5432 %>
  username: <%= ENV["DB_USERNAME"] || "postgres" %>
  password: <%= ENV["DB_PASSWORD"] || "" %>
  database: <%= ENV["DB_NAME"] || "myapp_development" %>

  # Connection pooling
  pool_size: <%= ENV["DB_POOL_SIZE"] || 10 %>
  pool_timeout: <%= ENV["DB_POOL_TIMEOUT"] || 5000 %>
  pool_checkout_timeout: <%= ENV["DB_POOL_CHECKOUT_TIMEOUT"] || 5000 %>

  # SSL configuration
  ssl_mode: <%= ENV["DB_SSL_MODE"] || "prefer" %>
  ssl_cert: <%= ENV["DB_SSL_CERT"] %>
  ssl_key: <%= ENV["DB_SSL_KEY"] %>
  ssl_ca: <%= ENV["DB_SSL_CA"] %>

  # Performance settings
  statement_timeout: <%= ENV["DB_STATEMENT_TIMEOUT"] || 30000 %>
  idle_in_transaction_timeout: <%= ENV["DB_IDLE_TIMEOUT"] || 30000 %>

  # Logging
  logging: <%= ENV["DB_LOGGING"] || false %>
  log_level: <%= ENV["DB_LOG_LEVEL"] || "info" %>

  # Migration settings
  migrations:
    directory: db/migrations/
    table: schema_migrations
    lock_timeout: 10000

  # Seed configuration
  seeds:
    directory: db/seeds/
    files:
      - main_seed.cr
      - test_data.cr
```

## Database Adapters

### PostgreSQL Configuration

```yaml
# PostgreSQL-specific configuration
database:
  adapter: postgresql
  host: localhost
  port: 5432
  username: postgres
  password: ""
  database: myapp_development

  # PostgreSQL-specific options
  postgresql:
    # Connection parameters
    application_name: myapp
    client_encoding: utf8
    timezone: UTC

    # Performance tuning
    shared_buffers: 128MB
    effective_cache_size: 4GB
    maintenance_work_mem: 64MB

    # Replication (if using)
    replication:
      enabled: false
      mode: async
      slots: []

    # Connection pooling with PgBouncer
    pgbouncer:
      enabled: false
      pool_mode: transaction
      max_client_conn: 1000
      default_pool_size: 20
```

### MySQL Configuration

```yaml
# MySQL-specific configuration
database:
  adapter: mysql
  host: localhost
  port: 3306
  username: root
  password: ""
  database: myapp_development

  # MySQL-specific options
  mysql:
    # Connection parameters
    charset: utf8mb4
    collation: utf8mb4_unicode_ci
    timezone: +00:00

    # Performance settings
    innodb_buffer_pool_size: 1G
    innodb_log_file_size: 256M
    innodb_flush_log_at_trx_commit: 1

    # Connection pooling
    connection_pool:
      min_size: 5
      max_size: 20
      checkout_timeout: 5000
```

### SQLite Configuration

```yaml
# SQLite-specific configuration
database:
  adapter: sqlite
  database: db/myapp_development.sqlite3

  # SQLite-specific options
  sqlite:
    # Performance settings
    journal_mode: WAL
    synchronous: NORMAL
    cache_size: -64000 # 64MB
    temp_store: MEMORY

    # Foreign key support
    foreign_keys: true

    # WAL mode settings
    wal_autocheckpoint: 1000
    wal_sync_mode: NORMAL
```

## Environment-Specific Configuration

### Development Environment

```yaml
# config/development.yml
database:
  url: postgresql://localhost/myapp_development
  host: localhost
  port: 5432
  username: postgres
  password: ""
  database: myapp_development

  # Development-specific settings
  pool_size: 5
  logging: true
  log_level: debug

  # Fast development settings
  postgresql:
    fsync: off
    synchronous_commit: off
    wal_buffers: 16MB
    checkpoint_segments: 32
    checkpoint_completion_target: 0.9
```

### Test Environment

```yaml
# config/test.yml
database:
  url: postgresql://localhost/myapp_test
  host: localhost
  port: 5432
  username: postgres
  password: ""
  database: myapp_test

  # Test-specific settings
  pool_size: 1
  logging: false

  # Fast test settings
  postgresql:
    fsync: off
    synchronous_commit: off
    wal_buffers: 1MB
    shared_buffers: 16MB
    effective_cache_size: 128MB
```

### Production Environment

```yaml
# config/production.yml
database:
  url: <%= ENV["DATABASE_URL"] %>
  host: <%= ENV["DB_HOST"] %>
  port: <%= ENV["DB_PORT"] || 5432 %>
  username: <%= ENV["DB_USERNAME"] %>
  password: <%= ENV["DB_PASSWORD"] %>
  database: <%= ENV["DB_NAME"] %>

  # Production-specific settings
  pool_size: <%= ENV["DB_POOL_SIZE"] || 20 %>
  logging: false

  # SSL configuration
  ssl_mode: require
  ssl_cert: <%= ENV["DB_SSL_CERT"] %>
  ssl_key: <%= ENV["DB_SSL_KEY"] %>
  ssl_ca: <%= ENV["DB_SSL_CA"] %>

  # Production performance settings
  postgresql:
    fsync: on
    synchronous_commit: on
    wal_buffers: 16MB
    shared_buffers: 256MB
    effective_cache_size: 1GB
    maintenance_work_mem: 64MB
```

## CQL ORM Configuration

### Model Configuration

```yaml
# CQL ORM configuration
cql:
  # Model settings
  models:
    # Default table naming
    table_naming: pluralize
    # Default primary key
    primary_key: id
    # Timestamps
    timestamps: true
    # UUID primary keys
    use_uuid: false

  # Validation settings
  validation:
    # Default validation messages
    messages:
      required: "is required"
      email: "must be a valid email"
      min_length: "must be at least %{min} characters"
      max_length: "must be at most %{max} characters"

  # Query settings
  query:
    # Default pagination
    default_per_page: 25
    max_per_page: 100
    # Case sensitivity
    case_sensitive: false
    # Default ordering
    default_order: "created_at DESC"
```

### Migration Configuration

```yaml
# Migration configuration
migrations:
  # Migration directory
  directory: db/migrations/

  # Migration table
  table: schema_migrations

  # Migration settings
  settings:
    # Lock timeout for migrations
    lock_timeout: 10000
    # Statement timeout
    statement_timeout: 30000
    # Transaction isolation level
    isolation_level: READ_COMMITTED

  # Migration templates
  templates:
    # Default migration template
    default: db/migration_template.cr.ecr
    # Custom migration templates
    custom:
      create_table: db/templates/create_table.cr.ecr
      add_column: db/templates/add_column.cr.ecr
      add_index: db/templates/add_index.cr.ecr
```

## Connection Pooling

### Pool Configuration

```yaml
# Connection pool configuration
database:
  # Pool settings
  pool:
    # Pool size
    size: 10
    # Pool timeout
    timeout: 5000
    # Checkout timeout
    checkout_timeout: 5000
    # Idle timeout
    idle_timeout: 300000 # 5 minutes
    # Max overflow
    max_overflow: 5
    # Preload connections
    preload: true

  # Pool monitoring
  pool_monitoring:
    enabled: true
    log_level: info
    metrics:
      - active_connections
      - idle_connections
      - checkout_time
      - wait_time
```

### Pool Management

```crystal
# In your application
require "azu_cli"

# Access database configuration
config = Azu::Config.current

# Database connection
db_config = config.database

# Connection string
connection_string = db_config.connection_string

# Pool settings
pool_size = db_config.pool_size
pool_timeout = db_config.pool_timeout

# Initialize database connection
CQL.configure do |settings|
  settings.database_url = connection_string
  settings.pool_size = pool_size
  settings.pool_timeout = pool_timeout
  settings.logging = db_config.logging
end
```

## Database Seeding

### Seed Configuration

```yaml
# Seed configuration
seeds:
  # Seed directory
  directory: db/seeds/

  # Seed files (executed in order)
  files:
    - main_seed.cr
    - users_seed.cr
    - products_seed.cr
    - orders_seed.cr

  # Environment-specific seeds
  environments:
    development:
      - dev_data_seed.cr
    test:
      - test_data_seed.cr
    production:
      - production_data_seed.cr

  # Seed settings
  settings:
    # Truncate tables before seeding
    truncate: false
    # Skip existing records
    skip_existing: true
    # Batch size for large datasets
    batch_size: 1000
```

### Seed File Example

```crystal
# db/seeds/main_seed.cr
require "../src/main"

# Seed configuration
config = Azu::Config.current
seed_config = config.seeds

# Create admin user
admin = User.create!(
  email: "admin@example.com",
  password: "admin123",
  role: "admin",
  confirmed_at: Time.utc
)

puts "Created admin user: #{admin.email}"

# Create sample categories
categories = [
  { name: "Electronics", description: "Electronic devices and gadgets" },
  { name: "Books", description: "Books and publications" },
  { name: "Clothing", description: "Apparel and accessories" }
]

categories.each do |category_data|
  category = Category.create!(category_data)
  puts "Created category: #{category.name}"
end

# Create sample products
products = [
  { name: "Laptop", price: 999.99, category_id: 1 },
  { name: "Smartphone", price: 599.99, category_id: 1 },
  { name: "Programming Book", price: 49.99, category_id: 2 }
]

products.each do |product_data|
  product = Product.create!(product_data)
  puts "Created product: #{product.name}"
end
```

## Database Monitoring

### Monitoring Configuration

```yaml
# Database monitoring
monitoring:
  # Query monitoring
  queries:
    enabled: true
    slow_query_threshold: 1000 # milliseconds
    log_slow_queries: true
    log_all_queries: false

  # Connection monitoring
  connections:
    enabled: true
    log_connection_errors: true
    log_connection_timeouts: true

  # Performance monitoring
  performance:
    enabled: true
    metrics:
      - query_count
      - query_time
      - connection_count
      - pool_utilization
    export_metrics: false
```

### Monitoring Implementation

```crystal
# Database monitoring
class DatabaseMonitor
  def self.monitor_query(query : String, duration : Time::Span)
    config = Azu::Config.current
    monitoring = config.monitoring

    return unless monitoring.queries.enabled

    if duration.total_milliseconds > monitoring.queries.slow_query_threshold
      Azu::Logger.warn("Slow query detected", {
        "query" => query,
        "duration_ms" => duration.total_milliseconds.to_s
      })
    end
  end

  def self.monitor_connection(error : Exception)
    config = Azu::Config.current
    monitoring = config.monitoring

    return unless monitoring.connections.enabled

    Azu::Logger.error("Database connection error", {
      "error" => error.message,
      "class" => error.class.name
    })
  end
end
```

## Database Commands

### Database Management Commands

```bash
# Create database
azu db create

# Drop database
azu db drop

# Run migrations
azu db migrate

# Rollback migrations
azu db rollback --steps 1

# Reset database (drop, create, migrate, seed)
azu db reset

# Seed database
azu db seed

# Check migration status
azu db status

# Create new migration
azu db new_migration CreateUsers

# Backup database
azu db backup

# Restore database
azu db restore backup.sql
```

### Configuration Commands

```bash
# Show database configuration
azu db config

# Test database connection
azu db test_connection

# Validate database configuration
azu db validate_config

# Generate database configuration
azu db generate_config
```

## Environment Variables

### Database Environment Variables

```bash
# Database connection
export DATABASE_URL="postgresql://user:password@host:5432/database"
export DB_ADAPTER="postgresql"
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_USERNAME="postgres"
export DB_PASSWORD="secret"
export DB_NAME="myapp_development"

# Connection pooling
export DB_POOL_SIZE="10"
export DB_POOL_TIMEOUT="5000"
export DB_POOL_CHECKOUT_TIMEOUT="5000"

# SSL configuration
export DB_SSL_MODE="require"
export DB_SSL_CERT="/path/to/cert.pem"
export DB_SSL_KEY="/path/to/key.pem"
export DB_SSL_CA="/path/to/ca.pem"

# Performance settings
export DB_STATEMENT_TIMEOUT="30000"
export DB_IDLE_TIMEOUT="30000"

# Logging
export DB_LOGGING="true"
export DB_LOG_LEVEL="info"
```

## Best Practices

### Configuration Management

1. **Environment Variables**: Use environment variables for sensitive data
2. **Connection Pooling**: Configure appropriate pool sizes for your workload
3. **SSL**: Always use SSL in production
4. **Monitoring**: Enable query and connection monitoring
5. **Backups**: Configure regular database backups

### Performance

1. **Pool Sizing**: Size connection pools based on application needs
2. **Query Optimization**: Monitor and optimize slow queries
3. **Indexing**: Ensure proper database indexing
4. **Connection Management**: Properly manage database connections
5. **Caching**: Use appropriate caching strategies

### Security

1. **Credentials**: Never commit database credentials to version control
2. **SSL**: Use SSL connections in production
3. **Access Control**: Restrict database access appropriately
4. **Audit Logging**: Enable audit logging for sensitive operations
5. **Backup Security**: Secure database backups

## Related Documentation

- [Configuration Overview](README.md) - General configuration guide
- [Project Configuration](project-config.md) - Project-specific configuration
- [Development Server Configuration](dev-server-config.md) - Development server settings
- [Generator Configuration](generator-config.md) - Code generation configuration
- [Environment Variables](environment.md) - Environment variable reference
