# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Azu CLI** is a feature-complete, production-ready command-line interface for the Azu Toolkit - a Rails-like framework for Crystal that provides database management, code generation, hot reloading, and comprehensive development tools.

- **Language**: Crystal 1.16.3
- **CLI Framework**: Topia (https://github.com/azutoolkit/topia)
- **Target Frameworks**:
  - Azu Web Framework (https://github.com/azutoolkit/azu)
  - CQL ORM (https://github.com/azutoolkit/cql)
  - JoobQ (https://github.com/azutoolkit/joobq)

## Common Commands

### Development

```bash
# Install dependencies
shards install

# Build the CLI
shards build --production --ignore-crystal-version

# Run the CLI directly during development
crystal run src/azu_cli.cr -- [command] [args]

# Install locally for testing
make install
```

### Testing

```bash
# Run all tests
crystal spec

# Run specific test file
crystal spec spec/azu_cli/integration/joobq_generator_spec.cr

# Run tests in watch mode (using azu test command in a generated project)
azu test --watch
```

### Building

```bash
# Build via Makefile (recommended)
make build

# Build manually
crystal build -o bin/azu src/azu_cli.cr -p --no-debug
```

### Installation

```bash
# Install globally (may require sudo)
make install

# Install man page
make install-man

# Uninstall
make clean
```

## Architecture Overview

### Core Components

1. **CLI Framework (src/azu_cli/cli.cr)**

   - Uses Topia for command parsing and routing
   - Middleware system for logging, error handling, and configuration
   - Plugin architecture for extensibility
   - Command registration happens in `CLI#setup_commands`

2. **Commands (src/azu_cli/commands/)**

   - All commands inherit from `Commands::Base`
   - Base class provides argument parsing, error handling, and validation
   - Command execution returns `Commands::Result` with success/error state
   - Database commands in `commands/db/`
   - Job queue commands in `commands/jobs/`

3. **Generators (src/azu_cli/generators/)**

   - Use Teeplate for file tree generation
   - Each generator inherits from `Teeplate::FileTree`
   - Template files use ECR (Embedded Crystal) in `templates/` directory
   - Generators support:
     - Models (CQL ORM)
     - Endpoints (HTTP handlers)
     - Services (business logic)
     - Scaffolds (complete CRUD)
     - Authentication (JWT/Session)
     - Jobs (JoobQ background jobs)
     - Channels (WebSocket)
     - Migrations

4. **Templates (src/azu_cli/templates/)**

   - `project/` - New project scaffolding
   - `scaffold/` - CRUD component generation
   - `auth/` - Authentication system
   - `joobq/` - Background job infrastructure
   - All use `.ecr` extension for template files
   - Variables interpolated using `<%= @variable %>` syntax

5. **Middleware (src/azu_cli/middleware/)**

   - Logging middleware for command execution
   - Error handler for consistent error reporting
   - Configuration middleware for environment setup
   - Executed before/after each command via `CLI#execute_command`

6. **Plugins (src/azu_cli/plugins/)**
   - Base plugin system using `Plugins::Base`
   - Built-in plugins: GeneratorPlugin, DatabasePlugin, DevelopmentPlugin
   - Hooks: `on_load`, `before_command`, `after_command`, `on_error`

### Key Design Patterns

**Command Pattern**: Each CLI command is a class with `execute` method returning `Result`

**Template Pattern**: Generators use Teeplate with ECR templates for code generation

**Middleware Pipeline**: Commands pass through middleware chain for logging, config, error handling

**Plugin System**: Extensibility through plugin hooks at CLI lifecycle events

**Type Safety**: Crystal's type system enforced throughout - explicit type annotations for public APIs

### Database Integration (CQL ORM)

- Migration system uses CQL's `Migrator` class
- Automatic schema synchronization to `src/db/schema.cr`
- Migration files in `db/migrations/` with timestamp prefixes
- Supports PostgreSQL, MySQL, SQLite
- Models use `CQL::Record` with macro-powered DSL

### Code Generation Workflow

1. User runs `azu generate [type] [name] [attributes]`
2. `Commands::Generate` parses arguments and options
3. Appropriate generator instantiated (e.g., `Generate::Model`)
4. Generator initializes with name, attributes, options
5. Teeplate renders ECR templates with instance variables
6. Files written to appropriate directories in project structure

### Error Handling Strategy

- Custom error categories defined in `Config::ErrorCategory`
- Error severity levels: DEBUG, INFO, WARN, ERROR, FATAL
- `Commands::Base#handle_error` provides consistent error formatting
- Debug mode shows full stack traces
- Exit codes: 0 (success), 1 (failure), 2 (invalid usage)

## Project-Specific Conventions

### Naming Conventions

- **Commands**: PascalCase classes (e.g., `Commands::DB::Migrate`)
- **Generators**: PascalCase classes (e.g., `Generate::Model`)
- **Files**: snake_case (e.g., `user_model.cr`)
- **Templates**: snake_case with .ecr extension
- **Template variables**: snake_case instance variables (`@snake_case_name`)

### Directory Structure of Generated Projects

```
project_name/
├── src/
│   ├── models/          # CQL models
│   ├── endpoints/       # HTTP request handlers
│   ├── requests/        # Request validation
│   ├── pages/           # Response pages
│   ├── services/        # Business logic
│   ├── jobs/            # Background jobs
│   ├── channels/        # WebSocket channels
│   ├── middleware/      # HTTP middleware
│   ├── initializers/    # App initialization
│   └── db/
│       ├── migrations/  # Database migrations
│       ├── schema.cr    # Auto-generated schema
│       └── seed.cr      # Seed data
├── public/
│   └── templates/       # Jinja templates
├── spec/                # Tests
└── config/              # Configuration files
```

### Template Variables and Helpers

Common template variables:

- `@name` - Original name (e.g., "User")
- `@snake_case_name` - Underscored (e.g., "user")
- `@resource_plural` - Pluralized (e.g., "users")
- `@table_name` - Database table (e.g., "users")
- `@attributes` - Hash of attribute names to types
- `@timestamps` - Boolean for created_at/updated_at
- `@module_name` - Schema/module context

### Generator Attribute Syntax

When parsing attribute arguments like `name:string email:string:unique age:int32`:

- Format: `name:type[:modifier]`
- Types: `string`, `int32`, `int64`, `float64`, `bool`, `time`, `uuid`
- Modifiers: `unique`, `index`, `required`
- References: `user_id:int64:ref:users` creates foreign key

### CQL ORM Patterns

Models use `CQL::Record` with schema DSL:

```crystal
module AppSchema
  @[CQL::Model(table_name: users)]
  struct User < CQL::Record(Int64)
    property name : String
    property email : String
    db_context AppDatabase
  end
end
```

Migrations use CQL Schema DSL:

```crystal
class CreateUsers < CQL::Migration(timestamp)
  def up
    schema.table :users do
      primary :id, Int64
      column :name, String
      column :email, String, unique: true
      timestamps
    end
    schema.users.create!
  end
end
```

### JoobQ Integration

- Background job infrastructure setup via `azu generate joobq`
- Jobs inherit from JoobQ job classes
- Configuration in `config/joobq.{environment}.yml`
- Worker process started with `azu jobs:worker`
- Queue monitoring via `azu jobs:status` or `azu jobs:ui`

## Important Implementation Details

### Command Argument Parsing

`Commands::Base#parse_args` handles:

- Long flags: `--option value` or `--option=value`
- Short flags: `-o value`
- Boolean flags: `--flag` (no value)
- Positional arguments stored in `@args`
- All arguments (including flags) in `@all_args`

### Template Rendering with Teeplate

Generators extend `Teeplate::FileTree`:

1. Set `directory` to template source path
2. Define instance variables matching template placeholders
3. Call `super` or let Teeplate auto-render on initialization
4. Files rendered to current directory or specified output

### Migration System

- Timestamps use Unix epoch format (e.g., `20240115103045_i64`)
- Migration files: `{timestamp}_{action}_{table_name}.cr`
- Auto-updates `src/db/schema.cr` after running migrations
- Rollback uses `--steps N` to roll back N migrations
- Status shows pending vs. executed migrations

### OpenAPI Integration

- Can generate OpenAPI specs from code: `azu openapi:export`
- Can generate code from OpenAPI specs: `azu openapi:generate`
- Analyzers extract models, endpoints, requests, responses
- Supports JSON and YAML formats

## Testing Approach

- Uses Crystal's built-in spec framework with spec2 extension
- Integration tests in `spec/azu_cli/integration/`
- Test helpers in `spec/support/`
- Fixtures in `spec/fixtures/`
- Mock file operations when testing generators
- Test both success and error paths

## Working with This Codebase

### Adding a New Command

1. Create file in `src/azu_cli/commands/` (or subdirectory)
2. Inherit from `Commands::Base`
3. Implement `execute : Result` method
4. Register in `CLI#setup_commands`
5. Add help text and examples via `show_help`/`show_examples`

### Adding a New Generator

1. Create file in `src/azu_cli/generators/`
2. Inherit from `Teeplate::FileTree`
3. Set `directory` pointing to templates
4. Define instance variables for template interpolation
5. Create ECR templates in `src/azu_cli/templates/`
6. Register in `Commands::Generate#execute`

### Modifying Templates

- Templates use ECR: `<%= expression %>` for output, `<% code %>` for logic
- Access generator instance variables: `<%= @name %>`
- Use helpers from generator class: `<%= snake_case_name %>`
- Test by running generator and verifying output

### Debugging

- Enable debug mode: Set `Config.instance.debug_mode = true`
- Use `Logger.debug` for debug messages (only shown in debug mode)
- Use `pp` macro for inspecting values during development
- Stack traces shown in debug mode on errors
