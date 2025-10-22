# Configuration Overview

Azu CLI uses a flexible configuration system that supports multiple environments, environment variables, and YAML-based configuration files. This guide covers how to configure your Azu applications effectively.

## Configuration Philosophy

Azu CLI follows these configuration principles:

- **Environment-based**: Different configurations for different environments
- **Secure**: Sensitive data stored in environment variables
- **Flexible**: Support for multiple configuration formats
- **Validated**: Configuration schema validation
- **Hierarchical**: Nested configuration with inheritance

## Configuration Sources

Configuration is loaded from multiple sources in order of precedence:

1. **Environment Variables** (highest priority)
2. **Configuration Files** (YAML)
3. **Default Values** (lowest priority)

### Environment Variables

Environment variables take precedence over all other configuration sources:

```bash
# Database configuration
export DATABASE_URL=postgresql://localhost/myapp_production
export DB_POOL_SIZE=20

# Server configuration
export HOST=0.0.0.0
export PORT=8080

# Application configuration
export APP_ENV=production
export APP_SECRET=your-secret-key-here
```

### Configuration Files

Configuration files are stored in the `config/` directory:

```
config/
├── application.yml          # Base configuration
├── development.yml          # Development environment
├── test.yml                # Test environment
├── production.yml           # Production environment
└── database.yml            # Database-specific configuration
```

### Default Values

Sensible defaults are provided for all configuration options:

```yaml
# Default configuration values
database:
  pool_size: 10
  timeout: 5000

server:
  host: 0.0.0.0
  port: 4000

app:
  environment: development
  log_level: info
```

## Configuration Structure

### Base Configuration (`config/application.yml`)

```yaml
# Application-wide configuration
app:
  name: <%= ENV["APP_NAME"] || "My Azu App" %>
  environment: <%= ENV["APP_ENV"] || "development" %>
  secret: <%= ENV["APP_SECRET"] %>
  log_level: <%= ENV["LOG_LEVEL"] || "info" %>

# Database configuration
database:
  url: <%= ENV["DATABASE_URL"] %>
  pool_size: <%= ENV["DB_POOL_SIZE"] || 10 %>
  timeout: <%= ENV["DB_TIMEOUT"] || 5000 %>
  logging: <%= ENV["DB_LOGGING"] || false %>

# Server configuration
server:
  host: <%= ENV["HOST"] || "0.0.0.0" %>
  port: <%= ENV["PORT"] || 4000 %>
  workers: <%= ENV["WORKERS"] || 1 %>

# Development server configuration
dev_server:
  reload: <%= ENV["RELOAD"] || true %>
  watch_paths: ["src/", "config/"]
  ignored_paths: [".git/", "node_modules/", ".crystal/"]

# Generator configuration
generators:
  default_template: basic
  overwrite_existing: false
  add_tests: true
  add_documentation: true

# Logging configuration
logging:
  level: <%= ENV["LOG_LEVEL"] || "info" %>
  format: <%= ENV["LOG_FORMAT"] || "json" %>
  output: <%= ENV["LOG_OUTPUT"] || "stdout" %>
  file_path: <%= ENV["LOG_FILE"] %>
```

### Environment-Specific Configuration

#### Development (`config/development.yml`)

```yaml
# Development-specific overrides
app:
  environment: development
  log_level: debug

database:
  url: postgresql://localhost/myapp_development
  logging: true

dev_server:
  reload: true
  port: 4000

logging:
  level: debug
  format: human
```

#### Test (`config/test.yml`)

```yaml
# Test-specific overrides
app:
  environment: test
  log_level: warn

database:
  url: postgresql://localhost/myapp_test
  pool_size: 5

dev_server:
  reload: false

logging:
  level: warn
  output: /dev/null
```

#### Production (`config/production.yml`)

```yaml
# Production-specific overrides
app:
  environment: production
  log_level: info

database:
  pool_size: 20
  timeout: 10000
  logging: false

server:
  workers: 4

logging:
  level: info
  format: json
  file_path: /var/log/myapp/app.log
```

## Configuration Loading

### Automatic Loading

