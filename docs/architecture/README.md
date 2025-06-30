# Architecture Overview

This document provides a comprehensive overview of the Azu CLI architecture, including its core components, design principles, and how they work together.

## Overview

Azu CLI is built on top of the Azu Toolkit framework and provides a command-line interface for rapid application development. It follows a modular, extensible architecture that promotes code reusability and maintainability.

## Core Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Azu CLI Application                      │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Commands  │  │ Generators  │  │  Templates  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Config    │  │   Logger    │  │   Utils     │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│                    Topia CLI Framework                      │
├─────────────────────────────────────────────────────────────┤
│                    Crystal Language                         │
└─────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. Command System

The command system is built on top of the Topia CLI framework and provides:

- **Command Parsing**: Automatic parsing of command-line arguments and options
- **Help System**: Built-in help generation for all commands
- **Subcommands**: Hierarchical command structure
- **Middleware**: Command-level middleware for cross-cutting concerns

```crystal
class Azu::Commands::Generate < Azu::Commands::Base
  def call
    case @subcommand
    when "model"
      Azu::Generators::Model.new(@name, @options).generate
    when "endpoint"
      Azu::Generators::Endpoint.new(@name, @options).generate
    # ... other generators
    end
  end
end
```

### 2. Generator System

The generator system is responsible for creating new files and code structures:

- **Base Generator**: Common functionality for all generators
- **Template Engine**: ECR-based templating for code generation
- **File Operations**: Safe file creation and directory management
- **Validation**: Input validation and error handling

```crystal
class Azu::Generators::Base
  abstract def generate
  abstract def template_path : String

  def render_template(context : Hash(String, String)) : String
    ECR.render(template_path, context)
  end
end
```

### 3. Template System

Templates use Crystal's ECR (Embedded Crystal) for code generation:

- **ECR Templates**: Crystal code embedded in templates
- **Variable Substitution**: Dynamic content generation
- **Conditional Logic**: Template branching based on options
- **Reusable Components**: Shared template fragments

```crystal
# Template example
class <%= @name.camelcase %> < CQL::Model
  table :<%= @name.underscore.pluralize %>

  <% @attributes.each do |attr| %>
  column :<%= attr.name %>, <%= attr.type %>
  <% end %>

  timestamps
end
```

### 4. Configuration System

The configuration system manages application settings:

- **YAML Configuration**: Human-readable configuration format
- **Environment Variables**: Secure configuration management
- **Default Values**: Sensible defaults for all settings
- **Validation**: Configuration schema validation

```yaml
# config/application.yml
database:
  url: <%= ENV["DATABASE_URL"] %>
  pool_size: <%= ENV["DB_POOL_SIZE"] || 10 %>

server:
  host: <%= ENV["HOST"] || "0.0.0.0" %>
  port: <%= ENV["PORT"] || 3000 %>
```

### 5. Logging System

The logging system provides structured logging capabilities:

- **Multiple Levels**: Debug, Info, Warn, Error, Fatal
- **Structured Output**: JSON and human-readable formats
- **Context Support**: Request context and correlation IDs
- **Performance**: Minimal overhead logging

```crystal
class Azu::Logger
  def self.info(message : String, context : Hash(String, String) = {} of String => String)
    Log.info { format_message(message, context) }
  end
end
```

## Design Principles

### 1. Modularity

Each component is designed to be independent and replaceable:

- **Loose Coupling**: Components communicate through well-defined interfaces
- **High Cohesion**: Related functionality is grouped together
- **Single Responsibility**: Each class has one clear purpose
- **Dependency Injection**: Dependencies are injected rather than hardcoded

### 2. Extensibility

The system is designed to be easily extended:

- **Plugin System**: Third-party plugins can extend functionality
- **Custom Generators**: Users can create custom generators
- **Template Customization**: Templates can be customized or replaced
- **Command Extensions**: New commands can be added dynamically

### 3. Consistency

Consistent patterns throughout the codebase:

- **Naming Conventions**: Consistent naming across all components
- **Error Handling**: Uniform error handling patterns
- **Configuration**: Consistent configuration management
- **Documentation**: Comprehensive documentation for all components

### 4. Performance

Performance considerations in design:

- **Compile-time Optimization**: Leveraging Crystal's compile-time features
- **Lazy Loading**: Loading components only when needed
- **Caching**: Intelligent caching of frequently used data
- **Memory Management**: Efficient memory usage patterns

## Data Flow

### Command Execution Flow

```
1. User Input → Command Parser
2. Command Parser → Command Router
3. Command Router → Command Handler
4. Command Handler → Generator/Service
5. Generator/Service → Template Engine
6. Template Engine → File System
7. File System → User Feedback
```

### Configuration Flow

```
1. Application Start → Config Loader
2. Config Loader → Environment Variables
3. Environment Variables → YAML Parser
4. YAML Parser → Config Validator
5. Config Validator → Config Store
6. Config Store → Application Components
```

## File Organization

### Source Code Structure

