# CLI Options Reference

This document provides a comprehensive reference for all Azu CLI commands, options, and flags.

## Command Structure

All Azu CLI commands follow this structure:

```bash
azu <command> [subcommand] [options] [arguments]
```

## Global Options

These options are available for all commands:

| Option        | Short | Description                   | Example                     |
| ------------- | ----- | ----------------------------- | --------------------------- |
| `--help`      | `-h`  | Show help for the command     | `azu --help`                |
| `--version`   | `-v`  | Show version information      | `azu --version`             |
| `--verbose`   | `-V`  | Enable verbose output         | `azu generate --verbose`    |
| `--quiet`     | `-q`  | Suppress output except errors | `azu serve --quiet`         |
| `--config`    | `-c`  | Specify configuration file    | `azu --config=./custom.yml` |
| `--log-level` | `-l`  | Set log level                 | `azu --log-level=debug`     |
| `--color`     |       | Enable/disable colored output | `azu --color=false`         |

## Project Commands

### `azu new`

Create a new Azu project.

```bash
azu new <project_name> [options]
```

| Option          | Description                             | Default          | Example                     |
| --------------- | --------------------------------------- | ---------------- | --------------------------- |
| `--type TYPE`   | Project type (web, api, cli)            | `web`            | `--type api`                |
| `--api`         | Shorthand for --type api                | -                | `--api`                     |
| `--db DATABASE` | Database adapter                        | `postgresql`     | `--db mysql`                |
| `--module NAME` | Module name (PascalCase)                | (from project)   | `--module MyApp`            |
| `--author NAME` | Author name                             | (from git)       | `--author "John Doe"`       |
| `--email EMAIL` | Author email                            | (from git)       | `--email john@example.com`  |
| `--license LIC` | License (MIT, Apache-2.0, etc.)         | `MIT`            | `--license Apache-2.0`      |
| `--ci CI`       | CI setup                                | `GitHub Actions` | `--ci "GitLab CI"`          |
| `--docker`      | Include Docker support                  | `false`          | `--docker`                  |
| `--no-docker`   | Skip Docker support                     | -                | `--no-docker`               |
| `--git`         | Initialize Git repository               | `true`           | `--git`                     |
| `--no-git`      | Skip Git initialization                 | -                | `--no-git`                  |
| `--example`     | Include example code                    | `true`           | `--example`                 |
| `--no-example`  | Skip example code                       | -                | `--no-example`              |
| `--joobq`       | Include JoobQ for background jobs       | `true`           | `--joobq`                   |
| `--no-joobq`    | Skip JoobQ integration                  | -                | `--no-joobq`                |
| `--yes`         | Non-interactive mode (use defaults)     | `false`          | `--yes`                     |

**Examples:**

```bash
# Create basic web project (interactive)
azu new myapp

# Create API project with MySQL (non-interactive)
azu new myapi --type api --db mysql --yes

# Create CLI project without Docker or Git
azu new mytool --type cli --no-docker --no-git --yes
```

### `azu init`

Initialize Azu in an existing project.

```bash
azu init [options]
```

| Option        | Description               | Default      | Example            |
| ------------- | ------------------------- | ------------ | ------------------ |
| `--framework` | Framework to use          | `azu`        | `--framework=azu`  |
| `--orm`       | ORM to use                | `cql`        | `--orm=cql`        |
| `--database`  | Database adapter          | `postgresql` | `--database=mysql` |
| `--force`     | Overwrite existing config | `false`      | `--force`          |

**Examples:**

```bash
# Initialize with defaults
azu init

# Initialize with specific ORM
azu init --orm=cql --database=postgresql
```

## Generation Commands

### `azu generate`

Generate code components.

```bash
azu generate <generator> <name> [options]
```

#### Common Generator Options

| Option         | Description              | Default           | Example              |
| -------------- | ------------------------ | ----------------- | -------------------- |
| `--force`      | Overwrite existing files | `false`           | `--force`            |
| `--skip-tests` | Skip test generation     | `false`           | `--skip-tests`       |
| `--api-only`   | Generate API components  | `false`           | `--api-only`         |
| `--web-only`   | Generate web components  | `false`           | `--web-only`         |
| `--skip COMP`  | Skip specific components | None              | `--skip model,page`  |

#### Endpoint Generator

```bash
azu generate endpoint <name> [options]
```

