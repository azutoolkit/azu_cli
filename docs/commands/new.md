# azu new

The `azu new` command creates a new Azu project from scratch. This is the primary way to start a new application with Azu CLI.

## Overview

```bash
azu new <project_name> [options]
```

## The wizard

Run without `--yes` on a terminal, `azu new` opens a wizard: module, author, email, license, type, database, tests,
jobs and extras (Docker, GitHub Actions, git, example code), with the answers so far beside each step. Steps that do not
apply are skipped (a `cli` project has no database or jobs step). The review screen shows what will happen, checks
that `crystal`, `shards` and `git` are on the `PATH`, and prints the same choices as one `azu new … --yes` command
line. Then a live card follows the work (files, `.env` secrets, git, `shards install` with a count, type-check) and a
last card lists the next steps.

Keys: arrows (or `j`/`k`) move, Space toggles, Enter goes on, Shift-Tab goes back, Esc cancels (nothing is written).
`--ui plain` (or `AZU_UI=plain`, or no terminal) uses line prompts and one line per step; `--ui json` prints NDJSON
events.

## Basic Usage

### Create a Simple Web Application

```bash
# Create a new web application (SQLite: no database server needed)
azu new my_blog

# Navigate to the project
cd my_blog

# Create the SQLite database (db/my_blog_development.db) and run the migrations
azu db:setup

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
# SQLite (default): a file, no server
azu new my_app

# PostgreSQL
azu new my_app --db postgresql

# MySQL
azu new my_app --db mysql
```

## Command Options

| Option                     | Description                                              | Default        |
| -------------------------- | -------------------------------------------------------- | -------------- |
| `--type <type>`            | Project type (web, api, cli)                             | web            |
| `--api`                    | Shorthand for `--type api`                               |                |
| `--db <db>`                | Database adapter (sqlite, postgresql, mysql)             | sqlite         |
| `--test <framework>`       | Test framework (spec, minitest)                          | spec           |
| `--docker`                 | Generate a `Dockerfile` and `.dockerignore` (web, api)   | off            |
| `--ci <setup>`, `--no-ci`  | `GitHub Actions` or `None`                               | GitHub Actions |
| `--git`, `--no-git`        | Initialize a git repository                              | on             |
| `--example`, `--no-example`| Include the example code                                 | on             |
| `--joobq`, `--no-joobq`    | Include JoobQ                                            | on             |
| `--name`, `--module`, `--author`, `--email`, `--license` | Project metadata           |                |
| `--yes`                    | Non-interactive: take the defaults                       |                |

An existing directory is never overwritten: choose another name.

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

- An `OptionParser` program with `--help`, `--version` (and, with the example, `--hello NAME`)
- No web server, database, background jobs, `.env` or assets; no dependencies in `shard.yml` (`--db` is ignored)
- `shards build` builds `bin/<name>`

**Generated Structure:**

```
my_cli_tool/
├── src/
│   └── my_cli_tool.cr         # The program (MyCliTool.run)
├── spec/
│   ├── spec_helper.cr
│   └── my_cli_tool_spec.cr
├── shard.yml                  # target my_cli_tool: src/my_cli_tool.cr
├── README.md, LICENSE, .gitignore, .editorconfig, .tool-versions
└── .github/workflows/ci.yml   # unless --no-ci
```

## Database Options

`azu new` used PostgreSQL by default before; it now uses SQLite, so a new project runs without a database server.
Pass `--db postgresql` (or `--db mysql`) for a server database.

### PostgreSQL (`--db postgresql`)

**For production applications with a database server.**

```bash
azu new my_app --db postgresql
```

**Features:**

- Full ACID compliance
- Advanced features (JSON, arrays, etc.)
- Excellent performance
- Rich ecosystem

**Requirements:**

- PostgreSQL server installed
- Database user with create privileges

### MySQL (`--db mysql`)

**Good for web applications and smaller projects.**

```bash
azu new my_app --db mysql
```

**Features:**

- Widely supported
- Good performance
- Easy to find hosting

**Requirements:**

- MySQL server installed
- Database user with create privileges

### SQLite (`--db sqlite`, the default)

**Perfect for development, prototypes, and simple applications.**

```bash
azu new my_app
```

`.env.development` and `.env.test` point `DATABASE_URL` at `db/my_app_development.db` and `db/my_app_test.db`;
`azu db:setup` creates the file. The generated CI workflow needs no database service.

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

## Docker and CI

### Docker (`--docker`)

Generates a multi-stage `Dockerfile` and a `.dockerignore`:

- build stage `crystallang/crystal:<version of the template>` with the system packages the CI job installs,
  `shards install`, and a `crystal build --release` of `src/server.cr` (web) or `src/api.cr` (api);
- runtime stage on `ubuntu:26.04` (the release of the build image) with only the shared libraries the binary links against, a non-root user,
  `CRYSTAL_ENV=production`, `HOST=0.0.0.0`, `PORT=4000` and a `HEALTHCHECK` on `/health`;
- on SQLite, a `/data` volume and `DATABASE_URL=sqlite3:///data/<project>.db`.

The secrets are not in the image. A web container refuses to start without `CSRF_SECRET` (and, once you generate
authentication, `SESSION_SECRET`):

```bash
docker build -t my_app .
docker run -p 4000:4000 -e CSRF_SECRET=$(openssl rand -hex 32) my_app
```

The image does not run migrations. A CLI project has no server, so `--docker` is refused for `--type cli`.
`scripts/e2e_docker.sh` in this repository builds and runs a generated image (it needs a docker daemon).

### CI (`--ci`)

`--ci "GitHub Actions"` (the default) generates `.github/workflows/ci.yml`: in a `crystallang/crystal` container pinned
to the Crystal version of the template (also in `.tool-versions`), it installs the system packages and shards, checks
formatting (`crystal tool format --check src spec`), runs the specs and builds the entry point. `--no-ci` skips it.
GitLab CI is not supported.

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
    config.port = 4000
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

targets:
  my_app:
    main: src/server.cr

dependencies:
  azu:
    github: azutoolkit/azu
    version: ~> 0.10.1
  cql:
    github: azutoolkit/cql
    version: 0.0.604
  session:
    github: azutoolkit/session
    version: ~> 1.1
  # ... joobq, redis, topia
  sqlite3: # pg ~> 0.31.0 with --db postgresql, mysql ~> 0.18.0 with --db mysql
    github: crystal-lang/crystal-sqlite3
    version: ~> 0.24.0
```

**`.env`, `.env.development`, `.env.test`, `.env.example`** - Environment files. The app (and every `azu` command
except `new`) loads them at boot; precedence, highest first: variables already in the environment (never
overridden), `.env.local`, `.env.<CRYSTAL_ENV>`, `.env`.

- `.env` is git-ignored: random `CSRF_SECRET` (and `SESSION_SECRET` after `azu generate auth`), `PORT`, `HOST`, log settings
- `.env.development` / `.env.test` are committed: the `DATABASE_URL` of that environment, and in development
  `PERFORMANCE_MONITORING=true`, which records the requests the development dashboard (`/dev-dashboard`) shows
- `.env.example` is committed: every variable the app reads, with the secrets left blank
- `.env.local` (git-ignored) is yours for machine-specific overrides

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
   azu db:setup
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

**`src/initializers/cql_config.cr`** - Azu + CQL setup:

```crystal
require "sqlite3" # "pg" with --db postgresql, "mysql" with --db mysql
require "azu/cql"

Azu::CQL.configure do |c|
  c.db = ENV["DATABASE_URL"]? || "sqlite3://./db/my_app_#{ENV["CRYSTAL_ENV"]? || "development"}.db"
  c.pool.size = 10
end

# The schema (src/db/schema.cr) loads after the initializers, so it is attached lazily
Azu::CQL.attach { MyAppDB }
```

```crystal
# src/db/schema.cr: URL, adapter and pool come from CQL.config
MyAppDB = Azu::CQL.schema :my_app_db do
  table :users do
    primary :id, Int64
    column :name, String
  end
end
```

Azu's dev dashboard (`/dev-dashboard`) then shows a **Database** tab with every query. See the
[azu database dashboard guide](https://github.com/azutoolkit/azu/blob/master/docs/reference/database-dashboard.md).
Tables used by models must be declared in `src/db/schema.cr`; migrations are run with
`auto_sync: false`, so they never rewrite that file.
`

## Examples

### Complete Blog Application

```bash
# Create blog with PostgreSQL
azu new my_blog --db postgresql --type web

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
azu new user_api --type api --db postgresql

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

# Build and run
shards build
./bin/file_processor --help
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

3. **Setup database (SQLite needs no server; with `--db postgresql` or `mysql`, start the server first):**

   ```bash
   azu db:setup
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

Check the permissions of the directory you run `azu new` in, or run it from another directory.

### Database Connection Error

With `--db postgresql` or `--db mysql`, ensure the database server is running and the user can create databases, or
use the default SQLite.

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
- [Quick Start](../getting-started/quickstart.md) - Build your first feature
- [Database Commands](database.md) - Manage your database
