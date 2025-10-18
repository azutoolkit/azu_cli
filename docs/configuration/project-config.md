# Project Configuration

Project configuration in Azu CLI manages project-specific settings, metadata, and build configurations. This includes project name, version, dependencies, build settings, and other project-wide options.

## Overview

Project configuration is stored in multiple files and locations:

- **`shard.yml`**: Crystal project metadata and dependencies
- **`config/azu.yml`**: Azu-specific project configuration
- **`config/application.yml`**: Application-wide settings
- **`.env`**: Local environment variables (optional)

## Project Metadata

### Shard Configuration (`shard.yml`)

The `shard.yml` file contains Crystal project metadata and dependencies:

```yaml
name: my-azu-app
version: 0.1.0

authors:
  - Your Name <your.email@example.com>

targets:
  my-azu-app:
    main: src/main.cr

dependencies:
  azu:
    github: azutoolkit/azu
    version: ~> 0.1.0
  cql:
    github: azutoolkit/cql
    version: ~> 0.1.0
  topia:
    github: azutoolkit/topia
    version: ~> 0.1.0

development_dependencies:
  spec2:
    github: waterlink/spec2.cr
    version: ~> 0.1.0

crystal: ">= 1.0.0"

license: MIT
```

### Project Configuration (`config/azu.yml`)

The main Azu project configuration file:

```yaml
# Project metadata
project:
  name: <%= @project_name %>
  version: 0.1.0
  description: <%= @project_description || "A Crystal web application built with Azu" %>
  author: <%= @project_author || "Your Name" %>
  email: <%= @project_email || "your.email@example.com" %>
  license: MIT

# Build configuration
build:
  target: <%= @project_name.underscore %>
  main_file: src/main.cr
  output_dir: bin/
  static: false
  release: false
  debug: true

# Development settings
development:
  auto_reload: true
  watch_paths:
    - src/
    - config/
    - public/
  ignored_paths:
    - .git/
    - node_modules/
    - .crystal/
    - bin/
  port: 4000
  host: localhost

# Testing configuration
testing:
  framework: spec2
  coverage: true
  parallel: true
  timeout: 30

# Documentation
documentation:
  generate: true
  output_dir: docs/
  format: markdown
  include_examples: true
```

## Project Structure Configuration

### Directory Layout

Configure the project directory structure:

```yaml
# Project structure configuration
structure:
  src:
    - models/
    - endpoints/
    - pages/
    - contracts/
    - services/
    - middleware/
    - components/
    - db/
      - migrations/
      - schema.cr
      - seed.cr
    - initializers/
      - database.cr
      - logger.cr
    - main.cr
    - server.cr

  spec:
    - models/
    - endpoints/
    - services/
    - spec_helper.cr

  config:
    - application.yml
    - database.yml
    - azu.yml

  public:
    - assets/
      - css/
      - js/
      - images/
    - templates/
      - helpers/
      - pages/

  docs:
    - api/
    - guides/
    - examples/

  tasks:
    - taskfile.cr
```

### Custom Directory Configuration

Override default directory paths:

```yaml
# Custom directory paths
paths:
  source: src/
  tests: spec/
  config: config/
  public: public/
  docs: docs/
  tasks: tasks/
  logs: logs/
  tmp: tmp/
  cache: .cache/
```

## Build Configuration

### Compilation Settings

Configure Crystal compilation options:

```yaml
# Build configuration
build:
  # Target configuration
  target: my-app
  main_file: src/main.cr
  output_dir: bin/

  # Compilation flags
  flags:
    - --release
    - --no-debug
    - --static
    - --threads 4

  # Conditional compilation
  defines:
    - PRODUCTION
    - ENABLE_LOGGING

  # Optimization
  optimization:
    level: 2
    strip_symbols: true
    link_flags: ["-static"]

  # Cross-compilation
  cross_compile:
    enabled: false
    targets:
      - linux-x86_64
      - darwin-x86_64
```

### Development Build

Development-specific build settings:

```yaml
# Development build configuration
development:
  build:
    debug: true
    warnings: true
    incremental: true
    parallel: true
    cache_dir: .crystal/

    # Fast compilation for development
    flags:
      - --debug
      - --warnings
      - --no-debug
      - --threads 2
```

### Production Build

Production build configuration:

```yaml
# Production build configuration
production:
  build:
    release: true
    static: true
    optimize: true

    flags:
      - --release
      - --no-debug
      - --static
      - --threads 4
      - -D PRODUCTION

    # Security hardening
    security:
      stack_protector: true
      relro: true
      now: true
```

## Dependency Management

### Crystal Dependencies

Manage Crystal shard dependencies:

```yaml
# Dependencies configuration
dependencies:
  # Core framework
  azu:
    github: azutoolkit/azu
    version: ~> 0.1.0

  # Database ORM
  cql:
    github: azutoolkit/cql
    version: ~> 0.1.0

  # CLI framework
  topia:
    github: azutoolkit/topia
    version: ~> 0.1.0

  # Database adapters
  pg:
    github: will/crystal-pg
    version: ~> 0.27.0

  # Template engine
  jinja:
    github: azutoolkit/jinja
    version: ~> 0.1.0

  # Utilities
  cadmium_inflector:
    github: cadmiumcr/inflector
    version: ~> 0.1.0

development_dependencies:
  spec2:
    github: waterlink/spec2.cr
    version: ~> 0.1.0

  ameba:
    github: crystal-ameba/ameba
    version: ~> 1.5.0
```

