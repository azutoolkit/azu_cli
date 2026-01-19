# Configuration Commands

The configuration commands help you manage and inspect your Azu CLI configuration.

## azu config:show

Display the current configuration settings.

### Usage

```bash
azu config:show [options]
```

### Options

| Option          | Description                  | Default  |
| --------------- | ---------------------------- | -------- |
| `--format, -f`  | Output format (yaml/json/table) | `yaml` |
| `--env, -e`     | Environment to show          | current  |
| `--section, -s` | Show specific section only   | all      |

### Sections

- `global` - Global CLI settings (debug mode, verbose, quiet)
- `project` - Project configuration (name, path, database adapter)
- `server` - Development server settings (host, port, watch)
- `database` - Database configuration (host, port, user, name)
- `paths` - File paths (templates, output)
- `logging` - Logging configuration (level, format)

### Examples

```bash
# Show all configuration in YAML format
azu config:show

# Show configuration in JSON format
azu config:show --format json

# Show only database configuration
azu config:show --section database

# Show production environment configuration
azu config:show --env production
```

## azu config:validate

Validate your configuration files and settings.

### Usage

```bash
azu config:validate [options]
```

### Options

| Option        | Description                     | Default |
| ------------- | ------------------------------- | ------- |
| `--env, -e`   | Environment to validate         | current |
| `--strict`    | Treat warnings as errors        | `false` |
| `--config, -c`| Path to configuration file      | auto    |

### What Gets Validated

- Configuration file syntax (YAML)
- Project directory structure
- Database configuration (adapter, port range)
- Server configuration (port range, host)
- Path existence (templates, output)

### Examples

```bash
# Validate current configuration
azu config:validate

# Strict validation (warnings become errors)
azu config:validate --strict

# Validate production configuration
azu config:validate --env production

# Validate specific configuration file
azu config:validate --config ./custom-config.yml
```

## azu config:env

Manage environment variables used by Azu CLI.

### Usage

```bash
azu config:env [options]
```

### Options

| Option    | Description                     |
| --------- | ------------------------------- |
| `--list`  | List all known environment variables |
| `--show`  | Show current values             |
| `--set`   | Set a variable (VAR=VALUE)      |
| `--unset` | Remove a variable               |

### Environment Variables

| Variable          | Description                       |
| ----------------- | --------------------------------- |
| `AZU_ENV`         | Environment name                  |
| `AZU_DEBUG`       | Enable debug mode                 |
| `AZU_VERBOSE`     | Enable verbose output             |
| `AZU_QUIET`       | Suppress non-error output         |
| `AZU_HOST`        | Development server host           |
| `AZU_PORT`        | Development server port           |
| `AZU_DB_HOST`     | Database host                     |
| `AZU_DB_PORT`     | Database port                     |
| `AZU_DB_USER`     | Database user                     |
| `AZU_DB_PASSWORD` | Database password                 |
| `AZU_DB_NAME`     | Database name                     |
| `DATABASE_URL`    | Full database connection URL      |

### Examples

```bash
# List all environment variables
azu config:env --list

# Show current values
azu config:env --show

# Set a variable in .env file
azu config:env --set AZU_PORT=4000

# Set database URL
azu config:env --set DATABASE_URL=postgres://localhost/mydb

# Remove a variable
azu config:env --unset AZU_DEBUG
```

## Best Practices

### 1. Validate Before Deploying

Always validate your configuration before deploying to production:

```bash
azu config:validate --env production --strict
```

### 2. Use Environment Variables for Secrets

Never commit secrets to version control. Use environment variables:

```bash
azu config:env --set DATABASE_URL=postgres://user:pass@host/db
```

### 3. Review Configuration Regularly

Periodically review your configuration to ensure it's optimized:

```bash
azu config:show --format table
```

---

**See Also:**

- [Environment Variables](../configuration/environment.md) - Detailed environment configuration
- [Project Configuration](../configuration/project-config.md) - Project settings
- [Database Configuration](../configuration/database-config.md) - Database setup
