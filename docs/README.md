# Azu CLI Documentation

Welcome to the comprehensive documentation for **Azu CLI** - the command-line interface for the Azu Toolkit ecosystem.

## What is Azu CLI?

Azu CLI is a powerful, developer-friendly command-line tool designed to accelerate development with the Azu Toolkit framework. It provides scaffolding, code generation, development server capabilities, and database management tools to help you build high-performance, type-safe Crystal applications quickly and efficiently.

## Key Features

### **Project Scaffolding**

- Create new Azu projects with a single command
- Initialize Azu in existing Crystal projects
- Multiple project templates (web, API, CLI)
- Interactive project setup wizard

### **Code Generation**

- Generate endpoints (controllers) with full CRUD operations
- Create CQL ORM models with attributes
- Build services following DDD patterns
- Generate middleware components
- Create request/response contracts
- Build page components and templates
- Generate real-time live components
- Create custom validators
- Database migration generation
- Complete resource scaffolding

### **Development Tools**

- Hot-reloading development server
- File system watching and auto-compilation
- Database management commands
- Interactive console (REPL)
- Testing framework integration
- Real-time error reporting

### **Framework Integration**

- **Azu Web Framework**: High-performance, type-safe web framework
- **CQL ORM**: Crystal Query Language Object-Relational Mapping
- **Topia CLI**: Powerful command-line parsing framework

## Who Is This For?

- **Crystal Developers** building web applications with Azu
- **Backend Developers** creating APIs and microservices
- **Full-Stack Developers** building real-time applications
- **DevOps Engineers** deploying Crystal applications
- **Teams** looking for consistent development workflows

## What You Can Build

- **Web Applications**: Full-featured web apps with real-time capabilities
- **REST APIs**: Type-safe, high-performance API services
- **Real-time Applications**: WebSocket-powered live applications
- **Microservices**: Distributed service architectures
- **CLI Tools**: Command-line applications using Crystal
- **Background Jobs**: Asynchronous job processing systems

## Prerequisites

Before using Azu CLI, ensure you have:

- **Crystal**: Version 1.6.0 or higher
- **Database**: PostgreSQL, MySQL, or SQLite
- **Git**: For version control and project management
- **Node.js**: (Optional) For frontend asset management

## Getting Started

1. **[Install Azu CLI](getting-started/installation.md)** - Installation instructions for all platforms
2. **[Quick Start Guide](getting-started/quick-start.md)** - Create your first Azu application in minutes
3. **[Project Structure](getting-started/project-structure.md)** - Understand how Azu projects are organized

## 📚 Documentation Sections

### Command Reference

Comprehensive guide to all CLI commands, their options, and usage examples.

### Generators

Detailed documentation for all code generators including templates, customization, and best practices.

### Development Workflows

Step-by-step guides for common development scenarios and patterns.

### Architecture & Internals

Deep dive into how Azu CLI works internally, useful for contributors and advanced users.

### Configuration

Complete configuration reference for projects, databases, and development environments.

### Examples & Tutorials

Hands-on tutorials building real applications with Azu CLI.

### Integration

How to integrate Azu CLI with other tools and frameworks in the Crystal ecosystem.

### Troubleshooting

Solutions to common issues and problems you might encounter.

## Quick Examples

### Create a New Project

```bash
# Create a new web application
azu new my_blog --type web --database postgres

# Create an API-only application
azu new my_api --type api --database mysql
```

### Generate Components

```bash
# Generate a complete blog post resource
azu generate scaffold Post title:string content:text published:boolean

# Generate a user model
azu generate model User name:string email:string

# Generate a real-time component
azu generate component Counter count:integer --websocket
```

### Development Server

```bash
# Start development server with hot reloading
azu serve --port 4000

# Start in development mode (alias)
azu dev
```

### Database Operations

```bash
# Create and migrate database
azu db:create
azu db:migrate

# Seed with sample data
azu db:seed
```

### OpenAPI Integration

```bash
# Generate code from OpenAPI specification
azu openapi:generate api-spec.yaml

# Export OpenAPI specification from code
azu openapi:export --output api.yaml
```

## Community & Support

- **GitHub Repository**: [azutoolkit/azu_cli](https://github.com/azutoolkit/azu_cli)
- **Azu Toolkit Documentation**: [azutopia.gitbook.io/azu](https://azutopia.gitbook.io/azu/)
- **Crystal Language**: [crystal-lang.org](https://crystal-lang.org/)
- **Issues & Bug Reports**: [GitHub Issues](https://github.com/azutoolkit/azu_cli/issues)

## License

Azu CLI is open source software licensed under the [MIT License](https://github.com/azutoolkit/azu_cli/blob/master/LICENSE).

## Related Projects

- **[Azu Web Framework](https://github.com/azutoolkit/azu)**: The core web framework
- **[CQL ORM](https://github.com/azutoolkit/cql)**: Crystal Query Language ORM
- **[Topia](https://github.com/azutoolkit/topia)**: CLI framework used by Azu CLI
- **[CQL ORM](https://github.com/azutoolkit/cql)**: Crystal Query Language ORM

---

Ready to get started? Head over to the [Installation Guide](getting-started/installation.md) or jump straight into the [Quick Start](getting-started/quick-start.md) tutorial!