```
src/
├── azu_cli.cr                   # Main entry point
├── azu_cli/
│   ├── command.cr               # Base command class
│   ├── commands/                # Command implementations
│   │   ├── new.cr               # Project creation
│   │   ├── generate.cr          # Code generation
│   │   ├── serve.cr             # Development server
│   │   └── db.cr                # Database operations
│   ├── generators/              # Generator implementations
│   │   ├── base.cr              # Base generator
│   │   ├── model.cr             # Model generator
│   │   ├── endpoint.cr          # Endpoint generator
│   │   └── project.cr           # Project generator
│   ├── templates/               # ECR templates
│   │   ├── generators/          # Generator templates
│   │   └── project/             # Project templates
│   ├── config.cr                # Configuration management
│   ├── logger.cr                # Logging system
│   └── utils.cr                 # Utility functions
```

### Template Structure

```
src/templates/
├── generators/                   # Generator templates
│   ├── model/                   # Model generator templates
│   │   ├── model.cr.ecr         # Model class template
│   │   └── model_spec.cr.ecr    # Model test template
│   ├── endpoint/                # Endpoint generator templates
│   │   ├── index_endpoint.cr.ecr
│   │   ├── show_endpoint.cr.ecr
│   │   └── endpoint_spec.cr.ecr
│   └── project/                 # Project templates
│       ├── basic/               # Basic project template
│       ├── api/                 # API project template
│       └── web/                 # Web project template
```

## Integration Points

### 1. Azu Framework Integration

Azu CLI integrates with the Azu framework through:

- **Framework Detection**: Automatic detection of Azu projects
- **Configuration Sharing**: Shared configuration between CLI and framework
- **Template Compatibility**: Templates that work with framework conventions
- **Development Tools**: Tools that understand framework structure

### 2. Crystal Language Integration

Deep integration with Crystal language features:

- **Type System**: Leveraging Crystal's static type system
- **Macros**: Using Crystal macros for code generation
- **Compile-time**: Compile-time optimizations and checks
- **Standard Library**: Using Crystal's standard library components

### 3. Database Integration

Database integration through CQL ORM:

- **Migration Generation**: Automatic migration file generation
- **Model Generation**: CQL-compatible model generation
- **Schema Management**: Database schema management tools
- **Query Building**: CQL query building support

## Security Considerations

### 1. Input Validation

- **Command Arguments**: Validation of all command-line arguments
- **File Paths**: Safe file path handling to prevent directory traversal
- **Template Variables**: Validation of template variable substitution
- **Configuration**: Validation of configuration values

### 2. File Operations

- **Safe File Creation**: Preventing overwriting of existing files
- **Permission Management**: Appropriate file permissions
- **Path Sanitization**: Sanitizing file paths and names
- **Backup Creation**: Creating backups before destructive operations

### 3. Configuration Security

- **Environment Variables**: Secure handling of sensitive configuration
- **Secret Management**: Proper secret management practices
- **Access Control**: Controlling access to configuration files
- **Audit Logging**: Logging configuration changes

## Performance Characteristics

### 1. Startup Time

- **Lazy Loading**: Components loaded only when needed
- **Compile-time Optimization**: Leveraging Crystal's compile-time features
- **Caching**: Caching frequently accessed data
- **Minimal Dependencies**: Keeping dependencies minimal

### 2. Memory Usage

- **Efficient Data Structures**: Using appropriate data structures
- **Memory Pooling**: Reusing objects where possible
- **Garbage Collection**: Working with Crystal's GC effectively
- **Resource Cleanup**: Proper resource cleanup

### 3. File I/O Performance

- **Buffered I/O**: Using buffered I/O operations
- **Batch Operations**: Batching file operations where possible
- **Async Operations**: Using async operations for I/O
- **Caching**: Caching file system operations

## Testing Strategy

### 1. Unit Testing

- **Component Isolation**: Testing components in isolation
- **Mock Objects**: Using mocks for external dependencies
- **Edge Cases**: Testing edge cases and error conditions
- **Performance Tests**: Testing performance characteristics

### 2. Integration Testing

- **End-to-End**: Testing complete workflows
- **File System**: Testing file system operations
- **Configuration**: Testing configuration management
- **Generator Pipeline**: Testing the complete generation pipeline

### 3. Acceptance Testing

- **User Scenarios**: Testing real user scenarios
- **Command Line**: Testing command-line interface
- **Output Validation**: Validating generated output
- **Error Handling**: Testing error handling scenarios

## Future Architecture Considerations

### 1. Plugin System

- **Dynamic Loading**: Dynamic plugin loading
- **Plugin Registry**: Centralized plugin registry
- **Version Compatibility**: Plugin version compatibility
- **Security**: Plugin security and sandboxing

### 2. Cloud Integration

- **Cloud Providers**: Integration with cloud providers
- **Deployment**: Automated deployment capabilities
- **Monitoring**: Application monitoring integration
- **Scaling**: Auto-scaling capabilities

### 3. AI/ML Integration

- **Code Suggestions**: AI-powered code suggestions
- **Pattern Recognition**: Automatic pattern recognition
- **Optimization**: AI-powered optimization suggestions
- **Documentation**: Automated documentation generation

## Related Documentation

- [CLI Framework (Topia)](cli-framework.md) - Detailed Topia integration
- [Generator System](generator-system.md) - Generator architecture details
- [Template Engine (ECR)](template-engine.md) - Template system architecture
- [Configuration System](configuration.md) - Configuration management
- [Logging System](logging.md) - Logging architecture
- [Plugin System](plugins.md) - Plugin architecture and development
