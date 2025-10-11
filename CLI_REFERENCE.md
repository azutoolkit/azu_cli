# Azu CLI - Complete Command Reference

## Quick Start

```bash
# Create a new project
azu new my-app

# Navigate to project
cd my-app

# Setup database
azu db:create
azu db:migrate

# Generate a model
azu generate model User name:string email:string

# Start development server
azu serve

# Run tests
azu test --watch
```

## All Available Commands

### Project Management

#### `azu new <name> [options]`

Create a new Azu project with interactive prompts or command-line options.

**Options:**

- `--type <type>` - Project type (web, api, cli) [default: web]
- `--database <db>` - Database (postgresql, mysql, sqlite) [default: postgresql]
- `--joobq` - Include JoobQ for background jobs [default: yes]
- `--no-joobq` - Skip JoobQ integration
- `--example` - Include example code [default: yes]
- `--no-example` - Skip example code
- `--docker` - Include Docker support
- `--no-docker` - Skip Docker support
- `--git` - Initialize Git repository [default: yes]
- `--skip-git` - Skip git initialization
- `--yes` - Non-interactive mode (use defaults)

**Example:**

```bash
# Interactive mode (asks about JoobQ and other options)
azu new blog

# API service with background jobs
azu new api-service --type api --database mysql --joobq

# Web app without background jobs
azu new simple-site --type web --no-joobq

# Non-interactive with defaults
azu new my-app --yes
```

#### `azu init`

Initialize Azu in existing project.

### Database Commands

#### `azu db:create [options]`

Create the database for current environment.

**Options:**

- `--force, -f` - Drop and recreate if exists
- `--database, -d <name>` - Specific database name
- `--env, -e <env>` - Environment [default: development]

**Example:**

```bash
azu db:create
azu db:create --database my_app_dev
DATABASE_URL="postgresql://user:pass@localhost/mydb" azu db:create
```

#### `azu db:drop [options]`

Drop the database (with confirmation).

**Options:**

- `--force, -f` - Skip confirmation
- `--database, -d <name>` - Specific database name
- `--env, -e <env>` - Environment

**Example:**

```bash
azu db:drop
azu db:drop --force
```

#### `azu db:migrate [options]`

Run pending database migrations.

**Options:**

- `--version, -v <version>` - Migrate to specific version
- `--verbose` - Show detailed output
- `--dry-run` - Show what would be migrated
- `--env, -e <env>` - Environment

**Example:**

```bash
azu db:migrate
azu db:migrate --verbose
azu db:migrate --dry-run
```

#### `azu db:rollback [options]`

Rollback the last migration(s).

**Options:**

- `--steps, -s <n>` - Number of migrations to rollback [default: 1]
- `--version, -v <version>` - Rollback to specific version
- `--verbose` - Show detailed output
- `--env, -e <env>` - Environment

**Example:**

```bash
azu db:rollback
azu db:rollback --steps 3
azu db:rollback --version 20240101000000
```

#### `azu db:seed [options]`

Seed the database with initial data.

**Options:**

- `--file, -f <path>` - Custom seed file
- `--verbose` - Show detailed output
- `--env, -e <env>` - Environment

**Example:**

```bash
azu db:seed
azu db:seed --file db/seeds/users.cr
```

#### `azu db:reset [options]`

Drop, create, migrate, and seed database.

**Options:**

- `--force, -f` - Skip confirmation
- `--no-seed` - Skip seeding step
- `--env, -e <env>` - Environment

**Example:**

```bash
azu db:reset
azu db:reset --force
azu db:reset --no-seed
```

#### `azu db:status`

Show migration status.

**Example:**

```bash
azu db:status
```

#### `azu db:setup [options]`

Create database and run migrations.

**Options:**

- `--seed` - Run seeds after migration
- `--env, -e <env>` - Environment

**Example:**

```bash
azu db:setup
azu db:setup --seed
```

### Development Commands

#### `azu serve [options]`

Start development server with hot reloading.

**Options:**

- `--port, -p <port>` - Server port [default: 3000]
- `--host, -h <host>` - Server host [default: localhost]
- `--env, -e <env>` - Environment [default: development]
- `--no-watch` - Disable file watching
- `--verbose, -v` - Verbose output

**Example:**

```bash
azu serve
azu serve --port 4000
azu serve --host 0.0.0.0 --port 8080
```

**Aliases:** `azu server`, `azu s`

#### `azu test [files] [options]`

Run application tests.

**Options:**

