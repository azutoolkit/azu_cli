# Database Commands

Azu CLI provides a comprehensive set of database commands for managing your application's database. These commands work with CQL ORM and support PostgreSQL, MySQL, and SQLite.

## Overview

All database commands follow the pattern:

```bash
azu db <command> [options]
```

## Available Commands

| Command                | Description                        |
| ---------------------- | ---------------------------------- |
| `azu db create`        | Create the database                |
| `azu db migrate`       | Run pending migrations             |
| `azu db rollback`      | Rollback migrations                |
| `azu db reset`         | Drop, create, and migrate database |
| `azu db seed`          | Run seed data                      |
| `azu db status`        | Show migration status              |
| `azu db new_migration` | Create a new migration file        |

## Database Configuration

### Environment Variables

```bash
# Database URL (recommended)
export DATABASE_URL="postgresql://username:password@localhost/my_app_development"

# Or individual components
export AZU_DB_HOST="localhost"
export AZU_DB_PORT="5432"
export AZU_DB_NAME="my_app_development"
export AZU_DB_USER="username"
export AZU_DB_PASSWORD="password"
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

## azu db create

Creates the database for the current environment.

### Basic Usage

```bash
# Create database for current environment
azu db create

# Create with custom database name
azu db create --database my_custom_db
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
azu db create
# Created database 'my_app_development'

# Create with custom name
azu db create --database my_custom_db
# Created database 'my_custom_db'
```

### Troubleshooting

```bash
# Permission denied
sudo -u postgres createdb my_app_development

# Database already exists
azu db create --force

# Connection refused
# Check if database server is running
sudo systemctl status postgresql
```

## azu db reset

Resets the database by dropping, creating, migrating, and optionally seeding.

### Basic Usage

```bash
# Reset database for current environment
azu db reset

# Reset with confirmation
azu db reset --force
```

### Options

| Option    | Description              | Default |
| --------- | ------------------------ | ------- |
| `--force` | Skip confirmation prompt | false   |

### Examples

```bash
# Reset development database
azu db reset
# Are you sure? [y/N]: y
# Reset database 'my_app_development'

# Reset without confirmation
azu db reset --force
# Reset database 'my_app_development'
```

## azu db migrate

Runs pending database migrations to update the database schema.

### Basic Usage

```bash
# Run all pending migrations
azu db migrate

# Run with verbose output
azu db migrate --verbose
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
azu db migrate
# == 20231201000001 CreateUsers: migrating ========================
# -- create_table(:users)
#    -> 0.1234s
# == 20231201000001 CreateUsers: migrated (0.1234s) ===============

# Run to specific version
azu db migrate --version 20231201000001

# Check migration status
azu db status

# Output:
# Status   Migration ID    Migration Name
# ------------------------------------------------------------
# up       20231201000001  CreateUsers
# up       20231201000002  AddEmailToUsers
# down     20231201000003  CreatePosts
```

## azu db rollback

Rolls back the last migration or a specified number of migrations.

### Basic Usage

```bash
# Rollback last migration
azu db rollback

# Rollback multiple migrations
azu db rollback --steps 3
```

### Options

| Option             | Description                      | Default |
| ------------------ | -------------------------------- | ------- |
| `--steps <number>` | Number of migrations to rollback | 1       |
| `--verbose`        | Show detailed output             | false   |

### Examples

```bash
# Rollback last migration
azu db rollback
# == 20231201000002 AddEmailToUsers: reverting ===================
# -- remove_column(:users, :email)
#    -> 0.0456s
# == 20231201000002 AddEmailToUsers: reverted (0.0456s) ==========

# Rollback 3 migrations
azu db rollback --steps 3
```

## azu db reset

Drops, creates, and migrates the database in one command.

### Basic Usage

```bash
# Reset database for current environment
azu db reset

# Reset with seed data
azu db reset --seed
```

### Options

| Option    | Description               | Default |
| --------- | ------------------------- | ------- |
| `--seed`  | Run seed data after reset | false   |
| `--force` | Skip confirmation prompt  | false   |

### Examples

```bash
# Reset development database
azu db reset
# Dropped database 'my_app_development'
# Created database 'my_app_development'
# == 20231201000001 CreateUsers: migrating ========================
# == 20231201000001 CreateUsers: migrated (0.1234s) ===============

# Reset with seed data
azu db reset --seed
# ... database operations ...
# Seeding database...
# Created 10 users
# Created 25 posts
```

## azu db seed

Runs seed data to populate the database with initial data.

### Basic Usage

```bash
# Run seed data for current environment
azu db seed
```

### Examples

```bash
# Run all seed files
azu db seed
# Seeding database...
# Created 10 users
# Created 25 posts
# Created 5 categories
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

## azu db new_migration

Creates a new migration file.

### Basic Usage

```bash
# Create new migration
azu db new_migration create_users_table

# Create migration with timestamp
azu db new_migration add_email_to_users
```

### Examples

```bash
# Create migration file
azu db new_migration create_users_table
# Created migration: src/db/migrations/20240115000000_create_users_table.cr

# Migration content will include:
# - up method for applying changes
# - down method for rolling back changes
```

## azu db status

Shows the current migration status.

### Basic Usage

```bash
# Show migration status
azu db status
```

### Examples

```bash
# Check migration status
azu db status
# Migration Status:
#   [✓] 20231201000001_create_users
#   [✓] 20231201000002_add_email_to_users
#   [ ] 20231201000003_add_phone_to_users
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
azu db migrate

# Make changes to models
# Generate new migration
azu generate migration add_field_to_table

# Run migration
azu db migrate

# If something goes wrong
azu db rollback

# Reset for clean slate
azu db reset --seed
```

### Testing Workflow

```bash
# Setup test database
azu db create
azu db migrate

# Run tests
crystal spec

# Clean up
azu db reset
```

### Production Workflow

```bash
# Deploy to production
azu db migrate

# If migration fails
azu db rollback

# Check current status
azu db status
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
azu db status

# Reset migrations
azu db reset

# Check migration files
ls -la src/db/migrations/
```

### Seed Issues

```bash
# Run seed data
azu db seed

# Check seed files
ls -la src/db/

# Check seed file content
cat src/db/seed.cr
```

## Best Practices

### 1. Environment Management

```bash
# Use different databases for each environment
azu db create
# Database name will be based on project name and environment
```

### 2. Migration Safety

```bash
# Always backup before migrations
pg_dump my_app_production > backup.sql

# Test migrations in development first
azu db migrate

# Check migration status
azu db status
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
