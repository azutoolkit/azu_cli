# Configuration System

The Azu CLI configuration system provides a flexible, environment-aware way to manage application settings. It supports multiple configuration formats, environment variable integration, and validation to ensure proper application behavior across different environments.

## Overview

The configuration system is designed to be:

- **Environment-Aware**: Different settings for development, test, and production
- **Secure**: Sensitive data through environment variables
- **Flexible**: Multiple configuration formats (YAML, JSON, environment variables)
- **Validated**: Schema validation and type checking
- **Extensible**: Easy to add new configuration options

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Configuration System                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Config    │  │ Environment │  │   Schema    │          │
│  │   Loader    │  │   Variables │  │ Validator   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   YAML      │  │   JSON      │  │   Default   │          │
│  │   Parser    │  │   Parser    │  │   Values    │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│                    Configuration Store                      │
├─────────────────────────────────────────────────────────────┤
│                    Application Components                   │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### Configuration Loader

The configuration loader manages the loading and merging of configuration from multiple sources:

```crystal
class Azu::Config::Loader
  getter environment : String
  getter config_path : String
  getter config_data : Hash(String, Any)

  def initialize(@environment : String = "development", @config_path : String = "config/azu.yml")
    @config_data = load_configuration
  end

  def load_configuration : Hash(String, Any)
    # Load base configuration
    base_config = load_yaml_file(@config_path)

    # Load environment-specific configuration
    env_config = base_config[@environment]? || {} of String => Any

    # Merge with environment variables
    env_vars_config = load_environment_variables

    # Merge configurations (env vars override file config)
    merge_configurations(base_config, env_config, env_vars_config)
  end

  private def load_yaml_file(path : String) : Hash(String, Any)
    return {} of String => Any unless File.exists?(path)

    YAML.parse(File.read(path)).as_h
  rescue ex
    Azu::Logger.error("Failed to load YAML config: #{ex.message}")
    {} of String => Any
  end

  private def load_environment_variables : Hash(String, Any)
    {
      "database" => {
        "url" => ENV["DATABASE_URL"]?,
        "host" => ENV["AZU_DB_HOST"]?,
        "port" => ENV["AZU_DB_PORT"]?,
        "user" => ENV["AZU_DB_USER"]?,
        "password" => ENV["AZU_DB_PASSWORD"]?,
        "name" => ENV["AZU_DB_NAME"]?
      },
      "server" => {
        "host" => ENV["AZU_HOST"]?,
        "port" => ENV["AZU_PORT"]?
      },
      "app" => {
        "secret" => ENV["APP_SECRET"]?,
        "env" => ENV["AZU_ENV"]?
      }
    }
  end

  private def merge_configurations(*configs) : Hash(String, Any)
    result = {} of String => Any

    configs.each do |config|
      deep_merge!(result, config)
    end

    result
  end

  private def deep_merge!(target : Hash(String, Any), source : Hash(String, Any))
    source.each do |key, value|
      if value.is_a?(Hash) && target[key]?.try(&.is_a?(Hash))
        deep_merge!(target[key].as(Hash(String, Any)), value.as(Hash(String, Any)))
      else
        target[key] = value
      end
    end
  end
end
```

### Configuration Store

The configuration store provides a centralized location for accessing configuration values:

```crystal
class Azu::Config
  @@current : Azu::Config?

  getter database : DatabaseConfig
  getter server : ServerConfig
  getter app : AppConfig
  getter logging : LoggingConfig

  def initialize(config_data : Hash(String, Any))
    @database = DatabaseConfig.new(config_data["database"]? || {} of String => Any)
    @server = ServerConfig.new(config_data["server"]? || {} of String => Any)
    @app = AppConfig.new(config_data["app"]? || {} of String => Any)
    @logging = LoggingConfig.new(config_data["logging"]? || {} of String => Any)
  end

  def self.current : Azu::Config
    @@current ||= load_current
  end

  def self.load_current : Azu::Config
    environment = ENV["AZU_ENV"]? || "development"
    loader = Config::Loader.new(environment)
    new(loader.config_data)
  end

  def self.reload
    @@current = load_current
  end
end
```