- `--watch, -w` - Watch mode (continuous testing)
- `--coverage, -c` - Enable coverage reporting
- `--verbose, -v` - Verbose output
- `--parallel, -p` - Run tests in parallel
- `--filter, -f <pattern>` - Filter tests by pattern

**Example:**

```bash
azu test
azu test spec/models/
azu test --watch
azu test --filter User --verbose
```

**Alias:** `azu t`

### Job Queue Commands

#### `azu jobs:worker [options]`

Start background job workers.

**Options:**

- `--workers, -w <n>` - Number of workers [default: 1]
- `--queues, -q <queues>` - Comma-separated queue list [default: default]
- `--daemon, -d` - Run as daemon
- `--verbose, -v` - Verbose output

**Example:**

```bash
azu jobs:worker
azu jobs:worker --workers 4 --queues critical,default,low
REDIS_URL="redis://localhost:6379" azu jobs:worker
```

#### `azu jobs:status`

Show job queue status and statistics.

**Example:**

```bash
azu jobs:status
REDIS_URL="redis://localhost:6379" azu jobs:status
```

#### `azu jobs:clear [options]`

Clear job queues.

**Options:**

- `--all` - Clear all queues
- `--failed` - Clear only failed jobs
- `--force, -f` - Skip confirmation
- `--queue, -q <name>` - Specific queue [default: default]

**Example:**

```bash
azu jobs:clear --queue default
azu jobs:clear --all --force
azu jobs:clear --failed
```

#### `azu jobs:retry [options]`

Retry failed jobs.

**Options:**

- `--all` - Retry all failed jobs
- `--limit, -l <n>` - Limit number of jobs to retry
- `--queue, -q <name>` - Specific queue [default: default]

**Example:**

```bash
azu jobs:retry
azu jobs:retry --all
azu jobs:retry --limit 10
```

#### `azu jobs:ui [options]`

Start JoobQUI web interface.

**Options:**

- `--port, -p <port>` - UI port [default: 4000]
- `--host, -h <host>` - UI host [default: localhost]
- `--verbose, -v` - Verbose output

**Example:**

```bash
azu jobs:ui
azu jobs:ui --port 5000
```

### Session Commands

#### `azu session:setup [options]`

Setup session management.

**Options:**

- `--backend, -b <type>` - Backend (redis, memory, database) [default: redis]
- `--force, -f` - Overwrite existing configuration

**Example:**

```bash
azu session:setup --backend redis
azu session:setup --backend database
```

#### `azu session:clear [options]`

Clear all application sessions.

**Options:**

- `--force, -f` - Skip confirmation
- `--backend, -b <type>` - Override detected backend

**Example:**

```bash
azu session:clear
azu session:clear --force
```

### Generator Commands

#### `azu generate model <name> [attr:type...] [options]`

Generate a CQL model with attributes.

**Options:**

- `--force` - Overwrite existing files
- `--skip-tests` - Skip test generation

**Example:**

```bash
azu generate model User name:string email:string age:int32
azu generate model Post title:string content:text published:bool author_id:int64
```

**Alias:** `azu g model ...`

#### `azu generate service <name> [method:return_type...] [options]`

Generate a service class for business logic.

**Example:**

```bash
azu generate service UserService create:User update:User delete:Bool
azu generate service PaymentService process:Payment refund:Bool
```

#### `azu generate joobq [options]`

Setup JoobQ background job processing infrastructure.

**Options:**

