# azu init

The `azu init` command initializes an existing directory as an Azu project. This is useful when you want to add Azu to an existing project or when you've cloned a project that doesn't have Azu configuration.

## Overview

```bash
azu init [options]
```

## Basic Usage

### Initialize Current Directory

```bash
# Initialize the current directory as an Azu project
azu init

# Initialize with specific database
azu init --database postgres

# Initialize with specific project type
azu init --type api
```

### Initialize Existing Project

```bash
# Navigate to existing project
cd my_existing_project

# Initialize as Azu project
azu init

# The command will:
# - Create Azu configuration files
# - Set up directory structure
# - Generate initial files
# - Install dependencies
```

## Command Options

| Option              | Description                             | Default  |
| ------------------- | --------------------------------------- | -------- |
| `--database <db>`   | Database type (postgres, mysql, sqlite) | postgres |
| `--type <type>`     | Project type (web, api, cli)            | web      |
| `--template <name>` | Use specific template                   | default  |
| `--skip-git`        | Skip Git repository initialization      | false    |
| `--skip-deps`       | Skip dependency installation            | false    |
| `--force`           | Overwrite existing files                | false    |

## Use Cases

### 1. Adding Azu to Existing Crystal Project

```bash
# You have an existing Crystal project
cd my_crystal_app

# Initialize with Azu
azu init --database postgres

# This will:
# - Add Azu dependencies to shard.yml
# - Create Azu configuration files
# - Set up directory structure
# - Keep existing code intact
```

### 2. Converting Rails/Sinatra Project

```bash
# You have a Ruby project you want to convert
cd my_ruby_app

# Initialize as Azu project
azu init --type api --database postgres

# This creates the foundation for migration
# You can then gradually port your code
```

### 3. Setting Up Cloned Project

```bash
# Clone a project that doesn't have Azu setup
git clone https://github.com/user/project.git
cd project

# Initialize Azu
azu init

# Install dependencies
shards install

# Start development
azu serve
```

## Generated Files

### Configuration Files

**`azu.yml`** - Azu configuration:

```yaml
name: my_app
version: 0.1.0
database: postgres
type: web

environments:
  development:
    database_url: postgres://localhost/my_app_development
    port: 3000
    debug: true

  test:
    database_url: postgres://localhost/my_app_test
    port: 3001
    debug: false

  production:
    database_url: <%= ENV["DATABASE_URL"] %>
    port: <%= ENV["PORT"] || 8080 %>
    debug: false
```

**`shard.yml`** - Updated with Azu dependencies:

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

### Directory Structure

```
my_app/
├── azu.yml                    # Azu configuration
├── shard.yml                  # Crystal dependencies
├── src/
│   ├── my_app.cr              # Main application
│   ├── server.cr              # HTTP server
│   ├── endpoints/             # HTTP endpoints
│   ├── models/                # Database models
│   ├── services/              # Business logic
│   ├── pages/                 # View components
│   ├── contracts/             # Request validation
│   ├── middleware/            # HTTP middleware
│   └── initializers/          # App configuration
├── public/
│   ├── assets/                # Static files
│   └── templates/             # HTML templates
├── spec/                      # Test files
├── db/                        # Database files
│   ├── migrations/            # Database migrations
│   └── seeds/                 # Seed data
└── config/                    # Configuration files
    └── environments/          # Environment configs
```

### Core Application Files

**`src/my_app.cr`** - Main application:

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

**`src/server.cr`** - HTTP server:

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

**`src/initializers/database.cr`** - Database setup:

```crystal
require "cql"

CQL.setup do |config|
  config.database_url = ENV.fetch("DATABASE_URL", "postgres://localhost/my_app_development")
  config.log_level = :debug
end
```

## Examples

### Initialize Web Application

```bash
# Initialize as web application
azu init --type web --database postgres

# Output:
# 🚀 Initializing Azu project...
# 📁 Creating directory structure...
# ⚙️  Generating configuration files...
# 📦 Installing dependencies...
# ✅ Project initialized successfully!
#
# Next steps:
# 1. cd my_app
# 2. azu db:create
# 3. azu serve
```

### Initialize API Application