| Option              | Description              | Default                                     | Example                       |
| ------------------- | ------------------------ | ------------------------------------------- | ----------------------------- |
| `--methods`         | HTTP methods to generate | `index,show,new,create,edit,update,destroy` | `--methods=index,show,create` |
| `--route-prefix`    | Route prefix             | `/`                                         | `--route-prefix=/api/v1`      |
| `--response-format` | Response format          | `json`                                      | `--response-format=html`      |
| `--auth`            | Require authentication   | `false`                                     | `--auth`                      |
| `--authorization`   | Add authorization        | `false`                                     | `--authorization`             |
| `--contract`        | Generate contracts       | `true`                                      | `--skip-contract`             |
| `--page`            | Generate pages           | `false`                                     | `--page`                      |

**Examples:**

```bash
# Generate basic endpoint
azu generate endpoint users

# Generate API endpoint
azu generate endpoint users --methods=index,show,create,update,destroy --response-format=json

# Generate with authentication
azu generate endpoint users --auth --authorization
```

#### Model Generator

```bash
azu generate model <name> [fields] [options]
```

| Option           | Description           | Default | Example              |
| ---------------- | --------------------- | ------- | -------------------- |
| `--orm`          | ORM framework         | `cql`   | `--orm=cql`          |
| `--migration`    | Generate migration    | `true`  | `--skip-migration`   |
| `--timestamps`   | Include timestamps    | `true`  | `--skip-timestamps`  |
| `--soft-deletes` | Include soft deletes  | `false` | `--soft-deletes`     |
| `--validations`  | Add validations       | `true`  | `--skip-validations` |
| `--associations` | Generate associations | `false` | `--associations`     |

**Field Types:**

- `string` - String field (String)
- `text` - Text field (String)
- `int32` - 32-bit integer (Int32)
- `int64` - 64-bit integer (Int64)
- `float32` - 32-bit float (Float32)
- `float64` - 64-bit float (Float64)
- `bool`, `boolean` - Boolean field (Bool)
- `time`, `datetime` - DateTime field (Time)
- `date` - Date field (Date)
- `json` - JSON field (JSON::Any)
- `uuid` - UUID field (UUID)
- `email` - Email field (String with validation)
- `url` - URL field (String with validation)
- `references`, `belongs_to` - Foreign key reference (Int64)

**Examples:**

```bash
# Generate basic model
azu generate model User email:string name:string

# Generate model with associations
azu generate model Post title:string content:text user:belongs_to

# Generate model with custom options
azu generate model Product name:string price:decimal --soft-deletes --validations
```

#### Service Generator

```bash
azu generate service <name> [options]
```

| Option                   | Description              | Default                           | Example                    |
| ------------------------ | ------------------------ | --------------------------------- | -------------------------- |
| `--methods`              | Service methods          | `create,update,destroy,find,list` | `--methods=create,update`  |
| `--interface`            | Generate interface       | `true`                            | `--skip-interface`         |
| `--transactions`         | Include transactions     | `true`                            | `--skip-transactions`      |
| `--error-handling`       | Error handling approach  | `exceptions`                      | `--error-handling=results` |
| `--dependency-injection` | Use dependency injection | `true`                            | `--skip-di`                |

**Examples:**

```bash
# Generate basic service
azu generate service UserService

# Generate service with custom methods
azu generate service PaymentService --methods=process,refund,cancel
```

#### Page Generator

```bash
azu generate page <name> [options]
```

| Option              | Description          | Default     | Example                    |
| ------------------- | -------------------- | ----------- | -------------------------- |
| `--template-engine` | Template engine      | `jinja`     | `--template-engine=ecr`    |
| `--layout`          | Layout template      | `layout`    | `--layout=admin`           |
| `--css-framework`   | CSS framework        | `bootstrap` | `--css-framework=tailwind` |
| `--js-framework`    | JavaScript framework | `vanilla`   | `--js-framework=alpine`    |
| `--forms`           | Include forms        | `true`      | `--skip-forms`             |
| `--pagination`      | Include pagination   | `false`     | `--pagination`             |

**Examples:**

```bash
# Generate basic page
azu generate page users/index

# Generate page with custom template engine
azu generate page users/show --template-engine=ecr --css-framework=tailwind
```

#### Contract Generator

```bash
azu generate contract <name> [options]
```

| Option          | Description          | Default   | Example                             |
| --------------- | -------------------- | --------- | ----------------------------------- |
| `--fields`      | Contract fields      | None      | `--fields=email:string,name:string` |
| `--validations` | Add validations      | `true`    | `--skip-validations`                |
| `--framework`   | Validation framework | `crystal` | `--framework=custom`                |

**Examples:**

```bash
# Generate basic contract
azu generate contract CreateUser

# Generate contract with fields
azu generate contract UpdateUser --fields=email:string,name:string,age:integer
```

#### Component Generator

