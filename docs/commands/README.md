# Command Reference

Azu CLI provides a comprehensive set of commands to help you develop, manage, and deploy your Azu applications. This reference covers all available commands, their options, and usage examples.

## Command Overview

### Project Management

- [`azu new`](new.md) - Create a new Azu project
- [`azu init`](init.md) - Initialize Azu in an existing project

### Code Generation

- [`azu generate`](generate.md) - Generate application components

### Development Tools

- [`azu serve`](serve.md) - Start development server with hot reloading
- [`azu dev`](dev.md) - Alias for serve command
- [`azu test`](test.md) - Run application tests with watch mode

### Background Jobs

- [`azu jobs:worker`](jobs.md#azu-jobsworker) - Start job workers
- [`azu jobs:status`](jobs.md#azu-jobsstatus) - Show job queue status
- [`azu jobs:clear`](jobs.md#azu-jobsclear) - Clear job queues
- [`azu jobs:retry`](jobs.md#azu-jobsretry) - Retry failed jobs
- [`azu jobs:ui`](jobs.md#azu-jobsui) - Start JoobQ web interface

### Session Management

- [`azu session:setup`](session.md#azu-sessionsetup) - Setup session management
- [`azu session:clear`](session.md#azu-sessionclear) - Clear all sessions

### Database Management

- [`azu db:create`](database.md#azu-dbcreate) - Create the database
- [`azu db:migrate`](database.md#azu-dbmigrate) - Run database migrations
- [`azu db:rollback`](database.md#azu-dbrollback) - Rollback migrations
- [`azu db:seed`](database.md#azu-dbseed) - Seed database with sample data
- [`azu db:reset`](database.md#azu-dbreset) - Reset database (drop, create, migrate)
- [`azu db:status`](database.md#azu-dbstatus) - Show migration status
- [`azu db:setup`](database.md#azu-dbsetup) - Setup database (create and migrate)
- [`azu db:drop`](database.md#azu-dbdrop) - Drop the database

### OpenAPI Integration

- [`azu openapi:generate`](openapi.md#azu-openapigenerate) - Generate code from OpenAPI specification
- [`azu openapi:export`](openapi.md#azu-openapiexport) - Export OpenAPI specification from code

### Plugin Management

- [`azu plugin`](plugin.md) - Manage CLI plugins

### Information & Help

- [`azu help`](help.md) - Show help information
- [`azu version`](version.md) - Display version information

## Command Structure

All Azu CLI commands follow a consistent structure:

```bash
azu <command> [subcommand] [arguments] [options]
```

### Examples

```bash
# Project Creation
azu new my_app --database postgres

# Code Generation
azu generate scaffold Post title:string content:text

# Database Operations
azu db:migrate

# Development Server
azu serve --port 4000
```

## Global Options

These options are available for most commands:

| Option          | Short | Description                           |
| --------------- | ----- | ------------------------------------- |
| `--help`        | `-h`  | Show help for the command             |
| `--version`     | `-v`  | Show version information              |
| `--debug`       | `-d`  | Enable debug mode with verbose output |
| `--verbose`     |       | Enable verbose output                 |
| `--quiet`       | `-q`  | Suppress non-error output             |
| `--config FILE` |       | Use custom configuration file         |

### Examples

```bash
# Get help for any command
azu generate --help
azu db migrate --help

# Enable debug mode
azu serve --debug

# Quiet operation
azu db:migrate --quiet
```

## Command Categories

### Project Management Commands

Commands for creating and initializing Azu projects.

#### `azu new <name>`

Creates a new Azu project with the specified name.

**Quick Examples:**

```bash
# Basic web application
azu new my_blog

# API-only application
azu new my_api --type api

# With specific database
azu new my_app --database mysql
```

#### `azu init`

Initializes Azu in an existing Crystal project.

**Quick Examples:**

```bash
# Initialize in current directory
azu init

# Initialize with specific database
azu init --database postgres
```

### Code Generation Commands

Commands for generating application components.

#### `azu generate <type> <name>`

Generates various types of components for your application.

**Available Generators:**

- `endpoint` - HTTP endpoints (controllers)
- `model` - Database models
- `service` - Business logic services
- `middleware` - HTTP middleware
- `contract` - Request/response contracts
- `page` - Page components (views)
- `component` - Live interactive components
- `validator` - Custom validators
- `migration` - Database migrations
- `scaffold` - Complete CRUD resource

**Quick Examples:**

```bash
# Generate a model
azu generate model User name:string email:string

# Generate an endpoint
azu generate endpoint posts

# Generate complete scaffold
azu generate scaffold Post title:string content:text published:boolean

# Generate a live component
azu generate component Counter count:integer --websocket
```

### Development Commands

Commands for development and testing.

#### `azu serve`

Starts the development server with hot reloading.

**Quick Examples:**

```bash
# Start on default port (4000)
azu serve

# Start on custom port
azu serve --port 4000

# Start with specific environment
azu serve --env production
```

#### `azu dev`

Alias for the `serve` command.

**Quick Examples:**

```bash
# Same as azu serve
azu dev

# With options
azu dev --port 8080
```

#### `azu test`

Runs application tests with watch mode support.

**Quick Examples:**

```bash
# Run all tests
azu test

# Run with watch mode
azu test --watch

# Run specific tests
azu test spec/models/user_spec.cr
```

### Background Jobs Commands

Commands for managing JoobQ background jobs.

#### `azu jobs:worker`

Starts background job workers.

**Quick Examples:**

```bash
# Start single worker
azu jobs:worker

# Start multiple workers
azu jobs:worker --workers 4

# Process specific queues
azu jobs:worker --queues critical,default
```

#### `azu jobs:status`

Shows job queue statistics.

**Quick Examples:**

```bash
# Show status
azu jobs:status
```

#### `azu jobs:clear`

Clears job queues.

**Quick Examples:**

```bash
# Clear default queue
azu jobs:clear

# Clear all queues
azu jobs:clear --all --force
```

#### `azu jobs:retry`

Retries failed jobs.

**Quick Examples:**

```bash
# Retry failed jobs
azu jobs:retry

# Retry all failed
azu jobs:retry --all
```

#### `azu jobs:ui`

Launches JoobQ web interface.

**Quick Examples:**

```bash
# Start UI
azu jobs:ui

# Custom port
azu jobs:ui --port 5000
```

### Session Management Commands

Commands for session configuration and management.

#### `azu session:setup`

Configures session management.

**Quick Examples:**

```bash
# Setup with Redis
azu session:setup --backend redis

# Setup with database
azu session:setup --backend database
```

#### `azu session:clear`

Clears all application sessions.

**Quick Examples:**

```bash
# Clear sessions
azu session:clear

# Clear without confirmation
azu session:clear --force
```

### Database Commands

Commands for database management.

#### `azu db:create`

Creates the database for the current environment.

#### `azu db:migrate`

Runs pending database migrations.

#### `azu db:rollback`

Rolls back the last migration or a specific number of migrations.

#### `azu db:seed`

Seeds the database with sample data.

#### `azu db:reset`

Drops, creates, and migrates the database.

#### `azu db:setup`

Sets up the database by creating it and running migrations.

#### `azu db:drop`

Drops the database for the current environment.

**Quick Examples:**

```bash
# Create database
azu db:create

# Run migrations
azu db:migrate

# Rollback last migration
azu db:rollback

# Rollback 3 migrations
azu db:rollback --steps 3

# Seed database
azu db:seed

# Reset database
azu db:reset
```

### OpenAPI Commands

Commands for OpenAPI specification integration.

#### `azu openapi:generate`

Generates Crystal code from an OpenAPI specification.

**Quick Examples:**

```bash
# Generate all code from spec
azu openapi:generate api-spec.yaml

# Generate only models
azu openapi:generate api-spec.yaml --models-only

# Generate only endpoints
azu openapi:generate api-spec.yaml --endpoints-only
```

#### `azu openapi:export`

Exports an OpenAPI specification from existing code.

**Quick Examples:**

```bash
# Export to default file
azu openapi:export

# Export to specific file
azu openapi:export --output api.yaml

# Export as JSON
azu openapi:export --output api.json --format json
```

### Plugin Management Commands

Commands for managing CLI plugins.

#### `azu plugin`

Manages Azu CLI plugins.

**Quick Examples:**

```bash
# List plugins
azu plugin list

# Install plugin
azu plugin install my-plugin

# Show plugin info
azu plugin info generator
```

### Information Commands

Commands for getting help and information.

#### `azu help`

Shows general help or help for a specific command.

**Quick Examples:**

```bash
# General help
azu help

# Help for specific command
azu help generate
azu help serve
```

#### `azu version`

Displays version information.

**Quick Examples:**

```bash
# Show version
azu version
```

## Command-Specific Options

### Project Creation Options

| Option              | Description                             | Default  |
| ------------------- | --------------------------------------- | -------- |
| `--database <db>`   | Database type (postgres, mysql, sqlite) | postgres |
| `--type <type>`     | Project type (web, api, cli)            | web      |
| `--template <name>` | Use specific template                   | default  |
| `--skip-git`        | Skip Git repository initialization      | false    |
| `--skip-deps`       | Skip dependency installation            | false    |

### Generation Options

| Option          | Description               | Default |
| --------------- | ------------------------- | ------- |
| `--force`       | Overwrite existing files  | false   |
| `--skip-tests`  | Skip test file generation | false   |
| `--skip-routes` | Skip route registration   | false   |

### Server Options

| Option                | Description          | Default     |
| --------------------- | -------------------- | ----------- |
| `--port <port>`       | Server port          | 4000        |
| `--host <host>`       | Server host          | localhost   |
| `--env <environment>` | Environment name     | development |
| `--ssl`               | Enable SSL           | false       |
| `--ssl-cert <path>`   | SSL certificate path |             |
| `--ssl-key <path>`    | SSL private key path |             |

### Database Options

| Option                | Description                      | Default     |
| --------------------- | -------------------------------- | ----------- |
| `--env <environment>` | Target environment               | development |
| `--steps <number>`    | Number of migrations to rollback | 1           |

## Environment Variables

Azu CLI respects these environment variables:

| Variable           | Description             | Default     |
| ------------------ | ----------------------- | ----------- |
| `AZU_ENV`          | Current environment     | development |
| `AZU_DATABASE_URL` | Database connection URL |             |
| `AZU_PORT`         | Default server port     | 4000        |
| `AZU_HOST`         | Default server host     | localhost   |
| `AZU_CONFIG`       | Configuration file path | azu.yml     |
| `AZU_DEBUG`        | Enable debug mode       | false       |

## Configuration File

You can create a configuration file (`azu.yml`) to set default options:

```yaml
# azu.yml
project:
  default_database: postgres
  default_type: web

development:
  port: 4000
  host: localhost
  debug: true

production:
  port: 8080
  host: 0.0.0.0
  debug: false

database:
  development:
    url: postgres://localhost/my_app_development
  test:
    url: postgres://localhost/my_app_test
  production:
    url: ${DATABASE_URL}
```

## Exit Codes

Azu CLI uses standard exit codes:

| Code | Meaning                   |
| ---- | ------------------------- |
| 0    | Success                   |
| 1    | General error             |
| 2    | Invalid usage/arguments   |
| 3    | File/directory not found  |
| 4    | Permission denied         |
| 5    | Database connection error |

## Shell Completion

Enable shell completion for faster command usage:

### Bash

```bash
# Add to ~/.bashrc
eval "$(azu completion bash)"
```

### Zsh

```bash
# Add to ~/.zshrc
eval "$(azu completion zsh)"
```

### Fish

```bash
# Add to ~/.config/fish/config.fish
azu completion fish | source
```

## Common Workflows

### Creating a New Application

```bash
# 1. Create new project
azu new my_blog --database postgres

# 2. Navigate to project
cd my_blog

# 3. Create database
azu db:create

# 4. Generate a resource
azu generate scaffold Post title:string content:text

# 5. Run migration
azu db:migrate

# 6. Start development server
azu serve
```

### Daily Development

```bash
# Generate new features
azu generate model User name:string email:string
azu generate endpoint users
azu generate service UserRegistration

# Run migrations
azu db:migrate

# Start development server
azu serve --port 4000

# Reset database when needed
azu db:reset
```

### Database Management

```bash
# Create and setup database
azu db:create
azu db:migrate
azu db:seed

# When things go wrong
azu db:rollback
azu db:reset
```

## Getting Help

For detailed help on any command:

```bash
# General help
azu help

# Command-specific help
azu <command> --help
azu generate --help
azu db:migrate --help
```

For more detailed information about each command, see the individual command documentation pages.

---

**Next Steps:**

- [Generators Guide](../generators/README.md) - Learn about code generation
- [Development Workflows](../examples/README.md) - Common development patterns
- [Configuration](../configuration/README.md) - Advanced configuration options
