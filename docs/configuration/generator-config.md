# Generator Configuration

The Azu CLI provides a flexible configuration system for customizing code generation behavior. This document covers how to configure generators to match your project's conventions and requirements.

## Overview

Generator configuration allows you to:

- Customize generated code style and structure
- Define project-specific naming conventions
- Configure template paths and custom templates
- Set default options for generators
- Override framework defaults

## Configuration File Location

Generator configuration is stored in your project's `azu.yml` file:

```yaml
# azu.yml
generators:
  # Generator-specific configurations
  endpoint:
    # Endpoint generator options
  model:
    # Model generator options
  # ... other generators
```

## Global Generator Settings

### Base Configuration

```yaml
generators:
  # Global settings applied to all generators
  base:
    # Default namespace for generated code
    namespace: "App"

    # Default directory structure
    directories:
      contracts: "src/contracts"
      endpoints: "src/endpoints"
      models: "src/models"
      pages: "src/pages"
      services: "src/services"
      middlewares: "src/middlewares"
      components: "src/components"
      migrations: "src/db/migrations"

    # Code style preferences
    style:
      indentation: 2
      line_ending: "lf"
      trailing_whitespace: false

    # File naming conventions
    naming:
      case: "snake_case" # snake_case, camelCase, PascalCase
      pluralization: true

    # Template customization
    templates:
      # Custom template paths (optional)
      custom_path: "templates/generators"

    # Default options for all generators
    defaults:
      spec: true
      documentation: true
      validation: true
```

## Generator-Specific Configuration

### Endpoint Generator

```yaml
generators:
  endpoint:
    # Default HTTP methods to generate
    methods: ["index", "show", "new", "create", "edit", "update", "destroy"]

    # Custom route prefixes
    route_prefix: "/api/v1"

    # Response format preferences
    response_format: "json" # json, html, both

    # Authentication requirements
    authentication:
      required: false
      type: "session" # session, token, oauth

    # Authorization patterns
    authorization:
      enabled: true
      pattern: "can_%{action}_%{resource}"

    # Error handling
    error_handling:
      standard_errors: true
      custom_errors: false

    # Documentation generation
    documentation:
      enabled: true
      format: "openapi" # openapi, markdown

    # Testing configuration
    testing:
      framework: "spec"
      coverage: 80
      fixtures: true
```

### Model Generator

```yaml
generators:
  model:
    # ORM configuration
    orm:
      framework: "cql"
      connection: "default"

    # Field types and validations
    fields:
      # Default field types
      defaults:
        string: "String"
        integer: "Int32"
        float: "Float64"
        boolean: "Bool"
        datetime: "Time"
        text: "String"

      # Custom field types
      custom:
        uuid: "UUID"
        json: "JSON::Any"
        array: "Array(String)"

    # Validation patterns
    validations:
      # Default validations for field types
      defaults:
        string:
          - "presence"
          - "length: {min: 1, max: 255}"
        integer:
          - "presence"
        email:
          - "presence"
          - "format: email"

    # Association patterns
    associations:
      # Default association types
      defaults:
        belongs_to: "belongs_to"
        has_many: "has_many"
        has_one: "has_one"
        many_to_many: "has_many :through"

    # Database configuration
    database:
      # Default table naming
      table_naming: "snake_case"

      # Index generation
      indexes:
        primary_key: true
        foreign_keys: true
        timestamps: true

    # Migration generation
    migration:
      auto_generate: true
      include_timestamps: true
      include_soft_deletes: false
```

### Service Generator

```yaml
generators:
  service:
    # Service layer patterns
    patterns:
      # Default service methods
      methods: ["create", "update", "destroy", "find", "list"]

      # Error handling
      error_handling: "exceptions" # exceptions, results, both

      # Transaction handling
      transactions: true

    # Interface generation
    interface:
      enabled: true
      naming: "I%{name}Service"

    # Dependency injection
    dependency_injection:
      enabled: true
      container: "service_container"

    # Testing configuration
    testing:
      mock_framework: "spec"
      test_helpers: true
```

### Page Generator

```yaml
generators:
  page:
    # Template engine
    template_engine: "jinja" # jinja, ecr, custom

    # Layout configuration
    layout:
      default: "layout.jinja"
      extendable: true

    # Asset management
    assets:
      css_framework: "bootstrap" # bootstrap, tailwind, custom
      js_framework: "vanilla" # vanilla, alpine, custom

    # Form handling
    forms:
      csrf_protection: true
      validation: "client_side"

    # Pagination
    pagination:
      enabled: true
      per_page: 20
      style: "bootstrap"
```

### Contract Generator

