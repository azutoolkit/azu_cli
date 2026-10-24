# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Azu CLI** is a feature-complete, production-ready command-line interface for the Azu Toolkit - a Rails-like framework for Crystal that provides database management, code generation, hot reloading, and comprehensive development tools.

- **Language**: Crystal 1.19.1 or newer (CI tests 1.19.1 and the latest release)
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

3. **Generators (src/azu_cli/generators/)** (a `Project` generator overrides `rendered_file_entries`; its `filter` method is not called by Teeplate)

   - Use Teeplate for file tree generation
   - Each generator inherits from `Teeplate::FileTree`
   - Template files use ECR (Embedded Crystal) in `templates/` directory
   - Generators support:
     - Models (CQL ORM)
     - Endpoints (HTTP handlers)
     - Services (business logic)
     - Scaffolds (complete CRUD)
     - Authentication (session cookie, web projects)
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
   - Internal hook system (`Plugins::Base`: `on_load`, `before_command`, `after_command`, `on_error`)
   - Built-in plugins: GeneratorPlugin, DatabasePlugin, DevelopmentPlugin; there is no `azu plugin` command and
     no external plugin installation

### Key Design Patterns

**Command Pattern**: Each CLI command is a class with `execute` method returning `Result`

**Template Pattern**: Generators use Teeplate with ECR templates for code generation

**Middleware Pipeline**: Commands pass through middleware chain for logging, config, error handling

**Plugin System**: Extensibility through plugin hooks at CLI lifecycle events

**Type Safety**: Crystal's type system enforced throughout - explicit type annotations for public APIs

### Database Integration (CQL ORM)

- Migrations are `CQL::Migration(<version>)` classes in `src/db/migrations/<version>_<name>.cr`; the version is a
  timestamp, and the migration generator picks an unused one when two are generated in the same second
- `src/db/schema.cr` declares every table (`Azu::CQL.schema`); the model generator registers a created table there once
- Supports PostgreSQL, MySQL, SQLite (only SQLite runs without a server: the e2e gate uses it)
- Models include `CQL::ActiveRecord::Model(Int64)` and bind to the schema with `db_context`
- Generated projects pin `cql` to exactly 0.0.604 and the drivers to `pg ~> 0.31.0`, `mysql ~> 0.18.0`, `sqlite3 ~> 0.24.0` (all on crystal-db ~> 0.15.0) (`templates/project/shard.yml.ecr`); the e2e gates run them on crystal-db 0.15. `CQL::Postgres::Connection#driver_name` is absent in tag v0.0.562 and present from v0.0.565, which is what the old TODO blamed for holding generated apps at 0.0.541

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
│       ├── schema.cr    # Table declarations (the generators add to it)
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

### CQL ORM Patterns (as the generators emit them)

Model (`src/models/post.cr`):

```crystal
require "cql"

class Post
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :posts

  property title : String
  property body : String
  property created_at : Time?
  property updated_at : Time?

  def initialize(@title : String, @body : String)
  end
end
```

Migration (`src/db/migrations/<version>_create_posts.cr`) and the same table in `src/db/schema.cr`:

```crystal
class CreatePosts < CQL::Migration(20261023111721)
  def up
    schema.table :posts do
      primary :id, Int64, auto_increment: true
      text :title
      text :body
      timestamps
    end
    schema.posts.create!
  end

  def down
    schema.posts.drop!
  end
end
```

### Azu Contract Style (as the generators emit it)

- One `Azu::Endpoint(Request, Response)` has ONE response type: a redirecting action returns `Azu::Response::Empty`
  (`redirect to: "/posts/#{record.id}", status: 303`), a rendering one returns its page; never a union
- Requests are `Azu::Request` structs with `getter` fields and `validate`; pages include `Azu::Response` and
  `Azu::Templates::Renderable` and render a Jinja template with `view data: {...}`
- Naming (the scaffold scheme): `Blog::<Plural>::<Action><Layer>`, e.g. `Blog::Posts::CreateEndpoint`,
  `Blog::Posts::CreateRequest`, `Blog::Posts::ShowPage`, `Blog::Posts::CreateService`; files at
  `src/<layer>s/<plural>/<action>_<layer>.cr`, templates at `public/templates/<app>/<plural>/<action>_page.jinja`.
  Channels and authentication follow it: `Blog::Registrations::CreateEndpoint`, `Blog::Sessions::*`, `Blog::Account::ShowEndpoint`
- Web forms carry the CSRF field (`Azu::Handler::CSRF.default` is the instance configured with `CSRF_SECRET`); writes
  answer 303

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

- Versions are timestamps (e.g. `20261023111721`); files are `src/db/migrations/{version}_{name}.cr`
- A second `create_*` migration whose class name exists is refused
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

## Environment files (`.env`)

- The generated app file starts with `require "azu/env"; Azu::Env.load_all` BEFORE `require "azu"` (Azu::CONFIG reads
  PORT/HOST/CRYSTAL_ENV when azu is required). Precedence: process env > `.env.local` > `.env.<CRYSTAL_ENV>` > `.env`;
  a file never overrides a variable the process already has
- `AzuCLI.run` calls `load_project_env` (`AzuCLI::DotEnv`, `src/azu_cli/dot_env.cr`) before `Config.load!`, for every
  command except `new`, `init`, `help`, `version`, `completion`. The CLI does not depend on azu, so `DotEnv` is a copy of
  the parser in azu's `src/azu/env.cr`: change both, and keep `spec/azu_cli/dot_env_spec.cr` in step with `spec/azu/env_spec.cr`