```bash
# Initialize as API application
azu init --type api --database mysql

# This creates:
# - API-focused structure
# - JSON response handling
# - No HTML templates
# - API documentation setup
```

### Initialize CLI Application

```bash
# Initialize as CLI application
azu init --type cli

# This creates:
# - CLI command structure
# - No web server
# - Command-line interface
# - Utility functions
```

## Post-Initialization Steps

### 1. Install Dependencies

```bash
# Install Crystal dependencies
shards install

# Verify installation
crystal --version
```

### 2. Setup Database

```bash
# Create database
azu db:create

# Run migrations (if any)
azu db:migrate

# Seed data (if any)
azu db:seed
```

### 3. Start Development

```bash
# Start development server
azu serve

# Visit your application
# http://localhost:3000
```

### 4. Generate Your First Resource

```bash
# Generate a model
azu generate model user name:string email:string

# Generate endpoints
azu generate endpoint users

# Generate pages
azu generate page users/index
```

## Migration from Other Frameworks

### From Rails

```bash
# Initialize Azu project
azu init --type web --database postgres

# Migrate your models
# Convert ActiveRecord models to CQL models

# Migrate your controllers
# Convert Rails controllers to Azu endpoints

# Migrate your views
# Convert ERB templates to Azu pages
```

### From Sinatra

```bash
# Initialize Azu project
azu init --type api --database postgres

# Migrate your routes
# Convert Sinatra routes to Azu endpoints

# Migrate your models
# Convert your data models to CQL models
```

### From Express.js

```bash
# Initialize Azu project
azu init --type api --database postgres

# Migrate your routes
# Convert Express routes to Azu endpoints

# Migrate your middleware
# Convert Express middleware to Azu middleware
```

## Troubleshooting

### Permission Issues

```bash
# Check directory permissions
ls -la

# Fix permissions if needed
chmod 755 .

# Initialize in different location
azu init --path ~/projects/my_app
```

### Existing Files Conflict

```bash
# Check for existing files
ls -la

# Use force to overwrite
azu init --force

# Or backup and initialize
cp -r . ../backup
azu init
```

### Database Connection Issues

```bash
# Check database server
sudo systemctl status postgresql

# Create database user
sudo -u postgres createuser -s $USER

# Test connection
psql -h localhost -U $USER -d postgres
```

### Dependency Issues

```bash
# Check Crystal installation
crystal --version

# Update Crystal
# (Follow Crystal installation guide)

# Clear shard cache
rm -rf lib/
shards install
```

## Best Practices

### 1. Project Structure

```bash
# Use descriptive project names
azu init my_blog_app
azu init user_management_api
azu init data_processor_cli

# Avoid generic names
azu init app
azu init project
azu init test
```

### 2. Database Selection

```bash
# Development/Prototyping
azu init --database sqlite

# Web Applications
azu init --database postgres

# API Services
azu init --database postgres

# CLI Tools
azu init --database sqlite
```

### 3. Project Type

```bash
# Full-stack applications
azu init --type web

# API services
azu init --type api

# Command-line tools
azu init --type cli
```

### 4. Version Control

```bash
# Initialize Git repository
git init

# Add .gitignore
echo "lib/" >> .gitignore
echo "bin/" >> .gitignore
echo "*.log" >> .gitignore

# Initial commit
git add .
git commit -m "Initialize Azu project"
```

## Integration with Existing Code

### Preserving Existing Files

```bash
# Azu init preserves existing files
# Only creates missing structure

# Existing files are kept:
# - src/your_existing_code.cr
# - spec/your_existing_tests.cr
# - README.md
# - .gitignore
```

### Gradual Migration

```bash
# 1. Initialize Azu
azu init

# 2. Move existing models
mv src/models/* src/models/

# 3. Convert endpoints gradually
# Start with one endpoint at a time

# 4. Update tests
# Convert existing tests to Azu format
```

---

The `azu init` command is perfect for adding Azu to existing projects or setting up projects that don't have Azu configuration.

**Next Steps:**

- [Project Structure](../getting-started/project-structure.md) - Understand the generated structure
- [Database Commands](database.md) - Setup your database
- [Generate Command](generate.md) - Create your first components
