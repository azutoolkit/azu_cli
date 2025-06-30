# Database Commands

Azu CLI provides a comprehensive set of database commands for managing your application's database. These commands work with CQL ORM and support PostgreSQL, MySQL, and SQLite.

## Overview

All database commands follow the pattern:

```bash
azu db:<command> [options]
```

## Available Commands

| Command           | Description                        |
| ----------------- | ---------------------------------- |
| `azu db:create`   | Create the database                |
| `azu db:drop`     | Drop the database                  |
| `azu db:migrate`  | Run pending migrations             |
| `azu db:rollback` | Rollback migrations                |
| `azu db:reset`    | Drop, create, and migrate database |
| `azu db:seed`     | Run seed data                      |
| `azu db:setup`    | Create and migrate database        |
| `azu db:version`  | Show current migration version     |

## Database Configuration

### Environment Variables

```bash
# Database URL (recommended)
export DATABASE_URL="postgres://username:password@localhost/my_app_development"

# Or individual components
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_NAME="my_app_development"
export DB_USER="username"
export DB_PASSWORD="password"
```

### Configuration File

```yaml
# config/database.yml
development:
  adapter: postgres
  database: my_app_development
  host: localhost
  port: 5432
  username: username
  password: password

test:
  adapter: postgres
  database: my_app_test
  host: localhost
  port: 5432
  username: username
  password: password

production:
  adapter: postgres
  url: <%= ENV["DATABASE_URL"] %>
```

## azu db:create

Creates the database for the current environment.

### Basic Usage

```bash
# Create database for current environment
azu db:create

# Create for specific environment
azu db:create --env production

# Create with custom database name
azu db:create --database my_custom_db
```

### Options

| Option                | Description                     | Default       |
| --------------------- | ------------------------------- | ------------- |
| `--env <environment>` | Target environment              | development   |
| `--database <name>`   | Database name                   | auto-detected |
| `--force`             | Force creation (drop if exists) | false         |

### Examples

```bash
# Create development database
azu db:create
# Created database 'my_app_development'

# Create test database
azu db:create --env test
# Created database 'my_app_test'

# Create production database
azu db:create --env production
# Created database 'my_app_production'
```

### Troubleshooting

```bash
# Permission denied
sudo -u postgres createdb my_app_development

# Database already exists
azu db:create --force

# Connection refused
# Check if database server is running
sudo systemctl status postgresql
```

## azu db:drop

Drops (deletes) the database for the current environment.

### Basic Usage

```bash
# Drop database for current environment
azu db:drop

# Drop for specific environment
azu db:drop --env test

# Drop with confirmation
azu db:drop --confirm
```

### Options

| Option                | Description               | Default     |
| --------------------- | ------------------------- | ----------- |
| `--env <environment>` | Target environment        | development |
| `--confirm`           | Skip confirmation prompt  | false       |
| `--force`             | Force drop without checks | false       |

### Examples

```bash
# Drop development database
azu db:drop
# Are you sure you want to drop 'my_app_development'? (y/N): y
# Dropped database 'my_app_development'

# Drop test database without confirmation
azu db:drop --env test --confirm
# Dropped database 'my_app_test'
```

### Safety Features

```bash
# Confirmation prompt prevents accidental drops
azu db:drop
# Are you sure you want to drop 'my_app_development'? (y/N): n
# Database drop cancelled

# Force drop (use with caution)
azu db:drop --force
# Dropped database 'my_app_development'
```

## azu db:migrate

Runs pending database migrations to update the database schema.

### Basic Usage

```bash
# Run all pending migrations
azu db:migrate

# Run migrations for specific environment
azu db:migrate --env production

# Run with verbose output
azu db:migrate --verbose
```

### Options

| Option                | Description                 | Default     |
| --------------------- | --------------------------- | ----------- |
| `--env <environment>` | Target environment          | development |
| `--version <version>` | Migrate to specific version | latest      |
| `--verbose`           | Show detailed output        | false       |
| `--dry-run`           | Show what would be migrated | false       |

### Examples

```bash
# Run all pending migrations
azu db:migrate
# == 20231201000001 CreateUsers: migrating ========================
# -- create_table(:users)
#    -> 0.1234s
# == 20231201000001 CreateUsers: migrated (0.1234s) ===============

# Run to specific version
azu db:migrate --version 20231201000001

# Dry run (show what would happen)
azu db:migrate --dry-run
# Would run migration: 20231201000001_create_users.cr
# Would run migration: 20231201000002_add_email_to_users.cr
```

