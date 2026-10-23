# CLI Options Reference

The options below are the ones the CLI registers; the help text (`azu help`, `azu help <topic>`) lists the same.
There are no global options: each command parses its own, and `--help` is only understood by `new`, `generate`,
`openapi:*`, `config:*` and `completion`. Some commands run when given an unknown flag, so check before passing `--help`.

Quick reference for the Azu CLI commands. For detail, see [docs/](docs/). `azu help` lists the commands;
`azu help <new|generate|db|serve|test|jobs|session>` shows more. `azu --help` and `azu --version` are not
options: use `azu help` and `azu version`.

## Project Commands

```bash
azu new <name> [options]      # Create new project
azu init                      # Initialize in existing project
azu serve [options]           # Start the development server (aliases: server, s)
azu test [options]            # Run specs (alias: t)
```

### `azu new` Options

| Option                         | Description                                                 |
| ------------------------------ | ----------------------------------------------------------- |
| `--type TYPE`                  | `web` (default), `api` or `cli`                             |
| `--api`                        | Shorthand for `--type api`                                  |
| `--db DATABASE`                | `postgresql` (default), `mysql` or `sqlite`                 |
| `--test TEST`                  | `spec` (default) or `minitest`                              |
| `--docker` / `--no-docker`     | Generate a `Dockerfile` and `.dockerignore` (web and api)   |
| `--ci CI` / `--no-ci`          | `GitHub Actions` (default) or `None`                        |
| `--git` / `--no-git`           | Initialize a git repository (default: yes)                  |
| `--example` / `--no-example`   | Include the example code                                    |
| `--joobq` / `--no-joobq`       | Include JoobQ                                               |
| `--name`, `--module`, `--author`, `--email`, `--license` | Project metadata                  |
| `--yes`                        | Non-interactive mode                                        |

### `azu serve` Options

`--port`/`-p`, `--host`/`-h`, `--env`/`-e`, `--no-watch`, `--verbose`/`-v`.

### `azu test` Options

`--watch`/`-w`, `--coverage`/`-c`, `--verbose`/`-v`, `--parallel`/`-p`, `--filter`/`-f PATTERN`, and spec paths.

## Database Commands

```bash
azu db:create                 # Create database
azu db:drop [--force]         # Drop database
azu db:migrate [--steps N] [--version V] [--dry-run]
azu db:rollback [--steps N] [--version V] [--dry-run] [--force]
azu db:seed                   # Run seed data
azu db:reset [--seed|--no-seed] [--force]   # Drop, create, migrate
azu db:setup [--seed|--no-seed]             # Create and migrate
azu db:status                 # Show migration status
azu db:schema:load [--file F] # Load a schema file
azu db:data:migrate           # Run data migrations
azu db:migrations:verify      # Check migrations roll back and re-apply
azu db:validate               # Check the database configuration and connection
```

Every database command accepts `--env`/`-e`.

## Generator Commands

```bash
azu generate <type> <name> [attribute:type...] [options]     # alias: azu g
```

| Generator        | Description                                    | Example                                   |
| ---------------- | ---------------------------------------------- | ----------------------------------------- |
| `model`          | Model with its migration                       | `azu generate model User name:string`     |
| `scaffold`       | CRUD: model, endpoints, pages, migration       | `azu generate scaffold Post title:string` |
| `endpoint`       | Endpoints with request and page                | `azu generate endpoint Users index show`  |
| `migration`      | Database migration                             | `azu generate migration create_posts`     |
| `data:migration` | Data migration                                 | `azu generate data:migration BackfillSlugs` |
| `service`        | Service                                        | `azu generate service CreateUser`         |
| `request`        | Request contract                               | `azu generate request CreateUser`         |
| `response`       | Response object                                | `azu generate response User`              |
| `page`           | Page with its template                         | `azu generate page UserIndex`             |
| `component`      | Component                                      | `azu generate component Counter`          |
| `middleware`     | HTTP middleware                                | `azu generate middleware Auth`            |
| `validator`      | Custom validator                               | `azu generate validator Email`            |
| `mailer`         | Mailer                                         | `azu generate mailer Welcome`             |
| `channel`        | WebSocket channel (`Azu::Channel`)             | `azu generate channel Chat`               |
| `auth`           | Session authentication (web projects)          | `azu generate auth`                       |
| `job`, `joobq`   | JoobQ job; JoobQ setup                         | `azu generate job SendEmail`              |
| `seed`, `template`, `api_resource` | Seed file; template; API resource | `azu generate seed Users`             |

Options: `--force`, `--skip-tests` (model: no migration), `--skip COMPONENTS`, `--api-only`, `--web-only`,
`--strategy session`, `--type`, `--record`.

Attribute types: `string`, `text`, `int32`, `int64`, `float64`, `bool`, `time`, `uuid`; `name:type:unique`,
`name:type:index`; `user_id:references` / `user_id:int64:ref:users` for foreign keys.

## Job Commands (JoobQ)

```bash
azu jobs:worker [--workers N] [--queues LIST] [--daemon] [--verbose]
azu jobs:status
azu jobs:clear [--queue NAME] [--all] [--failed] [--force]
azu jobs:retry [--queue NAME] [--all] [--limit N]
azu jobs:ui [--port PORT] [--host HOST]
```

## Session Commands

```bash
azu session:setup [--backend TYPE] [--force]   # redis, memory or database
azu session:clear [--backend TYPE] [--force]
```

`session:setup` writes its own session initializer and handler: do not combine it with `azu generate auth`.

## OpenAPI Commands

```bash
azu openapi:export [--output FILE] [--format yaml|json] [--project NAME] [--version V]
azu openapi:generate <spec> [--force] [--models-only] [--endpoints-only]
```

## Configuration Commands

```bash
azu config:show [--format yaml|json|table] [--env ENV] [--section NAME]
azu config:validate [--env ENV]
azu config:env [--list|--show|--set K=V|--unset K]
```

## Other

```bash
azu completion bash|zsh|fish   # shell completion script
azu version
azu help [new|generate|db|serve|test|jobs|session]
```

## Common Workflows

### New Project

```bash
azu new my_app --db sqlite
cd my_app && shards install
azu db:setup
azu serve
```

### Add a Feature

```bash
azu generate scaffold Product name:string price:float64
azu db:migrate
```

### Ship It

```bash
azu new my_app --db sqlite --docker
cd my_app
docker build -t my_app .
docker run -p 4000:4000 -e CSRF_SECRET=$(openssl rand -hex 32) my_app
```

## Environment Variables

The CLI reads `DATABASE_URL`, `CRYSTAL_ENV` (and `AZU_ENV` in some commands), `REDIS_URL`, `JOOBQ_REDIS_URL`. A
generated app reads `PORT`, `HOST`, `DATABASE_URL`, `CSRF_SECRET` and, with authentication, `SESSION_SECRET`;
in production (`CRYSTAL_ENV=production`) it refuses to boot without the secrets.

---

For detailed documentation, see [docs/](docs/).
