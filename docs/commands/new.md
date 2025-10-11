# azu new

The `azu new` command creates a new Azu project from scratch. This is the primary way to start a new application with Azu CLI.

## Overview

```bash
azu new <project_name> [options]
```

## Basic Usage

### Create a Simple Web Application

```bash
# Create a new web application
azu new my_blog

# Navigate to the project
cd my_blog

# Start development
azu serve
```

### Create Different Project Types

```bash
# Web application (default)
azu new my_web_app --type web

# API-only application
azu new my_api --type api
# or use the shorthand:
azu new my_api --api

# CLI application
azu new my_cli_tool --type cli
```

### Specify Database

```bash
# PostgreSQL (default)
azu new my_app --database postgres

# MySQL
azu new my_app --database mysql

# SQLite
azu new my_app --database sqlite
```

## Command Options

| Option              | Description                             | Default  |
| ------------------- | --------------------------------------- | -------- |
| `--type <type>`     | Project type (web, api, cli)            | web      |
| `--database <db>`   | Database type (postgres, mysql, sqlite) | postgres |
| `--template <name>` | Use specific template                   | default  |
| `--skip-git`        | Skip Git repository initialization      | false    |
| `--skip-deps`       | Skip dependency installation            | false    |
| `--force`           | Overwrite existing directory            | false    |

## Project Types

### Web Application (`--type web`)

Full-stack web applications with HTML templates, CSS, and JavaScript.

**Features:**

- HTML page rendering with Jinja2 templates
- Static asset management (CSS, JS, images)
- Real-time components with WebSocket support
- Complete MVC architecture

**Generated Structure:**

```
my_web_app/
├── src/
│   ├── my_web_app.cr          # Main application
│   ├── server.cr              # HTTP server
│   ├── endpoints/             # Controllers
│   ├── models/                # Database models
│   ├── pages/                 # View components
│   ├── contracts/             # Request validation
│   └── initializers/          # App configuration
├── public/
│   ├── assets/                # Static files
│   └── templates/             # HTML templates
├── spec/                      # Test files
└── db/                        # Database files
```

### API Application (`--type api`)

API-only applications for building REST APIs, microservices, or mobile backends.

**Features:**

- JSON API endpoints
- Request/response contracts
- No HTML templates or static assets
- Optimized for API development

**Generated Structure:**

```
my_api/
├── src/
│   ├── my_api.cr              # Main application
│   ├── server.cr              # HTTP server
│   ├── endpoints/             # API controllers
│   ├── models/                # Database models
│   ├── contracts/             # API contracts
│   ├── services/              # Business logic
│   └── initializers/          # App configuration
├── spec/                      # Test files
└── db/                        # Database files
```

### CLI Application (`--type cli`)

Command-line applications and tools.

**Features:**

- Command-line interface
- No web server or database (unless added)
- Focused on CLI development

**Generated Structure:**

```
my_cli_tool/
├── src/
│   ├── my_cli_tool.cr         # Main application
│   ├── commands/              # CLI commands
│   ├── services/              # Business logic
│   └── utils/                 # Utilities
├── spec/                      # Test files
└── bin/                       # Executable
```

## Database Options

### PostgreSQL (`--database postgres`)

**Recommended for production applications.**

```bash
azu new my_app --database postgres
```

**Features:**

- Full ACID compliance
- Advanced features (JSON, arrays, etc.)
- Excellent performance
- Rich ecosystem

**Requirements:**

- PostgreSQL server installed
- Database user with create privileges

### MySQL (`--database mysql`)

**Good for web applications and smaller projects.**

```bash
azu new my_app --database mysql
```

**Features:**

- Widely supported
- Good performance
- Easy to find hosting

**Requirements:**

- MySQL server installed
- Database user with create privileges

### SQLite (`--database sqlite`)

**Perfect for development, prototypes, and simple applications.**

```bash
azu new my_app --database sqlite
```

**Features:**

- No server required
- File-based database
- Zero configuration
- Great for development

**Use Cases:**

- Development and testing
- Simple applications
- Prototypes and demos
- Embedded applications

## Advanced Options

### Custom Templates

Use a custom project template:

```bash
# Create custom template
mkdir -p ~/.azu/templates/projects/custom/
# Add template files...

# Use custom template
azu new my_app --template custom
```

### Skip Git Initialization

```bash
# Don't initialize Git repository
azu new my_app --skip-git
```

### Skip Dependencies

```bash
# Don't install shards automatically
azu new my_app --skip-deps
```

### Force Overwrite

```bash
# Overwrite existing directory
azu new my_app --force
```

## Generated Files

### Core Application Files

**`src/<project_name>.cr`** - Main application module:

```crystal
require "azu"
require "./server"

module MyApp
  VERSION = "0.1.0"

  # Application configuration
  Azu.configure do |config|
    config.debug = true
    config.log_level = :debug
    config.host = "localhost"
    config.port = 3000
  end
end
```

**`src/server.cr`** - HTTP server configuration:

```crystal
require "azu"

# Load all application components
require "./endpoints/**"
require "./models/**"
require "./services/**"
require "./middleware/**"
require "./initializers/**"

# Start the server
Azu::Server.start
```

### Configuration Files

**`shard.yml`** - Crystal dependencies:

```yaml
name: my_app
version: 0.1.0

dependencies:
  azu:
    github: azutoolkit/azu
    version: ~> 1.0.0
  cql:
    github: azutoolkit/cql
    version: ~> 0.8.0

development_dependencies:
  ameba:
    github: crystal-ameba/ameba
    version: ~> 1.4.0

targets:
  my_app:
    main: src/my_app.cr
```

**`README.md`** - Project documentation:

````markdown
# My App

A Crystal web application built with Azu.

## Installation

1. Install dependencies:
   ```bash
   shards install
   ```
````

2. Setup database:

   ```bash
   azu db:create
   azu db:migrate
   ```

3. Start development server:
   ```bash
   azu serve
   ```

## Development

- `azu serve` - Start development server
- `azu generate scaffold Post title:string` - Generate resources
- `crystal spec` - Run tests

````

### Database Configuration

**`src/initializers/database.cr`** - Database setup:
```crystal
require "cql"

CQL.setup do |config|
  config.database_url = ENV.fetch("DATABASE_URL", "postgres://localhost/my_app_development")
  config.log_level = :debug
end
````

## Examples

### Complete Blog Application

```bash
# Create blog with PostgreSQL
azu new my_blog --database postgres --type web

cd my_blog

# Setup database
azu db:create
azu db:migrate

# Generate blog resources
azu generate scaffold Post title:string content:text published:boolean
azu generate scaffold User name:string email:string

# Start development
azu serve
```

### API Service

```bash
# Create API service
azu new user_api --type api --database postgres

cd user_api

# Setup
azu db:create
azu db:migrate

# Generate API endpoints
azu generate model User name:string email:string
azu generate endpoint api/v1/users --api

# Start API server
azu serve --port 8080
```

### CLI Tool

```bash
# Create CLI tool
azu new file_processor --type cli

cd file_processor

# Generate commands
azu generate command process
azu generate command convert

# Build and run
crystal build src/file_processor.cr -o bin/file_processor
./bin/file_processor process --help
```

## Post-Creation Steps

After creating a new project:

1. **Navigate to project directory:**

   ```bash
   cd my_app
   ```

2. **Install dependencies:**

   ```bash
   shards install
   ```

3. **Setup database (if applicable):**

   ```bash
   azu db:create
   azu db:migrate
   ```

4. **Start development:**

   ```bash
   azu serve
   ```

5. **Generate your first resource:**
   ```bash
   azu generate scaffold Post title:string content:text
   ```

## Troubleshooting

### Permission Denied

```bash
# Check directory permissions
ls -la

# Create in different location
azu new my_app --path ~/projects/
```

### Database Connection Error

```bash
# Ensure database server is running
sudo systemctl status postgresql  # Linux
brew services list | grep postgres  # macOS

# Check database user
createuser -s $USER  # PostgreSQL
```

### Template Not Found

```bash
# Use default template
azu new my_app --template default

# Or create custom template
mkdir -p ~/.azu/templates/projects/my_template/
```

## Best Practices

### 1. Choose the Right Project Type

- **Web**: Full-stack applications with UI
- **API**: Backend services and microservices
- **CLI**: Command-line tools and utilities

### 2. Select Appropriate Database

- **PostgreSQL**: Production applications, complex data
- **MySQL**: Web applications, shared hosting
- **SQLite**: Development, prototypes, simple apps

### 3. Use Descriptive Names

```bash
# Good names
azu new blog_platform
azu new user_management_api
azu new data_processor_cli

# Avoid generic names
azu new app
azu new project
azu new test
```

### 4. Plan Your Structure

Before creating the project, consider:

- **Project type** (web, API, CLI)
- **Database requirements**
- **Deployment environment**
- **Team size and workflow**

---

The `azu new` command is your starting point for all Azu applications. Choose the right options for your project type and requirements to get the best foundation for your development.

**Next Steps:**

- [Project Structure](../getting-started/project-structure.md) - Understand the generated structure
- [Quick Start](../getting-started/quick-start.md) - Build your first feature
- [Database Commands](database.md) - Manage your database