```bash
azu generate component <name> [options]
```

| Option              | Description     | Default     | Example                    |
| ------------------- | --------------- | ----------- | -------------------------- |
| `--type`            | Component type  | `ui`        | `--type=form`              |
| `--template-engine` | Template engine | `jinja`     | `--template-engine=ecr`    |
| `--css-framework`   | CSS framework   | `bootstrap` | `--css-framework=tailwind` |
| `--props`           | Include props   | `true`      | `--skip-props`             |
| `--slots`           | Include slots   | `false`     | `--slots`                  |
| `--events`          | Include events  | `false`     | `--events`                 |

**Examples:**

```bash
# Generate basic component
azu generate component UserCard

# Generate form component
azu generate component UserForm --type=form --props --events
```

#### Middleware Generator

```bash
azu generate middleware <name> [options]
```

| Option     | Description           | Default  | Example                 |
| ---------- | --------------------- | -------- | ----------------------- |
| `--type`   | Middleware type       | `custom` | `--type=authentication` |
| `--before` | Execute before        | None     | `--before=auth`         |
| `--after`  | Execute after         | None     | `--after=logging`       |
| `--config` | Include configuration | `true`   | `--skip-config`         |

**Examples:**

```bash
# Generate basic middleware
azu generate middleware RateLimiting

# Generate authentication middleware
azu generate middleware AuthMiddleware --type=authentication --before=auth
```

#### Migration Generator

```bash
azu generate migration <name> [options]
```

| Option         | Description               | Default            | Example                             |
| -------------- | ------------------------- | ------------------ | ----------------------------------- |
| `--table`      | Table name                | Inferred from name | `--table=users`                     |
| `--fields`     | Migration fields          | None               | `--fields=email:string,name:string` |
| `--reversible` | Make migration reversible | `true`             | `--skip-reversible`                 |

**Examples:**

```bash
# Generate basic migration
azu generate migration create_users

# Generate migration with fields
azu generate migration add_fields_to_users --fields=email:string,name:string
```

#### Scaffold Generator

```bash
azu generate scaffold <name> [fields] [options]
```

| Option            | Description              | Default | Example           |
| ----------------- | ------------------------ | ------- | ----------------- |
| `--skip-model`    | Skip model generation    | `false` | `--skip-model`    |
| `--skip-endpoint` | Skip endpoint generation | `false` | `--skip-endpoint` |
| `--skip-page`     | Skip page generation     | `false` | `--skip-page`     |
| `--skip-contract` | Skip contract generation | `false` | `--skip-contract` |
| `--skip-service`  | Skip service generation  | `false` | `--skip-service`  |

**Examples:**

```bash
# Generate full scaffold
azu generate scaffold User email:string name:string

# Generate scaffold without pages
azu generate scaffold Product name:string price:decimal --skip-page
```

## Database Commands

### `azu db`

Database management commands.

```bash
azu db <subcommand> [options]
```

#### `azu db create`

Create database.

```bash
azu db create [options]
```

| Option      | Description      | Default     | Example                              |
| ----------- | ---------------- | ----------- | ------------------------------------ |
| `--adapter` | Database adapter | From config | `--adapter=postgresql`               |
| `--url`     | Database URL     | From config | `--url=postgresql://localhost/myapp` |
| `--force`   | Force creation   | `false`     | `--force`                            |

#### `azu db drop`

Drop database.

```bash
azu db drop [options]
```

| Option      | Description      | Default     | Example                              |
| ----------- | ---------------- | ----------- | ------------------------------------ |
| `--adapter` | Database adapter | From config | `--adapter=postgresql`               |
| `--url`     | Database URL     | From config | `--url=postgresql://localhost/myapp` |
| `--force`   | Force drop       | `false`     | `--force`                            |

#### `azu db migrate`

Run database migrations.

```bash
azu db migrate [options]
```

| Option      | Description            | Default     | Example                    |
| ----------- | ---------------------- | ----------- | -------------------------- |
| `--version` | Target version         | Latest      | `--version=20231201000000` |
| `--adapter` | Database adapter       | From config | `--adapter=postgresql`     |
| `--dry-run` | Show what would be run | `false`     | `--dry-run`                |
| `--verbose` | Show detailed output   | `false`     | `--verbose`                |

#### `azu db rollback`

Rollback database migrations.

```bash
azu db rollback [options]
```

| Option      | Description            | Default     | Example                    |
| ----------- | ---------------------- | ----------- | -------------------------- |
| `--version` | Target version         | Previous    | `--version=20231101000000` |
| `--steps`   | Number of steps        | `1`         | `--steps=3`                |
| `--adapter` | Database adapter       | From config | `--adapter=postgresql`     |
| `--dry-run` | Show what would be run | `false`     | `--dry-run`                |