- `--project <name>` - Project name (defaults to current directory)
- `--redis <url>` - Redis connection URL [default: redis://localhost:6379]
- `--no-example` - Skip creating example job

**Example:**

```bash
# Basic setup with defaults
azu generate joobq

# Custom Redis URL
azu generate joobq --redis redis://localhost:6380

# Without example job
azu generate joobq --no-example
```

**Generated:**

- `config/joobq.development.yml` - JoobQ configuration
- `config/joobq.production.yml` - Production configuration
- `config/joobq.test.yml` - Test configuration
- `src/initializers/joobq.cr` - JoobQ initializer
- `src/jobs/example_job.cr` - Example job (optional)

#### `azu generate job <name> [param:type...] [options]`

Generate a background job.

**Options:**

- `--queue <name>` - Queue name [default: default]
- `--retries <count>` - Number of retries [default: 3]
- `--expires <duration>` - Job expiration time [default: 1.days]

**Example:**

```bash
azu generate job EmailNotification user_id:int32 template:string
azu generate job ProcessPayment amount:float64 user_id:int64
azu generate job ImportData file_path:string --queue=imports --retries=5
```

**Generated:**

- `src/jobs/<snake_case_name>_job.cr` - Job struct with JoobQ integration

#### `azu generate mailer <name> [methods...] [options]`

Generate a mailer class for emails.

**Example:**

```bash
azu generate mailer UserMailer welcome password_reset confirmation
azu generate mailer OrderMailer receipt shipping_notification
```

#### `azu generate channel <name> [actions...] [options]`

Generate a WebSocket channel.

**Example:**

```bash
azu generate channel ChatChannel subscribed receive message
azu generate channel NotificationChannel subscribed unsubscribed broadcast
```

#### `azu generate auth [options]`

Generate complete authentication system.

**Options:**

- `--strategy <type>` - Strategy (jwt, session, oauth) [default: jwt]

**Example:**

```bash
azu generate auth --strategy jwt
azu generate auth --strategy session
```

**Generated:**

- User model with password hashing
- Auth endpoints (register, login, logout)
- Contracts for validation
- JWT/session handling

#### `azu generate scaffold <name> [attr:type...] [options]`

Generate complete CRUD scaffold.

**Options:**

- `--force` - Overwrite existing files
- `--api-only` - Generate API-only components
- `--web-only` - Generate web-only components
- `--skip <components>` - Skip components (comma-separated)

**Example:**

```bash
azu generate scaffold Post title:string content:text published:bool
azu generate scaffold Product name:string price:float64 --api-only
azu generate scaffold Article title:string --skip migration,template
```

**Generated:**

- Model with validations
- 7 CRUD endpoints (index, show, new, create, edit, update, destroy)
- 7 contracts for validation
- 7 response pages
- 4 web templates (index, show, new, edit)
- Database migration

#### `azu generate endpoint <name> [actions...] [options]`

Generate RESTful endpoints.

**Example:**

```bash
azu generate endpoint Users index show create update destroy
azu generate endpoint Posts index show --api-only
```

#### `azu generate contract <name> [attr:type...] [options]`

Generate a validation contract.

**Example:**

```bash
azu generate contract UserContract name:string email:string
```

#### `azu generate page <name> [attr:type...] [options]`

Generate a response page.

**Example:**

```bash
azu generate page UserProfile name:string email:string
```

#### `azu generate migration <name> [attr:type...] [options]`

Generate a database migration.

**Example:**

```bash
azu generate migration CreateUsers email:string name:string
azu generate migration AddAgeToUsers age:int32
```

#### `azu generate middleware <name> [options]`

Generate HTTP middleware.

**Options:**

- `--type <type>` - Middleware type

**Example:**

```bash
azu generate middleware Authentication --type auth
azu generate middleware RateLimiter
```

#### `azu generate component <name> [attr:type...] [options]`

Generate a reusable component.

**Example:**

```bash
azu generate component UserCard name:string email:string
```

#### `azu generate validator <name> [options]`

Generate a custom validator.

**Options:**

- `--record <type>` - Record type to validate

**Example:**

```bash
azu generate validator EmailValidator --record User
```

### Other Commands

#### `azu version`

Show CLI version.

#### `azu help [command]`

Show help for all commands or specific command.

**Example:**

```bash
azu help
azu help generate
azu help db
azu help jobs
```

## Environment Variables

### Database

- `DATABASE_URL` - Full database connection string
- `AZU_DB_HOST` - Database host
- `AZU_DB_PORT` - Database port
- `AZU_DB_NAME` - Database name
- `AZU_DB_USER` - Database username
- `AZU_DB_PASSWORD` - Database password
- `AZU_DB_ADAPTER` - Database adapter (postgres, mysql, sqlite)

### Job Queue

- `REDIS_URL` - Redis connection URL
- `JOOBQ_REDIS_URL` - JoobQ-specific Redis URL
- `JOOBQ_QUEUE` - Default queue name
- `JOOBQ_WORKERS` - Number of workers

### Session

- `SESSION_SECRET` - Session encryption secret
- `SESSION_BACKEND` - Session backend (redis, memory, database)
- `REDIS_URL` - Redis URL for session storage

### Development

- `AZU_ENV` - Environment (development, test, production)
- `CRYSTAL_ENV` - Crystal environment
- `JWT_SECRET` - JWT token secret (for auth)

## Configuration Files

Generated projects include:

- `config/database.yml` - Database configuration
- `config/jobs.yml` - Job queue configuration
- `config/session.yml` - Session configuration
- `src/db/seed.cr` - Seed data
- `src/worker.cr` - Background worker process

## Workflow Examples

### Creating a Blog Application

```bash
# 1. Create project
azu new blog

# 2. Setup database
cd blog
azu db:create

# 3. Generate models
azu generate model User name:string email:string
azu generate model Post title:string content:text author_id:int64 published:bool
azu generate model Comment content:text post_id:int64 user_id:int64

# 4. Run migrations
azu db:migrate

# 5. Generate scaffolds for CRUD
azu generate scaffold Post title:string content:text published:bool
azu generate scaffold Comment content:text post_id:int64 user_id:int64

# 6. Setup authentication
azu generate auth --strategy jwt

# 7. Setup sessions
azu session:setup --backend redis

# 8. Generate services
azu generate service PostService create:Post publish:Bool
azu generate service CommentService create:Comment approve:Bool

# 9. Start development server
azu serve

# 10. Run tests in watch mode (in another terminal)
azu test --watch
```

### Creating an API-Only Application

```bash
# 1. Create API project
azu new api-service --type api

# 2. Setup database
cd api-service
azu db:create

# 3. Generate models
azu generate model Product name:string price:float64 stock:int32

# 4. Generate API endpoints
azu generate scaffold Product name:string price:float64 stock:int32 --api-only

# 5. Setup authentication
azu generate auth --strategy jwt

# 6. Generate background jobs
azu generate job ProcessOrder order_id:int64
azu generate job SendEmail recipient:string subject:string

# 7. Migrate database
azu db:migrate

# 8. Start server and workers
azu serve &
azu jobs:worker --workers 4 &
```

### Development Workflow

```bash
# Terminal 1: Development server with hot reload
azu serve

# Terminal 2: Test watcher
azu test --watch

# Terminal 3: Job workers
azu jobs:worker --workers 2

# Terminal 4: Generate code as needed
azu generate model Category name:string
azu generate service CategoryService
```

## Tips & Best Practices

### Database

- Always use `db:reset` with caution (destroys all data)
- Use `db:status` to check migration state before deploying
- Keep seed files idempotent (safe to run multiple times)
- Use environment-specific database names

### Job Queue

- Monitor job queues regularly with `jobs:status`
- Use appropriate queue names for priority (critical, default, low)
- Set up JoobQUI in development for visibility
- Configure retries appropriately for your use case

### Testing

- Use `test --watch` during development
- Run full test suite before commits
- Keep tests fast and isolated
- Use test database separate from development

### Code Generation

- Use `scaffold` for rapid prototyping
- Use individual generators for fine-grained control
- Use `--skip` to exclude components you don't need
- Use `--force` carefully (backs up nothing)

### Sessions

- Use Redis backend in production for scalability
- Use memory backend only in development/testing
- Use database backend if you need session querying
- Always set strong SESSION_SECRET in production

## Common Patterns

### Add Authentication to Existing App

```bash
azu generate auth --strategy jwt
azu db:migrate
# Update routes to include auth endpoints
```

### Add Background Jobs

```bash
azu generate job EmailJob recipient:string template:string
azu session:setup --backend redis  # Ensure Redis is configured
azu jobs:worker --workers 2
```

### Add Real-Time Features

```bash
azu generate channel NotificationChannel
# Implement channel logic
# Add WebSocket route to server
```

### Full CRUD Resource

```bash
azu generate scaffold Article title:string content:text
azu db:migrate
azu serve
```

## Troubleshooting

### Database Connection Issues

```bash
# Check status
azu db:status

# Verify DATABASE_URL
echo $DATABASE_URL

# Use explicit URL
DATABASE_URL="postgresql://user:pass@localhost/db" azu db:create
```

### Job Queue Issues

```bash
# Check Redis connection
redis-cli ping

# Verify queue status
azu jobs:status

# Clear stuck jobs
azu jobs:clear --failed
```

### Development Server Issues

```bash
# Check port availability
lsof -i :3000

# Use different port
azu serve --port 4000

# Verbose output for debugging
azu serve --verbose
```

## Summary

The Azu CLI provides **25+ commands** and **12+ generators** for complete Rails-like development workflow:

- ✅ 8 Database commands
- ✅ 5 Job queue commands
- ✅ 2 Session commands
- ✅ 2 Development commands
- ✅ 12+ Code generators
- ✅ Complete help system
- ✅ Plugin architecture

**All features production-ready and tested! 🚀**