Configuration is automatically loaded when the application starts:

```crystal
# Configuration is loaded automatically
require "azu_cli"

# Access configuration
config = Azu::Config.current
puts config.database.url
puts config.server.port
```

### Manual Loading

You can also load configuration manually:

```crystal
# Load specific environment
config = Azu::Config.load(:production)

# Load from custom path
config = Azu::Config.load_from("config/custom.yml")

# Load with overrides
config = Azu::Config.load(:development, {
  "database" => {"url" => "postgresql://localhost/custom"}
})
```

## Configuration Access

### In Application Code

```crystal
# Access configuration values
config = Azu::Config.current

# Database configuration
db_url = config.database.url
pool_size = config.database.pool_size

# Server configuration
host = config.server.host
port = config.server.port

# Application configuration
env = config.app.environment
secret = config.app.secret
```

### In Templates

```crystal
# Access configuration in ECR templates
<% config = Azu::Config.current %>

# Use in templates
database_url = <%= config.database.url %>
app_name = <%= config.app.name %>
```

### In Commands

```crystal
class MyCommand < Azu::Commands::Base
  def call
    config = Azu::Config.current

    # Use configuration in commands
    puts "Database: #{config.database.url}"
    puts "Environment: #{config.app.environment}"
  end
end
```

## Environment Variables

### Required Environment Variables

```bash
# Database (required for database operations)
DATABASE_URL=postgresql://username:password@localhost/database_name

# Application security (required for production)
APP_SECRET=your-secret-key-here

# Environment (recommended)
APP_ENV=development|test|production
```

### Optional Environment Variables

```bash
# Database configuration
DB_POOL_SIZE=10
DB_TIMEOUT=5000
DB_LOGGING=true

# Server configuration
HOST=0.0.0.0
PORT=4000
WORKERS=1

# Logging configuration
LOG_LEVEL=debug|info|warn|error
LOG_FORMAT=json|human
LOG_OUTPUT=stdout|stderr|file
LOG_FILE=/path/to/log/file

# Development server
RELOAD=true|false
WATCH_PATHS=src/,config/
IGNORED_PATHS=.git/,node_modules/

# Generator configuration
GENERATOR_TEMPLATE=basic|api|web
OVERWRITE_EXISTING=false
ADD_TESTS=true
ADD_DOCUMENTATION=true
```

### Environment Variable Naming

Azu CLI follows these naming conventions:

- **UPPERCASE**: All environment variables are uppercase
- **Underscore Separated**: Words separated by underscores
- **Namespaced**: Related variables grouped with prefixes
- **Descriptive**: Clear, descriptive names

```bash
# Good naming
DATABASE_URL
DB_POOL_SIZE
APP_SECRET
LOG_LEVEL

# Avoid
database_url
dbPoolSize
secret
log
```

## Configuration Validation

### Schema Validation

Configuration is validated against a schema:

```crystal
# Configuration schema
class ConfigSchema
  include JSON::Serializable

  property app : AppConfig
  property database : DatabaseConfig
  property server : ServerConfig

  class AppConfig
    include JSON::Serializable

    property name : String
    property environment : String
    property secret : String?
    property log_level : String
  end

  class DatabaseConfig
    include JSON::Serializable

    property url : String
    property pool_size : Int32
    property timeout : Int32
    property logging : Bool
  end

  class ServerConfig
    include JSON::Serializable

    property host : String
    property port : Int32
    property workers : Int32
  end
end
```

### Validation Errors

Configuration validation errors are reported clearly:

```bash
# Invalid configuration
Error: Invalid configuration
  - database.url: required field missing
  - server.port: must be a positive integer
  - app.secret: required for production environment
```

## Configuration Best Practices

### 1. Environment Separation

Keep different environments separate:

```yaml
# config/development.yml
database:
  url: postgresql://localhost/myapp_development

# config/production.yml
database:
  url: <%= ENV["DATABASE_URL"] %>
```

### 2. Sensitive Data

Never commit sensitive data to version control:

```yaml
# Good: Use environment variables
app:
  secret: <%= ENV["APP_SECRET"] %>

# Bad: Hardcoded secrets
app:
  secret: my-secret-key-here
```