### Migration Status

```bash
# Check migration status
azu db:migrate:status

# Output:
# Status   Migration ID    Migration Name
# ------------------------------------------------------------
# up       20231201000001  CreateUsers
# up       20231201000002  AddEmailToUsers
# down     20231201000003  CreatePosts
```

## azu db:rollback

Rolls back the last migration or a specified number of migrations.

### Basic Usage

```bash
# Rollback last migration
azu db:rollback

# Rollback multiple migrations
azu db:rollback --steps 3

# Rollback to specific version
azu db:rollback --version 20231201000001
```

### Options

| Option                | Description                      | Default     |
| --------------------- | -------------------------------- | ----------- |
| `--env <environment>` | Target environment               | development |
| `--steps <number>`    | Number of migrations to rollback | 1           |
| `--version <version>` | Rollback to specific version     |             |
| `--verbose`           | Show detailed output             | false       |

### Examples

```bash
# Rollback last migration
azu db:rollback
# == 20231201000002 AddEmailToUsers: reverting ===================
# -- remove_column(:users, :email)
#    -> 0.0456s
# == 20231201000002 AddEmailToUsers: reverted (0.0456s) ==========

# Rollback 3 migrations
azu db:rollback --steps 3

# Rollback to specific version
azu db:rollback --version 20231201000001
```

### Safety Features

```bash
# Confirmation for destructive operations
azu db:rollback --steps 5
# This will rollback 5 migrations. Continue? (y/N): y

# Dry run to see what would happen
azu db:rollback --dry-run
# Would rollback: 20231201000002_add_email_to_users.cr
```

## azu db:reset

Drops, creates, and migrates the database in one command.

### Basic Usage

```bash
# Reset database for current environment
azu db:reset

# Reset for specific environment
azu db:reset --env test

# Reset with seed data
azu db:reset --seed
```

### Options

| Option                | Description               | Default     |
| --------------------- | ------------------------- | ----------- |
| `--env <environment>` | Target environment        | development |
| `--seed`              | Run seed data after reset | false       |
| `--confirm`           | Skip confirmation prompt  | false       |

### Examples

```bash
# Reset development database
azu db:reset
# Dropped database 'my_app_development'
# Created database 'my_app_development'
# == 20231201000001 CreateUsers: migrating ========================
# == 20231201000001 CreateUsers: migrated (0.1234s) ===============

# Reset with seed data
azu db:reset --seed
# ... database operations ...
# Seeding database...
# Created 10 users
# Created 25 posts
```

### Use Cases

```bash
# Development reset
azu db:reset --env development

# Test environment reset
azu db:reset --env test --seed

# Production reset (use with extreme caution)
azu db:reset --env production --confirm
```

## azu db:seed

Runs seed data to populate the database with initial data.

### Basic Usage

```bash
# Run seed data for current environment
azu db:seed

# Run for specific environment
azu db:seed --env production

# Run specific seed file
azu db:seed --file users
```

### Options

| Option                | Description               | Default     |
| --------------------- | ------------------------- | ----------- |
| `--env <environment>` | Target environment        | development |
| `--file <name>`       | Specific seed file to run | all         |
| `--verbose`           | Show detailed output      | false       |

### Examples

```bash
# Run all seed files
azu db:seed
# Seeding database...
# Created 10 users
# Created 25 posts
# Created 5 categories

# Run specific seed file
azu db:seed --file users
# Seeding users...
# Created 10 users

# Run with verbose output
azu db:seed --verbose
# Seeding database...
# Creating users...
#   - Creating user: john@example.com
#   - Creating user: jane@example.com
# Created 10 users
```

### Seed File Structure

```crystal
# db/seeds/users.cr
require "../src/models/**"

# Create admin user
admin = User.create!(
  name: "Admin User",
  email: "admin@example.com",
  role: "admin"
)

puts "Created admin user: #{admin.email}"

# Create sample users
10.times do |i|
  user = User.create!(
    name: "User #{i + 1}",
    email: "user#{i + 1}@example.com",
    role: "user"
  )
  puts "Created user: #{user.email}"
end
```

## azu db:setup

Creates and migrates the database (equivalent to `create` + `migrate`).

### Basic Usage