### External Dependencies

Configure external system dependencies:

```yaml
# External dependencies
external_dependencies:
  # Database
  postgresql:
    version: ">= 12.0"
    required: true

  # Node.js (for frontend assets)
  nodejs:
    version: ">= 16.0"
    required: false

  # Redis (for caching)
  redis:
    version: ">= 6.0"
    required: false

  # System libraries
  system_libs:
    - libssl-dev
    - libreadline-dev
    - libpq-dev
```

## Testing Configuration

### Test Framework Settings

Configure testing framework and options:

```yaml
# Testing configuration
testing:
  # Framework
  framework: spec2

  # Test execution
  execution:
    parallel: true
    timeout: 30
    coverage: true
    coverage_threshold: 80

  # Test directories
  directories:
    - spec/
    - test/

  # Test patterns
  patterns:
    - "*_spec.cr"
    - "*_test.cr"

  # Test environment
  environment:
    database: test
    logging: warn
    debug: false

  # Test data
  fixtures:
    directory: spec/fixtures/
    load_automatically: true
```

### Code Quality

Configure code quality tools:

```yaml
# Code quality configuration
quality:
  # Linting
  ameba:
    enabled: true
    config: .ameba.yml
    fail_on_warnings: false

  # Formatting
  crystal_format:
    enabled: true
    check_only: false

  # Security scanning
  security:
    enabled: true
    tools:
      - bandit
      - safety

  # Documentation
  documentation:
    generate: true
    coverage: true
    format: markdown
```

## Documentation Configuration

### API Documentation

Configure API documentation generation:

```yaml
# Documentation configuration
documentation:
  # API documentation
  api:
    generate: true
    output_dir: docs/api/
    format: markdown
    include_examples: true
    include_tests: true

  # User guides
  guides:
    generate: true
    output_dir: docs/guides/
    templates_dir: docs/templates/

  # Examples
  examples:
    generate: true
    output_dir: docs/examples/
    include_source: true

  # README generation
  readme:
    generate: true
    template: docs/templates/README.md.ecr
    include_installation: true
    include_usage: true
    include_api: true
```

## Deployment Configuration

### Deployment Settings

Configure deployment options:

```yaml
# Deployment configuration
deployment:
  # Build for deployment
  build:
    target: production
    static: true
    optimize: true

  # Docker configuration
  docker:
    enabled: true
    base_image: crystallang/crystal:1.16.0-alpine
    multi_stage: true
    optimize_size: true

  # Environment configuration
  environments:
    staging:
      build_target: staging
      database_url: <%= ENV["STAGING_DATABASE_URL"] %>
      domain: staging.example.com

    production:
      build_target: production
      database_url: <%= ENV["PRODUCTION_DATABASE_URL"] %>
      domain: example.com
```

## Environment-Specific Configuration

### Development Environment

```yaml
# config/development.yml
project:
  name: my-app-dev
  debug: true

development:
  auto_reload: true
  port: 4000
  host: localhost

build:
  debug: true
  warnings: true
  incremental: true

testing:
  parallel: false
  coverage: true
```

### Test Environment

```yaml
# config/test.yml
project:
  name: my-app-test
  debug: false

development:
  auto_reload: false
  port: 3001

build:
  debug: false
  warnings: false

testing:
  parallel: true
  coverage: true
  database: test
```

### Production Environment

```yaml
# config/production.yml
project:
  name: my-app
  debug: false

development:
  auto_reload: false
  port: <%= ENV["PORT"] || 3000 %>
  host: 0.0.0.0

build:
  release: true
  static: true
  optimize: true

testing:
  parallel: true
  coverage: false
```

## Configuration Commands

### Project Configuration Commands

Azu CLI provides commands for managing project configuration:

```bash
# Initialize project configuration
azu init --config

# Show current configuration
azu config show

# Validate configuration
azu config validate

# Generate configuration template
azu config generate

# Update configuration
azu config update
```

### Configuration Management

```crystal
# In your application
require "azu_cli"

# Access project configuration
config = Azu::Config.current

# Project metadata
puts "Project: #{config.project.name}"
puts "Version: #{config.project.version}"

# Build settings
puts "Build target: #{config.build.target}"
puts "Main file: #{config.build.main_file}"

# Development settings
puts "Auto reload: #{config.development.auto_reload}"
puts "Port: #{config.development.port}"
```

## Best Practices

### Configuration Organization

1. **Separate Concerns**: Keep different types of configuration separate
2. **Environment Variables**: Use environment variables for sensitive data
3. **Default Values**: Provide sensible defaults for all settings
4. **Validation**: Validate configuration at startup
5. **Documentation**: Document all configuration options

### Security

1. **Secrets Management**: Never commit secrets to version control
2. **Environment Variables**: Use environment variables for sensitive data
3. **Access Control**: Restrict access to configuration files
4. **Validation**: Validate configuration values

### Performance

1. **Lazy Loading**: Load configuration only when needed
2. **Caching**: Cache configuration values
3. **Validation**: Validate configuration once at startup
4. **Optimization**: Use appropriate build settings for each environment

## Related Documentation

- [Configuration Overview](README.md) - General configuration guide
- [Database Configuration](database-config.md) - Database-specific configuration
- [Development Server Configuration](dev-server-config.md) - Development server settings
- [Generator Configuration](generator-config.md) - Code generation configuration
- [Environment Variables](environment.md) - Environment variable reference