#### `azu db seed`

Seed database with data.

```bash
azu db seed [options]
```

| Option      | Description      | Default     | Example                |
| ----------- | ---------------- | ----------- | ---------------------- |
| `--file`    | Seed file        | `seed.cr`   | `--file=users.cr`      |
| `--adapter` | Database adapter | From config | `--adapter=postgresql` |
| `--force`   | Force seeding    | `false`     | `--force`              |

#### `azu db reset`

Reset database (drop, create, migrate, seed).

```bash
azu db reset [options]
```

| Option        | Description      | Default     | Example                |
| ------------- | ---------------- | ----------- | ---------------------- |
| `--adapter`   | Database adapter | From config | `--adapter=postgresql` |
| `--skip-seed` | Skip seeding     | `false`     | `--skip-seed`          |
| `--force`     | Force reset      | `false`     | `--force`              |

#### `azu db status`

Show migration status.

```bash
azu db status [options]
```

| Option      | Description      | Default     | Example                |
| ----------- | ---------------- | ----------- | ---------------------- |
| `--adapter` | Database adapter | From config | `--adapter=postgresql` |
| `--format`  | Output format    | `table`     | `--format=json`        |

#### `azu db new_migration`

Generate new migration.

```bash
azu db new_migration <name> [options]
```

| Option         | Description               | Default            | Example                             |
| -------------- | ------------------------- | ------------------ | ----------------------------------- |
| `--table`      | Table name                | Inferred from name | `--table=users`                     |
| `--fields`     | Migration fields          | None               | `--fields=email:string,name:string` |
| `--reversible` | Make migration reversible | `true`             | `--skip-reversible`                 |

## Development Commands

### `azu serve`

Start development server.

```bash
azu serve [options]
```

| Option       | Description       | Default       | Example                            |
| ------------ | ----------------- | ------------- | ---------------------------------- |
| `--host`     | Server host       | `localhost`   | `--host=0.0.0.0`                   |
| `--port`     | Server port       | `4000`        | `--port=8080`                      |
| `--workers`  | Number of workers | `1`           | `--workers=4`                      |
| `--reload`   | Enable hot reload | `false`       | `--reload`                         |
| `--watch`    | Watch directories | `src/`        | `--watch=src/endpoints,src/models` |
| `--ssl`      | Enable SSL        | `false`       | `--ssl`                            |
| `--ssl-cert` | SSL certificate   | None          | `--ssl-cert=cert.pem`              |
| `--ssl-key`  | SSL private key   | None          | `--ssl-key=key.pem`                |
| `--env`      | Environment       | `development` | `--env=production`                 |

**Examples:**

```bash
# Start basic server
azu serve

# Start with hot reload
azu serve --reload --port=8080

# Start with SSL
azu serve --ssl --ssl-cert=cert.pem --ssl-key=key.pem
```

### `azu dev`

Development workflow commands.

```bash
azu dev <subcommand> [options]
```

#### `azu dev console`

Start interactive console.

```bash
azu dev console [options]
```

| Option   | Description         | Default       | Example                  |
| -------- | ------------------- | ------------- | ------------------------ |
| `--env`  | Environment         | `development` | `--env=test`             |
| `--load` | Load specific files | None          | `--load=src/models/*.cr` |

#### `azu dev test`

Run tests.

```bash
azu dev test [options]
```

| Option        | Description           | Default             | Example                   |
| ------------- | --------------------- | ------------------- | ------------------------- |
| `--framework` | Test framework        | `spec`              | `--framework=minitest`    |
| `--pattern`   | Test pattern          | `spec/**/*_spec.cr` | `--pattern=spec/models/*` |
| `--parallel`  | Run tests in parallel | `false`             | `--parallel`              |
| `--coverage`  | Generate coverage     | `false`             | `--coverage`              |
| `--verbose`   | Verbose output        | `false`             | `--verbose`               |

#### `azu dev lint`

Run linter.

```bash
azu dev lint [options]
```

| Option     | Description     | Default   | Example                     |
| ---------- | --------------- | --------- | --------------------------- |
| `--tool`   | Linting tool    | `ameba`   | `--tool=crystal`            |
| `--rules`  | Specific rules  | All rules | `--rules=Style,Performance` |
| `--fix`    | Auto-fix issues | `false`   | `--fix`                     |
| `--format` | Output format   | `text`    | `--format=json`             |

#### `azu dev format`

Format code.

```bash
azu dev format [options]
```

