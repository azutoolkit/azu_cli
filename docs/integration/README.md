# Framework Integration

The Azu CLI is designed to integrate seamlessly with the broader Crystal ecosystem and various development tools. This section covers how to integrate the CLI with different frameworks, libraries, and external services.

## Overview

Integration capabilities include:

- **Azu Web Framework**: Native integration with the Azu toolkit
- **CQL ORM**: Database integration and model generation
- **Third-party Libraries**: Support for popular Crystal libraries
- **Development Tools**: IDE and editor integration
- **CI/CD Systems**: Automated deployment and testing
- **Cloud Platforms**: Deployment to various cloud providers

## Integration Types

### Framework Integration

- [Azu Web Framework](azu-framework.md) - Core framework integration
- [CQL ORM](cql-orm.md) - Database and model management
- [Third-party Libraries](third-party.md) - External library support

### Development Tools

- **IDE Support**: VS Code, Vim, Emacs extensions
- **Editor Integration**: Syntax highlighting, autocompletion
- **Debugging**: Integration with Crystal debuggers
- **Testing**: Test framework integration

### Deployment & DevOps

- **Containerization**: Docker and Kubernetes support
- **Cloud Platforms**: AWS, Google Cloud, Azure integration
- **CI/CD**: GitHub Actions, GitLab CI, Jenkins
- **Monitoring**: Application performance monitoring

## Quick Integration Guide

### 1. Framework Setup

```bash
# Create new Azu project with full integration
azu new myapp --framework=azu --orm=cql

# Initialize existing project
azu init --framework=azu --orm=cql
```

### 2. Database Integration

```bash
# Set up database connection
azu db setup --adapter=postgresql

# Generate models with CQL integration
azu generate model User email:string name:string
```

### 3. Development Workflow

```bash
# Start development server with hot reload
azu serve --reload

# Run tests with framework integration
azu test --framework=spec
```

## Integration Benefits

### Developer Experience

- **Unified Workflow**: Single CLI for all development tasks
- **Code Generation**: Consistent patterns across projects
- **Hot Reloading**: Instant feedback during development
- **Error Handling**: Framework-aware error messages

### Performance

- **Optimized Builds**: Framework-specific optimizations
- **Caching**: Intelligent caching for faster builds
- **Bundle Analysis**: Performance insights and optimization

### Maintainability

- **Consistent Patterns**: Enforced coding standards
- **Documentation**: Auto-generated API documentation
- **Testing**: Integrated testing frameworks
- **Migration Management**: Database schema evolution

## Configuration Integration

### Framework Configuration

```yaml
# azu.yml
framework:
  name: "azu"
  version: "latest"

integration:
  orm: "cql"
  template_engine: "jinja"
  authentication: "authly"
  background_jobs: "joobq"
```

### Environment Integration

```bash
# Development environment
export AZU_FRAMEWORK_ENV=development
export AZU_DATABASE_URL=postgresql://localhost/myapp_dev

# Production environment
export AZU_FRAMEWORK_ENV=production
export AZU_DATABASE_URL=postgresql://user:pass@prod-db/myapp_prod
```

## Migration from Other Tools

### From Rails/Other Frameworks

```bash
# Generate migration guide
azu migration guide --from=rails

# Convert existing models
azu migration convert --input=rails_models --output=cql_models
```

### From Manual Setup

```bash
# Analyze existing project
azu analyze --project=./existing-project

# Generate integration plan
azu integration plan --framework=azu
```

## Troubleshooting Integration

### Common Issues

**Framework Version Mismatch**: Ensure compatible versions between CLI and framework.

**Database Connection Issues**: Verify database configuration and connectivity.

**Template Engine Conflicts**: Check template engine configuration and file extensions.

**Authentication Integration**: Validate authentication provider configuration.

### Debugging Integration

```bash
# Check integration status
azu integration status

# Validate framework configuration
azu integration validate --framework=azu

# Test database connectivity
azu integration test --database
```

## Best Practices

### Framework Integration

1. **Version Compatibility**: Keep CLI and framework versions in sync
2. **Configuration Management**: Use environment-specific configurations
3. **Testing Strategy**: Test integration points thoroughly
4. **Documentation**: Document custom integration patterns

### Development Workflow

1. **Consistent Commands**: Use CLI commands for all development tasks
2. **Automated Testing**: Integrate testing into your workflow
3. **Code Generation**: Leverage generators for consistency
4. **Performance Monitoring**: Monitor integration performance

### Deployment Integration

1. **Environment Configuration**: Use proper environment variables
2. **Database Migrations**: Run migrations as part of deployment
3. **Health Checks**: Implement proper health check endpoints
4. **Monitoring**: Set up application monitoring and alerting

## Advanced Integration

### Custom Integrations

```crystal
# Custom integration example
module MyCustomIntegration
  extend Azu::Integration::Base

  def self.setup
    # Custom setup logic
  end

  def self.validate
    # Custom validation
  end
end
```

### Plugin Development

```crystal
# Integration plugin
class MyIntegrationPlugin < Azu::Plugin
  def initialize
    @name = "my_integration"
    @version = "1.0.0"
  end

  def install
    # Installation logic
  end

  def configure(config)
    # Configuration logic
  end
end
```

## Support and Community

### Getting Help

- **Documentation**: Comprehensive integration guides
- **Community**: Discord, GitHub discussions
- **Examples**: Sample projects and integration patterns
- **Tutorials**: Step-by-step integration guides

### Contributing

- **Integration Development**: Create new integrations
- **Documentation**: Improve integration guides
- **Testing**: Test integration scenarios
- **Feedback**: Report issues and suggest improvements

## Next Steps

1. **Choose Your Framework**: Select the appropriate framework integration
2. **Set Up Database**: Configure CQL ORM integration
3. **Configure Development**: Set up development environment
4. **Deploy**: Choose deployment strategy and platform
5. **Monitor**: Set up monitoring and alerting

For specific integration details, see the individual integration guides:

- [Azu Web Framework Integration](azu-framework.md)
- [CQL ORM Integration](cql-orm.md)
- [Third-party Library Integration](third-party.md)