### 3. Default Values

Provide sensible defaults:

```yaml
# Good: Sensible defaults
database:
  pool_size: <%= ENV["DB_POOL_SIZE"] || 10 %>
  timeout: <%= ENV["DB_TIMEOUT"] || 5000 %>

# Bad: No defaults
database:
  pool_size: <%= ENV["DB_POOL_SIZE"] %>
  timeout: <%= ENV["DB_TIMEOUT"] %>
```

### 4. Configuration Organization

Organize configuration logically:

```yaml
# Group related settings
database:
  url: <%= ENV["DATABASE_URL"] %>
  pool_size: <%= ENV["DB_POOL_SIZE"] || 10 %>
  timeout: <%= ENV["DB_TIMEOUT"] || 5000 %>

server:
  host: <%= ENV["HOST"] || "0.0.0.0" %>
  port: <%= ENV["PORT"] || 4000 %>
  workers: <%= ENV["WORKERS"] || 1 %>
```

### 5. Documentation

Document configuration options:

```yaml
# Configuration for MyApp
#
# Environment Variables:
# - DATABASE_URL: PostgreSQL connection string
# - APP_SECRET: Application secret key
# - LOG_LEVEL: Logging level (debug, info, warn, error)

app:
  name: MyApp
  environment: <%= ENV["APP_ENV"] || "development" %>
  secret: <%= ENV["APP_SECRET"] %>
```

## Configuration Commands

### View Configuration

```bash
# Show current configuration
azu config:show

# Show specific section
azu config:show database

# Show configuration for specific environment
azu config:show --env production
```

### Validate Configuration

```bash
# Validate configuration
azu config:validate

# Validate specific environment
azu config:validate --env production
```

### Generate Configuration

```bash
# Generate configuration files
azu config:generate

# Generate for specific environment
azu config:generate --env production
```

## Advanced Configuration

### Custom Configuration Classes

```crystal
# Custom configuration class
class MyAppConfig
  include JSON::Serializable

  property database : DatabaseConfig
  property api : ApiConfig

  class DatabaseConfig
    include JSON::Serializable

    property url : String
    property pool_size : Int32
  end

  class ApiConfig
    include JSON::Serializable

    property base_url : String
    property timeout : Int32
    property retries : Int32
  end
end

# Load custom configuration
config = MyAppConfig.from_yaml(File.read("config/application.yml"))
```

### Dynamic Configuration

```crystal
# Dynamic configuration based on environment
config = case ENV["APP_ENV"]?
when "production"
  ProductionConfig.new
when "test"
  TestConfig.new
else
  DevelopmentConfig.new
end
```

### Configuration Reloading

```crystal
# Reload configuration
Azu::Config.reload

# Reload with specific environment
Azu::Config.reload(:production)

# Watch for configuration changes
Azu::Config.watch do |config|
  puts "Configuration changed: #{config.app.environment}"
end
```

## Troubleshooting Configuration

### Common Issues

#### Missing Environment Variables

```bash
# Error: Missing required environment variable
Error: DATABASE_URL is required

# Solution: Set the environment variable
export DATABASE_URL=postgresql://localhost/myapp_development
```

#### Invalid Configuration Format

```bash
# Error: Invalid YAML format
Error: Invalid YAML at line 5, column 10

# Solution: Check YAML syntax
yamllint config/application.yml
```

#### Configuration Not Loading

```bash
# Error: Configuration file not found
Error: config/application.yml not found

# Solution: Create configuration file
azu config:generate
```

### Debug Configuration

```bash
# Enable configuration debugging
export AZU_CONFIG_DEBUG=true

# Show configuration loading process
azu config:show --debug

# Validate configuration with details
azu config:validate --verbose
```

## Related Documentation

- [Project Configuration](project-config.md) - Project-specific configuration
- [Database Configuration](database-config.md) - Database configuration details
- [Development Server Configuration](dev-server-config.md) - Development server settings
- [Generator Configuration](generator-config.md) - Generator configuration options
- [Environment Variables](environment.md) - Environment variable reference