- Trust model (best effort, not a sandbox): the CLI loads the `.env*` of whatever project it runs in and then spawns
  tools. `DotEnv` always skips the `UNSAFE_NAME` denylist (`LD_*`, `PATH`, `HOME`, `CC`/`CXX`/`*FLAGS`, `SHARDS_*`, `GIT_*`,
  `CRYSTAL_*` except `CRYSTAL_ENV`/`CRYSTAL_LOG_*`, `DOCKER_*`, `COMPOSE_*`, `SSH_*`, proxies, certs, interpreter and editor
  variables, ...), and applies any other name only if it matches `APP_NAME` (DATABASE_URL, PORT, `*_SECRET`, `*_URL`, ...)
  or is listed in the project's `.env.example` (so every name the generated `.env` holds must be in the generated
  `.env.example`: a spec checks it). The CLI still compiles and runs the project's own code, so it is NOT safe in an
  untrusted checkout. `load_project_env` honours the command's `--env` (a value starting with `-` and anything after `--`
  are ignored; `test` = `test`) before loading, and `azu test` warns when a shell `DATABASE_URL` will win.
  `spec/fixtures/dotenv_corpus.json` must stay identical to azu's (both specs pin its SHA256)
- Generated files: `.env` (git-ignored, chmod 0600, random secrets), `.env.development` / `.env.test` (committed, `DATABASE_URL` only),
  `.env.example` (committed, secrets blank), `.env.local` is git-ignored. Do not put empty values in `.env`: once it
  is loaded an empty `SSL_MODE=` replaces a default
- `scripts/e2e_generated_app.sh` unsets the secrets and asserts the app boots from `.env` alone, keeps its CSRF key
  across a restart, and refuses to boot in production without `CSRF_SECRET`

## Delivery files of generated projects

- `azu new --docker` writes a multi-stage `Dockerfile` and `.dockerignore`; `--ci` (default `GitHub Actions`) writes
  `.github/workflows/ci.yml`. Both use `Generate::Project::CRYSTAL_VERSION` (also `.tool-versions`) and the package
  lists in `Generate::Project#build_packages` / `#runtime_packages`; change a Crystal version in one place
- Web and api apps `require "azu/dev"` (DevDashboard and PerformanceMonitor moved there; first release with it is azu 0.5.69, the generated shard.yml requires `~> 0.5.99`, the first release with `Azu::Env` (azu#163; it also contains the SQLite pragmas of azu#152, first in 0.5.93); `E2E_AZU_BRANCH=<ref>` pins the generated project's azu to a branch in the e2e scripts, opt-in)
- Development handlers (DevDashboard, PerformanceMonitor) are mounted by `def self.dev_handlers` in the generated app
  file, guarded by `Azu::CONFIG.env.development?` at runtime, never by the environment at generation time
- The generated app's `handlers` is `Array(HTTP::Handler)` (literal `of HTTP::Handler`): an array of a union of handler classes passed as `Array(HTTP::Handler)` is corrupted in optimized builds (IndexError / SIGSEGV at boot). `scripts/e2e_generated_app.sh` builds unoptimized, so only `scripts/e2e_docker.sh` (a `--release` build) catches this class of bug
- The app requires `./db/schema` only: `src/db/seed.cr` would run on every boot (`azu db:migrate` requires the migrations itself)
- The `Dockerfile` template starts with `FROM`, without a `# syntax=` line: that line makes BuildKit pull its frontend from the network

## Quality rules (from the PR reviews)

- Validate every name a generator turns into code (identifiers, paths); never interpolate raw input into generated Crystal
- No hard-coded secrets in generated code: read them with `Azu::Env.secret("NAME")` (the environment value, a random
  one outside production, an error in production; never a per-file copy of that guard) and list a random value in
  the git-ignored `.env`. Azu reads `CRYSTAL_ENV` only
- Escape template output (`| e`; Jinja `.jinja` files are not autoescaped); redirects after writes are 303
- Check what a generator would overwrite and refuse (`Auth.conflict`, duplicate migration class names)
- Specs must be able to fail: write the failing assertion first; do not claim a review that did not happen
- Do not document commands or flags that are not registered; `azu help` and `CLI_REFERENCE.md` list what exists

## End-to-end gates

`scripts/e2e_generated_app.sh [web|api]` generates a project with the built `azu` binary, installs its shards,
compiles it, boots it and drives it with curl (scaffold CRUD, a Chat channel with two WebSocket clients, session
authentication, CSRF and cookie checks). `E2E_DB=postgresql` only boots (no database server). CI runs it in a
`crystallang/crystal` container (see `.github/workflows/crystal.yaml`).

`scripts/e2e_docker.sh [web|api]` builds the generated `Dockerfile` with the host docker, runs the container, checks
`/health` and `/`, the production guards (no `CSRF_SECRET` / `SESSION_SECRET` means exit with an error), the non-root
user, the HEALTHCHECK and the `/data` volume. It needs a docker daemon, so CI does not run it.

Running them locally with Docker (no Crystal on the host):

```bash
docker run --rm -v "$PWD":/work -w /work crystallang/crystal:1.19.1 \
  sh -c 'apt-get update && apt-get install -y libreadline-dev libevent-dev libssl-dev libxml2-dev libyaml-dev libgmp-dev libsqlite3-dev sqlite3 curl \
         && shards install --ignore-crystal-version && shards build --ignore-crystal-version && scripts/e2e_generated_app.sh web'
scripts/e2e_docker.sh web      # on the host
```