### Configuration Classes

Each configuration section has its own class for type safety:

```crystal
class Azu::Config::DatabaseConfig
  getter url : String
  getter host : String
  getter port : Int32
  getter user : String
  getter password : String
  getter name : String
  getter pool_size : Int32

  def initialize(config : Hash(String, Any))
    @url = config["url"]?.try(&.as_s) || "postgresql://localhost/database"
    @host = config["host"]?.try(&.as_s) || "localhost"
    @port = config["port"]?.try(&.as_i) || 5432
    @user = config["user"]?.try(&.as_s) || "postgres"
    @password = config["password"]?.try(&.as_s) || ""
    @name = config["name"]?.try(&.as_s) || "database"
    @pool_size = config["pool_size"]?.try(&.as_i) || 10
  end

  def connection_string : String
    if @url != "postgresql://localhost/database"
      @url
    else
      "postgresql://#{@user}:#{@password}@#{@host}:#{@port}/#{@name}"
    end
  end
end

class Azu::Config::ServerConfig
  getter host : String
  getter port : Int32
  getter watch : Bool
  getter rebuild : Bool

  def initialize(config : Hash(String, Any))
    @host = config["host"]?.try(&.as_s) || "0.0.0.0"
    @port = config["port"]?.try(&.as_i) || 4000
    @watch = config["watch"]?.try(&.as_bool) || true
    @rebuild = config["rebuild"]?.try(&.as_bool) || true
  end
end

class Azu::Config::AppConfig
  getter secret : String
  getter env : String
  getter debug : Bool

  def initialize(config : Hash(String, Any))
    @secret = config["secret"]?.try(&.as_s) || "default-secret-key"
    @env = config["env"]?.try(&.as_s) || "development"
    @debug = config["debug"]?.try(&.as_bool) || false
  end
end

class Azu::Config::LoggingConfig
  getter level : String
  getter format : String
  getter file : String?

  def initialize(config : Hash(String, Any))
    @level = config["level"]?.try(&.as_s) || "info"
    @format = config["format"]?.try(&.as_s) || "default"
    @file = config["file"]?.try(&.as_s)
  end
end
```

## Configuration Files

### YAML Configuration

The primary configuration format is YAML, which provides a clean, readable structure:

```yaml
# config/azu.yml
defaults: &defaults
  database:
    adapter: postgresql
    pool_size: 10
    timeout: 5000

  server:
    host: 0.0.0.0
    port: 4000
    watch: true
    rebuild: true

  logging:
    level: info
    format: default
    colored_output: true

development:
  <<: *defaults
  database:
    url: <%= ENV["DATABASE_URL"] %>
    host: <%= ENV["AZU_DB_HOST"] || "localhost" %>
    port: <%= ENV["AZU_DB_PORT"] || 5432 %>
    user: <%= ENV["AZU_DB_USER"] || "postgres" %>
    password: <%= ENV["AZU_DB_PASSWORD"] || "" %>
    name: <%= ENV["AZU_DB_NAME"] || "myapp_development" %>

  server:
    host: <%= ENV["AZU_HOST"] || "localhost" %>
    port: <%= ENV["AZU_PORT"] || 4000 %>

  logging:
    level: debug

test:
  <<: *defaults
  database:
    url: <%= ENV["DATABASE_URL"] %>
    name: <%= ENV["AZU_DB_NAME"] || "myapp_test" %>

  server:
    port: <%= ENV["AZU_PORT"] || 3001 %>

  logging:
    level: warn

production:
  <<: *defaults
  database:
    url: <%= ENV["DATABASE_URL"] %>
    pool_size: 20

  server:
    host: <%= ENV["AZU_HOST"] || "0.0.0.0" %>
    port: <%= ENV["AZU_PORT"] || 4000 %>
    watch: false
    rebuild: false

  logging:
    level: info
    file: logs/application.log

  app:
    secret: <%= ENV["APP_SECRET"] %>
    env: production
```

### Environment Variables

Environment variables provide secure configuration for sensitive data:

```bash
# Database configuration
export DATABASE_URL="postgresql://user:password@host:5432/database"
export AZU_DB_HOST="localhost"
export AZU_DB_PORT="5432"
export AZU_DB_USER="postgres"
export AZU_DB_PASSWORD="secret"
export AZU_DB_NAME="myapp_development"

# Server configuration
export AZU_HOST="0.0.0.0"
export AZU_PORT="4000"

# Application configuration
export APP_SECRET="your-secret-key-here"
export AZU_ENV="development"

# Development configuration
export AZU_DEBUG="true"
export AZU_VERBOSE="true"
export AZU_QUIET="false"
```

## Configuration Usage

### Accessing Configuration

Configuration values can be accessed throughout the application:

```crystal
# In commands
class Azu::Commands::Serve < Azu::Commands::Base
  def call
    config = Azu::Config.current

    Azu::Logger.info("Starting server on #{config.server.host}:#{config.server.port}")

    server = HTTP::Server.new([
      Azu::Middleware::Logging.new,
      Azu::Middleware::ErrorHandler.new,
      Azu::Router.new
    ])

    server.bind_tcp(config.server.host, config.server.port)
    server.listen
  end
end

# In generators
class Azu::Generators::Base
  def create_file(path : String, content : String)
    config = Azu::Config.current

    if config.app.debug
      Azu::Logger.debug("Creating file: #{path}")
    end

    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    Azu::Logger.info("Created: #{path}")
  end
end

# In database operations
class Azu::Commands::Database < Azu::Commands::Base
  def call
    config = Azu::Config.current

    Azu::Logger.info("Connecting to database: #{config.database.host}:#{config.database.port}")

    # Use database configuration
    connection_string = config.database.connection_string
    # ... database operations
  end
end
```

### Configuration Validation

The configuration system includes validation to ensure proper settings:

```crystal
class Azu::Config::Validator
  def self.validate(config : Azu::Config) : Bool
    validate_database(config.database) &&
    validate_server(config.server) &&
    validate_app(config.app)
  end

  private def self.validate_database(config : DatabaseConfig) : Bool
    if config.url.empty? && config.host.empty?
      Azu::Logger.error("Database URL or host must be configured")
      return false
    end

    if config.port <= 0 || config.port > 65535
      Azu::Logger.error("Invalid database port: #{config.port}")
      return false
    end

    true
  end

  private def self.validate_server(config : ServerConfig) : Bool
    if config.port <= 0 || config.port > 65535
      Azu::Logger.error("Invalid server port: #{config.port}")
      return false
    end

    true
  end

  private def self.validate_app(config : AppConfig) : Bool
    if config.secret == "default-secret-key" && config.env == "production"
      Azu::Logger.error("Default secret key cannot be used in production")
      return false
    end

    true
  end
end
```

## Environment-Specific Configuration

### Development Environment

```yaml
development:
  database:
    url: postgresql://localhost/myapp_development
    pool_size: 5

  server:
    host: localhost
    port: 4000
    watch: true
    rebuild: true

  logging:
    level: debug
    colored_output: true

  app:
    debug: true
    verbose: true
```

### Test Environment

```yaml
test:
  database:
    url: postgresql://localhost/myapp_test
    pool_size: 1

  server:
    host: localhost
    port: 3001
    watch: false
    rebuild: false

  logging:
    level: warn
    colored_output: false

  app:
    debug: false
    verbose: false
```

### Production Environment

```yaml
production:
  database:
    url: <%= ENV["DATABASE_URL"] %>
    pool_size: 20
    timeout: 10000

  server:
    host: 0.0.0.0
    port: <%= ENV["PORT"] || 4000 %>
    watch: false
    rebuild: false

  logging:
    level: info
    file: logs/application.log
    colored_output: false

  app:
    secret: <%= ENV["APP_SECRET"] %>
    debug: false
    verbose: false
```

## Configuration Commands

### Configuration Management

Azu CLI provides commands for managing configuration:

```crystal
class Azu::Commands::Config < Azu::Commands::Base
  def call
    case @subcommand
    when "show"
      show_configuration
    when "validate"
      validate_configuration
    when "init"
      initialize_configuration
    when "reload"
      reload_configuration
    else
      show_help
    end
  end

  private def show_configuration
    config = Azu::Config.current

    puts "Current Configuration:"
    puts "Environment: #{ENV["AZU_ENV"]? || "development"}"
    puts ""
    puts "Database:"
    puts "  URL: #{config.database.url}"
    puts "  Host: #{config.database.host}"
    puts "  Port: #{config.database.port}"
    puts ""
    puts "Server:"
    puts "  Host: #{config.server.host}"
    puts "  Port: #{config.server.port}"
    puts "  Watch: #{config.server.watch}"
    puts ""
    puts "Logging:"
    puts "  Level: #{config.logging.level}"
    puts "  Format: #{config.logging.format}"
  end

  private def validate_configuration
    config = Azu::Config.current

    if Azu::Config::Validator.validate(config)
      Azu::Logger.info("Configuration is valid")
    else
      Azu::Logger.error("Configuration validation failed")
      exit(1)
    end
  end

  private def initialize_configuration
    config_template = File.read("src/templates/config/azu.yml.ecr")
    config_content = ECR.render(config_template, {
      "project_name" => "MyApp",
      "database_adapter" => "postgresql"
    })

    File.write("config/azu.yml", config_content)
    Azu::Logger.info("Configuration file created: config/azu.yml")
  end

  private def reload_configuration
    Azu::Config.reload
    Azu::Logger.info("Configuration reloaded")
  end
end
```

## Configuration Templates

### Default Configuration Template

```yaml
# src/templates/config/azu.yml.ecr
defaults: &defaults
  database:
    adapter: <%= @database_adapter %>
    pool_size: 10
    timeout: 5000

  server:
    host: 0.0.0.0
    port: 4000
    watch: true
    rebuild: true

  logging:
    level: info
    format: default
    colored_output: true

development:
  <<: *defaults
  database:
    url: <%= ENV["DATABASE_URL"] %>
    host: <%= ENV["AZU_DB_HOST"] || "localhost" %>
    port: <%= ENV["AZU_DB_PORT"] || 5432 %>
    user: <%= ENV["AZU_DB_USER"] || "postgres" %>
    password: <%= ENV["AZU_DB_PASSWORD"] || "" %>
    name: <%= ENV["AZU_DB_NAME"] || "<%= @project_name.underscore %>_development" %>

  server:
    host: <%= ENV["AZU_HOST"] || "localhost" %>
    port: <%= ENV["AZU_PORT"] || 4000 %>

  logging:
    level: debug

test:
  <<: *defaults
  database:
    url: <%= ENV["DATABASE_URL"] %>
    name: <%= ENV["AZU_DB_NAME"] || "<%= @project_name.underscore %>_test" %>

  server:
    port: <%= ENV["AZU_PORT"] || 3001 %>

  logging:
    level: warn

production:
  <<: *defaults
  database:
    url: <%= ENV["DATABASE_URL"] %>
    pool_size: 20

  server:
    host: <%= ENV["AZU_HOST"] || "0.0.0.0" %>
    port: <%= ENV["AZU_PORT"] || 4000 %>
    watch: false
    rebuild: false

  logging:
    level: info
    file: logs/application.log

  app:
    secret: <%= ENV["APP_SECRET"] %>
    env: production
```

## Best Practices

### Security

1. **Environment Variables**: Use environment variables for sensitive data
2. **Secret Management**: Never commit secrets to version control
3. **Validation**: Validate configuration before use
4. **Defaults**: Provide secure defaults for all settings

### Organization

1. **Environment Separation**: Keep different environments separate
2. **Inheritance**: Use YAML anchors for common settings
3. **Documentation**: Document all configuration options
4. **Validation**: Include validation for critical settings

### Performance

1. **Lazy Loading**: Load configuration only when needed
2. **Caching**: Cache configuration values
3. **Validation**: Validate configuration once at startup
4. **Reloading**: Support configuration reloading for development

## Related Documentation

- [CLI Framework (Topia)](cli-framework.md) - Command-line interface framework
- [Logging System](logging.md) - Logging configuration and usage
- [Commands Reference](../commands/README.md) - Command documentation
- [Environment Variables](../reference/cli-options.md) - Environment variable reference