```bash
# Setup database for current environment
azu db:setup

# Setup for specific environment
azu db:setup --env test

# Setup with seed data
azu db:setup --seed
```

### Options

| Option                | Description                | Default     |
| --------------------- | -------------------------- | ----------- |
| `--env <environment>` | Target environment         | development |
| `--seed`              | Run seed data after setup  | false       |
| `--force`             | Force recreation if exists | false       |

### Examples

```bash
# Setup development database
azu db:setup
# Created database 'my_app_development'
# == 20231201000001 CreateUsers: migrating ========================
# == 20231201000001 CreateUsers: migrated (0.1234s) ===============

# Setup with seed data
azu db:setup --seed
# ... database operations ...
# Seeding database...
# Created 10 users
```

## azu db:version

Shows the current migration version.

### Basic Usage

```bash
# Show current version
azu db:version

# Show for specific environment
azu db:version --env production
```

### Examples

```bash
# Development environment
azu db:version
# Current version: 20231201000002

# Production environment
azu db:version --env production
# Current version: 20231201000001
```

## Database Adapters

### PostgreSQL

```bash
# Install PostgreSQL adapter
# Add to shard.yml:
# dependencies:
#   cql:
#     github: azutoolkit/cql
#     version: ~> 0.8.0

# Configuration
export DATABASE_URL="postgres://username:password@localhost/my_app_development"
```

### MySQL

```bash
# Install MySQL adapter
# Add to shard.yml:
# dependencies:
#   cql:
#     github: azutoolkit/cql
#     version: ~> 0.8.0

# Configuration
export DATABASE_URL="mysql://username:password@localhost/my_app_development"
```

### SQLite

```bash
# Install SQLite adapter
# Add to shard.yml:
# dependencies:
#   cql:
#     github: azutoolkit/cql
#     version: ~> 0.8.0

# Configuration
export DATABASE_URL="sqlite://./db/development.db"
```

## Common Workflows

### Development Workflow

```bash
# Start new feature
azu db:migrate

# Make changes to models
# Generate new migration
azu generate migration add_field_to_table

# Run migration
azu db:migrate

# If something goes wrong
azu db:rollback

# Reset for clean slate
azu db:reset --seed
```

### Testing Workflow

```bash
# Setup test database
azu db:setup --env test

# Run tests
crystal spec

# Clean up
azu db:drop --env test
```

### Production Workflow

```bash
# Deploy to production
azu db:migrate --env production

# If migration fails
azu db:rollback --env production

# Check current version
azu db:version --env production
```

## Troubleshooting

### Connection Issues

```bash
# Check database server status
sudo systemctl status postgresql

# Test connection
psql -h localhost -U username -d my_app_development

# Check environment variables
echo $DATABASE_URL
```

### Permission Issues

```bash
# Create database user
sudo -u postgres createuser -s username

# Grant permissions
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE my_app_development TO username;"
```

### Migration Issues

```bash
# Check migration status
azu db:migrate:status

# Reset migrations
azu db:reset

# Check migration files
ls -la db/migrations/
```

### Seed Issues

```bash
# Run seed with verbose output
azu db:seed --verbose

# Check seed files
ls -la db/seeds/

# Run specific seed file
azu db:seed --file users
```

## Best Practices

### 1. Environment Management

```bash
# Use different databases for each environment
azu db:create --env development
azu db:create --env test
azu db:create --env staging
```

### 2. Migration Safety

```bash
# Always backup before migrations
pg_dump my_app_production > backup.sql

# Test migrations in staging first
azu db:migrate --env staging

# Use dry-run to preview changes
azu db:migrate --dry-run
```

### 3. Seed Data

```bash
# Keep seeds idempotent
# Use create_or_find instead of create

# Separate seeds by environment
db/seeds/
├── development/
├── test/
└── production/
```

### 4. Database URLs

```bash
# Use DATABASE_URL for all environments
export DATABASE_URL="postgres://username:password@localhost/my_app_development"

# Use .env files for local development
echo "DATABASE_URL=postgres://..." > .env
```

---

The database commands provide a complete workflow for managing your Azu application's database, from creation to migration to seeding.

**Next Steps:**

- [Migration Generator](../generators/migration.md) - Create database migrations
- [Model Generator](../generators/model.md) - Create database models
- [Development Workflows](../workflows/README.md) - Learn database workflows