| Option    | Description    | Default           | Example                      |
| --------- | -------------- | ----------------- | ---------------------------- |
| `--check` | Check only     | `false`           | `--check`                    |
| `--files` | Specific files | All Crystal files | `--files=src/endpoints/*.cr` |

## Configuration Commands

### `azu config`

Configuration management.

```bash
azu config <subcommand> [options]
```

#### `azu config show`

Show current configuration.

```bash
azu config show [options]
```

| Option      | Description      | Default | Example              |
| ----------- | ---------------- | ------- | -------------------- |
| `--format`  | Output format    | `yaml`  | `--format=json`      |
| `--env`     | Environment      | Current | `--env=production`   |
| `--section` | Specific section | All     | `--section=database` |

#### `azu config validate`

Validate configuration.

```bash
azu config validate [options]
```

| Option     | Description       | Default | Example            |
| ---------- | ----------------- | ------- | ------------------ |
| `--env`    | Environment       | Current | `--env=production` |
| `--strict` | Strict validation | `false` | `--strict`         |

#### `azu config env`

Environment variable management.

```bash
azu config env [options]
```

| Option    | Description         | Default | Example                     |
| --------- | ------------------- | ------- | --------------------------- |
| `--list`  | List all variables  | `false` | `--list`                    |
| `--show`  | Show current values | `false` | `--show`                    |
| `--set`   | Set variable        | None    | `--set=AZU_LOG_LEVEL=debug` |
| `--unset` | Unset variable      | None    | `--unset=AZU_LOG_LEVEL`     |

## Utility Commands

### `azu help`

Show help information.

```bash
azu help [command]
```

### `azu version`

Show version information.

```bash
azu version [options]
```

| Option     | Description       | Default | Example         |
| ---------- | ----------------- | ------- | --------------- |
| `--format` | Output format     | `text`  | `--format=json` |
| `--check`  | Check for updates | `false` | `--check`       |

## Environment Variables

### Core Variables

| Variable          | Description             | Default       |
| ----------------- | ----------------------- | ------------- |
| `AZU_CONFIG_PATH` | Configuration file path | `./azu.yml`   |
| `AZU_LOG_LEVEL`   | Log level               | `info`        |
| `AZU_ENV`         | Environment             | `development` |

### Database Variables

| Variable                | Description             | Default     |
| ----------------------- | ----------------------- | ----------- |
| `AZU_DATABASE_URL`      | Database connection URL | None        |
| `AZU_DATABASE_HOST`     | Database host           | `localhost` |
| `AZU_DATABASE_PORT`     | Database port           | `5432`      |
| `AZU_DATABASE_NAME`     | Database name           | None        |
| `AZU_DATABASE_USER`     | Database username       | None        |
| `AZU_DATABASE_PASSWORD` | Database password       | None        |

### Server Variables

| Variable             | Description       | Default     |
| -------------------- | ----------------- | ----------- |
| `AZU_SERVER_HOST`    | Server host       | `localhost` |
| `AZU_SERVER_PORT`    | Server port       | `4000`      |
| `AZU_SERVER_WORKERS` | Number of workers | `1`         |
| `AZU_SERVER_RELOAD`  | Enable hot reload | `false`     |

## Exit Codes

| Code | Description                    |
| ---- | ------------------------------ |
| `0`  | Success (EXIT_SUCCESS)         |
| `1`  | General failure (EXIT_FAILURE) |
| `2`  | Invalid usage/arguments        |
| `3`  | Not found                      |

## Examples

### Complete Workflow

```bash
# Create new project
azu new myapp --framework=azu --orm=cql

# Generate scaffold
azu generate scaffold User email:string name:string

# Setup database
azu db create
azu db migrate
azu db seed

# Start development server
azu serve --reload --port=8080
```

### Advanced Generation

```bash
# Generate API endpoint with authentication
azu generate endpoint users \
  --methods=index,show,create,update,destroy \
  --response-format=json \
  --auth \
  --authorization

# Generate model with associations
azu generate model Post \
  title:string \
  content:text \
  user:belongs_to \
  --validations \
  --soft-deletes

# Generate service with custom methods
azu generate service PaymentService \
  --methods=process,refund,cancel \
  --interface \
  --transactions
```

### Database Management

```bash
# Create and setup database
azu db create
azu db migrate
azu db seed

# Check migration status
azu db status

# Rollback last migration
azu db rollback

# Reset database
azu db reset --skip-seed
```

### Development Workflow

```bash
# Run tests
azu dev test --parallel --coverage

# Run linter
azu dev lint --fix

# Format code
azu dev format

# Start console
azu dev console --env=development
```