```yaml
generators:
  contract:
    # Validation framework
    validation:
      framework: "crystal" # crystal, custom

    # Field definitions
    fields:
      # Default field types
      types:
        string: "String"
        integer: "Int32"
        float: "Float64"
        boolean: "Bool"
        datetime: "Time"

    # Validation rules
    validations:
      # Built-in validations
      built_in:
        - "presence"
        - "length"
        - "format"
        - "inclusion"
        - "exclusion"
        - "numericality"

    # Custom validators
    custom_validators:
      enabled: true
      directory: "src/validators"
```

### Component Generator

```yaml
generators:
  component:
    # Component types
    types:
      - "ui"
      - "form"
      - "layout"
      - "business"

    # Template engine
    template_engine: "jinja"

    # Styling approach
    styling:
      approach: "css_classes" # css_classes, inline, scoped
      framework: "bootstrap"

    # JavaScript integration
    javascript:
      framework: "vanilla"
      bundling: false

    # Reusability
    reusability:
      props: true
      slots: true
      events: true
```

### Middleware Generator

```yaml
generators:
  middleware:
    # Middleware types
    types:
      - "authentication"
      - "authorization"
      - "logging"
      - "caching"
      - "rate_limiting"
      - "cors"
      - "custom"

    # Execution order
    execution:
      before: []
      after: []

    # Configuration
    configuration:
      env_based: true
      config_file: true

    # Error handling
    error_handling:
      graceful: true
      logging: true
```

## Environment-Specific Configuration

You can override generator settings based on the environment:

```yaml
generators:
  endpoint:
    # Development environment
    development:
      documentation: false
      testing: false

    # Production environment
    production:
      documentation: true
      testing: true
      error_handling:
        detailed_errors: false
```

## Custom Templates

### Template Override

To use custom templates instead of the default ones:

```yaml
generators:
  endpoint:
    templates:
      # Override specific templates
      custom:
        create_endpoint: "templates/custom/create_endpoint.cr.ecr"
        show_endpoint: "templates/custom/show_endpoint.cr.ecr"

      # Use completely custom template directory
      directory: "templates/generators"
```

### Template Variables

Custom templates can use the same variables as built-in templates:

```crystal
# Available variables in templates
class_name: String
resource_name: String
namespace: String
methods: Array(String)
# ... and more
```

## Configuration Inheritance

Generator configurations inherit from parent levels:

1. **Global defaults** (built into Azu CLI)
2. **Project configuration** (`azu.yml`)
3. **Environment-specific** overrides
4. **Command-line** options

Later configurations override earlier ones.

## Validation

The CLI validates your generator configuration:

```bash
# Validate configuration
azu config validate

# Check specific generator config
azu config validate --generator endpoint
```

## Examples

### Minimal Configuration

```yaml
# azu.yml
generators:
  endpoint:
    methods: ["index", "show", "create", "update", "destroy"]
  model:
    orm:
      framework: "cql"
```

### Comprehensive Configuration

```yaml
# azu.yml
generators:
  base:
    namespace: "MyApp"
    directories:
      contracts: "src/contracts"
      endpoints: "src/endpoints"
      models: "src/models"
    style:
      indentation: 2
    naming:
      case: "snake_case"

  endpoint:
    methods: ["index", "show", "new", "create", "edit", "update", "destroy"]
    route_prefix: "/api/v1"
    response_format: "json"
    authentication:
      required: true
      type: "token"
    authorization:
      enabled: true
    testing:
      framework: "spec"
      coverage: 90

  model:
    orm:
      framework: "cql"
    fields:
      defaults:
        string: "String"
        integer: "Int32"
    validations:
      defaults:
        string:
          - "presence"
          - "length: {min: 1, max: 255}"
    migration:
      auto_generate: true
      include_timestamps: true

  service:
    patterns:
      methods: ["create", "update", "destroy", "find", "list"]
    error_handling: "exceptions"
    transactions: true
    interface:
      enabled: true
```

## Best Practices

1. **Start Simple**: Begin with minimal configuration and add complexity as needed
2. **Be Consistent**: Use consistent naming and structure across your project
3. **Environment Awareness**: Use environment-specific overrides for different deployment stages
4. **Version Control**: Include your `azu.yml` in version control for team consistency
5. **Documentation**: Document any custom configurations for team members
6. **Testing**: Test generated code to ensure configurations work as expected

## Troubleshooting

### Common Issues

**Configuration not applied**: Ensure your `azu.yml` is in the project root and properly formatted.

**Template not found**: Check that custom template paths are correct and files exist.

**Validation errors**: Use `azu config validate` to check for configuration issues.

**Inheritance problems**: Verify the configuration hierarchy and override order.

### Debugging

Enable verbose output to see how configuration is being applied:

```bash
azu generate endpoint users --verbose
```

This will show which configuration values are being used for generation.
