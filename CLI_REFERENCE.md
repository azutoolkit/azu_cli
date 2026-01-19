# Azu CLI Reference

Quick reference for all Azu CLI commands. For detailed documentation, see [docs/](docs/).

## Project Commands

```bash
azu new <name> [options]      # Create new project
azu init                      # Initialize in existing project
azu serve [options]           # Start development server
azu test [--watch]            # Run tests
```

### `azu new` Options

| Option       | Description                          |
| ------------ | ------------------------------------ |
| `--api`      | Create API-only project              |
| `--database` | Database type (postgres/mysql/sqlite)|
| `--joobq`    | Include background job support       |
| `--docker`   | Include Docker configuration         |
| `--yes`      | Non-interactive mode                 |

## Database Commands

```bash
azu db:create                 # Create database
azu db:drop [--force]         # Drop database
azu db:migrate                # Run pending migrations
azu db:rollback [--steps N]   # Rollback migrations
azu db:seed                   # Run seed data
azu db:reset [--seed]         # Drop, create, migrate
azu db:setup [--seed]         # Create and migrate
azu db:status                 # Show migration status
```

## Generator Commands

```bash
azu generate <type> <name> [fields...] [options]
```

### Available Generators

| Generator    | Description                | Example                                    |
| ------------ | -------------------------- | ------------------------------------------ |
| `model`      | Database model             | `azu generate model User name:string`      |
| `endpoint`   | HTTP endpoint              | `azu generate endpoint users --api`        |
| `scaffold`   | Complete CRUD              | `azu generate scaffold Post title:string`  |
| `migration`  | Database migration         | `azu generate migration AddAvatarToUsers`  |
| `service`    | Business logic service     | `azu generate service CreateUser`          |
| `job`        | Background job             | `azu generate job SendEmail`               |
| `channel`    | WebSocket channel          | `azu generate channel Chat`                |
| `auth`       | Authentication system      | `azu generate auth --strategy jwt`         |
| `middleware` | HTTP middleware            | `azu generate middleware Auth`             |
| `request`    | Request validation         | `azu generate request CreateUser`          |
| `page`       | Response page              | `azu generate page UserIndex`              |
| `mailer`     | Email mailer               | `azu generate mailer Welcome`              |

### Field Types

| Type         | Crystal Type | Example                   |
| ------------ | ------------ | ------------------------- |
| `string`     | `String`     | `name:string`             |
| `text`       | `String`     | `content:text`            |
| `int32`      | `Int32`      | `age:int32`               |
| `int64`      | `Int64`      | `count:int64`             |
| `float64`    | `Float64`    | `price:float64`           |
| `bool`       | `Bool`       | `active:bool`             |
| `time`       | `Time`       | `published_at:time`       |
| `uuid`       | `UUID`       | `uuid:uuid`               |
| `references` | `Int64`      | `user_id:references`      |

## Job Commands (JoobQ)

```bash
azu jobs:worker [--workers N] # Start job workers
azu jobs:status               # Show queue status
azu jobs:clear [--queue NAME] # Clear job queues
azu jobs:retry [--queue NAME] # Retry failed jobs
azu jobs:ui [--port PORT]     # Start web interface
```

## Session Commands

```bash
azu session:setup [--backend TYPE]  # Setup sessions (redis/memory/database)
azu session:clear                    # Clear all sessions
```

## OpenAPI Commands

```bash
azu openapi:export [--output FILE]  # Export OpenAPI spec
azu openapi:generate [--input FILE] # Generate from spec
```

## Common Workflows

### New Project

```bash
azu new my_app --database postgres
cd my_app
azu db:create && azu db:migrate
azu serve
```

### Add a Feature

```bash
azu generate scaffold Product name:string price:float64
azu db:migrate
```

### Start Background Jobs

```bash
azu jobs:worker --workers 4
```

## Environment Variables

| Variable       | Description                     |
| -------------- | ------------------------------- |
| `DATABASE_URL` | Database connection string      |
| `AZU_ENV`      | Environment (development/test)  |
| `PORT`         | Server port (default: 4000)     |

## Help

```bash
azu --help                    # Show all commands
azu <command> --help          # Show command help
azu --version                 # Show version
```

---

For detailed documentation, see [docs/](docs/).
