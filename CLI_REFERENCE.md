# Azu CLI Reference

Quick reference for the Azu CLI commands. For detail, see [docs/](docs/). `azu help` lists the commands;
`azu help <new|generate|db|serve|dev|routes|console|doctor|test|jobs|session>` shows more. `azu --help` and `azu --version` are not
options: use `azu help` and `azu version`.

## Project Commands

```bash
azu new <name> [options]      # Create new project
azu init                      # Initialize in existing project
azu undo [--dry-run|--list]   # Revert the files of the last azu generate
azu serve [options]           # Start the development server (aliases: server, s)
azu dev [options]             # Run the app; rebuild (not a release build) and restart when the code changes
azu routes [options]          # List the routes: method, path, endpoint, request/response types, helpers
azu console                   # Crystal's interpreter (crystal i) with the app loaded
azu doctor [--json]           # Check Crystal, shards, database, env, secrets, port, docker, .env
azu test [options]            # Run specs (alias: t)
```

### `azu new` Options

| Option                         | Description                                                 |
| ------------------------------ | ----------------------------------------------------------- |
| `--type TYPE`                  | `web` (default), `api` or `cli`                             |
| `--api`                        | Shorthand for `--type api`                                  |
| `--db DATABASE`                | `sqlite` (default, no server), `postgresql` or `mysql`      |
| `--test TEST`                  | `spec` (default) or `minitest`                              |
| `--docker` / `--no-docker`     | Generate a `Dockerfile` and `.dockerignore` (web and api)   |
| `--ci CI` / `--no-ci`          | `GitHub Actions` (default) or `None`                        |
| `--git` / `--no-git`           | Initialize a git repository (default: yes)                  |
| `--example` / `--no-example`   | Include the example code                                    |
| `--joobq` / `--no-joobq`       | Include JoobQ                                               |
| `--name`, `--module`, `--author`, `--email`, `--license` | Project metadata                  |
| `--yes`                        | Non-interactive mode                                        |
| `--ui MODE`                    | `rich` (live progress cards), `plain` (one line per step) or `json` (NDJSON events) |

Without `--yes` on a terminal, `azu new` opens a wizard: one step per option above, a review with the same choices as
one command line, then a live progress card (files, secrets, git, shards, type-check). Without a terminal it prompts
line by line as before.

### `azu serve` Options

`--port`/`-p`, `--host`/`-h`, `--env`/`-e`, `--no-watch`, `--verbose`/`-v`.

### `azu dev` Options

`--port PORT`, `--host HOST`, `--env NAME` (each only overrides what your environment or `.env` files say when given; without `--host` or `HOST`, `azu serve` leaves the host to the app),
`--debounce MS` (default 300), `--interval MS` (polling interval, default 250), `--ui rich|plain`. On a terminal of
at least 60x16 (not CI) `azu dev` opens a dashboard: build with compiler stages, app (pid, uptime, restarts, crashes,
memory), requests and SQL from the app (azu's `Dev::Telemetry` over `AZU_TELEMETRY_SOCKET`), JoobQ queues, the app's
log, and the CLI's own commands (panel `2`: doctor, routes, db:status, test, db:migrate, session:clear, config:*, version, completion, re-run when what they read changes); keys `1`-`6` panels, `r` rebuild, `l` log, `c` clear log, `q` quit. `--ui plain` keeps the line output. `src/**`, `config/**`, `shard.yml` and
`shard.lock` changes build and restart; `public/templates/**` changes neither build nor restart; `.env*` changes restart
without a build. A failed build keeps the running app. See [docs/commands/dev.md](docs/commands/dev.md).

### `azu routes` Options

`--format table|json` (default `table`), `--method METHOD`, `--path TEXT` (substring), `--ui rich|plain` (a card on a
color terminal by default). Exit 0, 1 (the app could not
be loaded), 2 (invalid usage). See [docs/commands/routes.md](docs/commands/routes.md).

### `azu doctor` Options

`--json`, `--ui rich|plain` (a card on a color terminal by default). Exit 0 (warnings allowed) or 1 (a check failed). See [docs/commands/doctor.md](docs/commands/doctor.md).

### `azu console`

No options. Needs a Crystal built with the interpreter, else exits 2. See [docs/commands/console.md](docs/commands/console.md).

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
`--strategy session`, `--type`, `--record`, `--dry-run` (show the files and diffs, write nothing), `--check` (type-check
the project with the generated files first), `--yes` (write without asking), `--ui rich|plain`.

On a terminal, `azu generate` runs the generator in a copy of the project first and shows every file it would write
and the diff of every file it would change, type-checking in the background; Enter writes exactly those files.
`azu generate` with no arguments opens a menu. `azu undo` reverts the last such write (files you edited since are left
as they are). Through a pipe or in CI, without `--dry-run` or `--check`, it generates directly as before.

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
azu session:setup [--backend TYPE] [--force]   # cookie (default), redis or memory
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
azu help [new|generate|db|serve|dev|routes|console|doctor|test|jobs|session]
```

## Common Workflows

### New Project

```bash
azu new my_app            # SQLite by default: no database server needed
cd my_app
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
azu new my_app --docker
cd my_app
docker build -t my_app .
docker run -p 4000:4000 -e CSRF_SECRET=$(openssl rand -hex 32) my_app
```

## Environment Variables

The CLI reads `DATABASE_URL`, `CRYSTAL_ENV` (and `AZU_ENV` in some commands), `REDIS_URL`, `JOOBQ_REDIS_URL`; for
its output `AZU_UI` (`rich`, `plain`, `json`), `NO_COLOR`, `FORCE_COLOR`, `CI`, `AZU_REDUCED_MOTION=1` (no spinners)
and `AZU_AMBIGUOUS_WIDE=1` (ASCII glyphs); `XDG_STATE_HOME` for the undo records. A
generated app reads `PORT`, `HOST` (the generated `.env` leaves it unset, so azu binds `127.0.0.1` in development and `0.0.0.0` elsewhere; `.env.example` has it commented; the production `Dockerfile` sets `0.0.0.0`; in a development container pass `-e HOST=0.0.0.0`), `DATABASE_URL`, `CSRF_SECRET` and, with authentication, `SESSION_SECRET`;
in production (`CRYSTAL_ENV=production`) it refuses to boot without the secrets.

---

For detailed documentation, see [docs/](docs/).
