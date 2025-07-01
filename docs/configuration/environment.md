# Environment Variables

The Azu CLI supports configuration through environment variables, providing flexibility for different deployment environments and CI/CD pipelines.

## Overview

Environment variables allow you to:

- Configure the CLI without modifying files
- Set different configurations for different environments
- Integrate with CI/CD systems
- Override configuration files dynamically
- Set sensitive information securely

## Environment Variable Prefix

All Azu CLI environment variables use the `AZU_` prefix:

```bash
AZU_CONFIG_PATH=/path/to/config
AZU_LOG_LEVEL=debug
AZU_DATABASE_URL=postgresql://user:pass@localhost/db
```

## Core Configuration Variables

### Project Configuration

| Variable                  | Description                | Default                | Example               |
| ------------------------- | -------------------------- | ---------------------- | --------------------- |
| `AZU_CONFIG_PATH`         | Path to configuration file | `./azu.yml`            | `/etc/azu/config.yml` |
| `AZU_PROJECT_NAME`        | Default project name       | Current directory name | `my_awesome_app`      |
| `AZU_PROJECT_VERSION`     | Project version            | `0.1.0`                | `1.2.3`               |
| `AZU_PROJECT_DESCRIPTION` | Project description        | `Azu project`          | `My web application`  |

### Logging Configuration

| Variable         | Description           | Default  | Example                          |
| ---------------- | --------------------- | -------- | -------------------------------- |
| `AZU_LOG_LEVEL`  | Logging level         | `info`   | `debug`, `info`, `warn`, `error` |
| `AZU_LOG_FORMAT` | Log format            | `text`   | `text`, `json`                   |
| `AZU_LOG_FILE`   | Log file path         | `STDERR` | `/var/log/azu.log`               |
| `AZU_LOG_COLOR`  | Enable colored output | `true`   | `true`, `false`                  |

### Database Configuration

| Variable                 | Description                  | Default     | Example                               |
| ------------------------ | ---------------------------- | ----------- | ------------------------------------- |
| `AZU_DATABASE_URL`       | Database connection URL      | -           | `postgresql://user:pass@localhost/db` |
| `AZU_DATABASE_HOST`      | Database host                | `localhost` | `db.example.com`                      |
| `AZU_DATABASE_PORT`      | Database port                | `5432`      | `3306`                                |
| `AZU_DATABASE_NAME`      | Database name                | -           | `myapp_production`                    |
| `AZU_DATABASE_USER`      | Database username            | -           | `myapp_user`                          |
| `AZU_DATABASE_PASSWORD`  | Database password            | -           | `secret_password`                     |
| `AZU_DATABASE_POOL_SIZE` | Connection pool size         | `5`         | `10`                                  |
| `AZU_DATABASE_TIMEOUT`   | Connection timeout (seconds) | `5`         | `10`                                  |

### Development Server Configuration

| Variable              | Description          | Default     | Example             |
| --------------------- | -------------------- | ----------- | ------------------- |
| `AZU_SERVER_HOST`     | Server host          | `localhost` | `0.0.0.0`           |
| `AZU_SERVER_PORT`     | Server port          | `3000`      | `8080`              |
| `AZU_SERVER_WORKERS`  | Number of workers    | `1`         | `4`                 |
| `AZU_SERVER_RELOAD`   | Enable auto-reload   | `true`      | `true`, `false`     |
| `AZU_SERVER_SSL`      | Enable SSL           | `false`     | `true`, `false`     |
| `AZU_SERVER_SSL_CERT` | SSL certificate path | -           | `/path/to/cert.pem` |
| `AZU_SERVER_SSL_KEY`  | SSL private key path | -           | `/path/to/key.pem`  |

## Generator-Specific Variables

### Endpoint Generator

| Variable                       | Description            | Default                                     | Example                            |
| ------------------------------ | ---------------------- | ------------------------------------------- | ---------------------------------- |
| `AZU_ENDPOINT_METHODS`         | Default HTTP methods   | `index,show,new,create,edit,update,destroy` | `index,show,create,update,destroy` |
| `AZU_ENDPOINT_ROUTE_PREFIX`    | Route prefix           | `/`                                         | `/api/v1`                          |
| `AZU_ENDPOINT_RESPONSE_FORMAT` | Response format        | `json`                                      | `json`, `html`, `both`             |
| `AZU_ENDPOINT_AUTH_REQUIRED`   | Require authentication | `false`                                     | `true`, `false`                    |
| `AZU_ENDPOINT_AUTH_TYPE`       | Authentication type    | `session`                                   | `session`, `token`, `oauth`        |

### Model Generator

| Variable                   | Description              | Default      | Example                   |
| -------------------------- | ------------------------ | ------------ | ------------------------- |
| `AZU_MODEL_ORM`            | ORM framework            | `cql`        | `cql`, `jennifer`         |
| `AZU_MODEL_TABLE_NAMING`   | Table naming convention  | `snake_case` | `snake_case`, `camelCase` |
| `AZU_MODEL_MIGRATION_AUTO` | Auto-generate migrations | `true`       | `true`, `false`           |
| `AZU_MODEL_TIMESTAMPS`     | Include timestamps       | `true`       | `true`, `false`           |
| `AZU_MODEL_SOFT_DELETES`   | Include soft deletes     | `false`      | `true`, `false`           |

### Service Generator

| Variable                     | Description             | Default                           | Example                         |
| ---------------------------- | ----------------------- | --------------------------------- | ------------------------------- |
| `AZU_SERVICE_METHODS`        | Default service methods | `create,update,destroy,find,list` | `create,update,destroy`         |
| `AZU_SERVICE_ERROR_HANDLING` | Error handling approach | `exceptions`                      | `exceptions`, `results`, `both` |
| `AZU_SERVICE_TRANSACTIONS`   | Enable transactions     | `true`                            | `true`, `false`                 |
| `AZU_SERVICE_INTERFACE`      | Generate interfaces     | `true`                            | `true`, `false`                 |

### Page Generator

| Variable                   | Description            | Default     | Example                 |
| -------------------------- | ---------------------- | ----------- | ----------------------- |
| `AZU_PAGE_TEMPLATE_ENGINE` | Template engine        | `jinja`     | `jinja`, `ecr`          |
| `AZU_PAGE_CSS_FRAMEWORK`   | CSS framework          | `bootstrap` | `bootstrap`, `tailwind` |
| `AZU_PAGE_JS_FRAMEWORK`    | JavaScript framework   | `vanilla`   | `vanilla`, `alpine`     |
| `AZU_PAGE_CSRF_PROTECTION` | Enable CSRF protection | `true`      | `true`, `false`         |

## Environment-Specific Configuration

### Development Environment

```bash
# Development environment variables
export AZU_LOG_LEVEL=debug
export AZU_SERVER_RELOAD=true
export AZU_DATABASE_URL=postgresql://localhost/myapp_dev
export AZU_ENDPOINT_AUTH_REQUIRED=false
export AZU_MODEL_MIGRATION_AUTO=true
```

### Production Environment

```bash
# Production environment variables
export AZU_LOG_LEVEL=warn
export AZU_SERVER_RELOAD=false
export AZU_SERVER_WORKERS=4
export AZU_DATABASE_URL=postgresql://user:pass@prod-db/myapp_prod
export AZU_ENDPOINT_AUTH_REQUIRED=true
export AZU_MODEL_MIGRATION_AUTO=false
```

### Testing Environment

```bash
# Testing environment variables
export AZU_LOG_LEVEL=error
export AZU_DATABASE_URL=postgresql://localhost/myapp_test
export AZU_ENDPOINT_AUTH_REQUIRED=false
export AZU_MODEL_MIGRATION_AUTO=true
export AZU_SERVER_RELOAD=false
```

## Configuration Precedence

Environment variables follow this precedence order (highest to lowest):

1. **Command-line arguments** (highest priority)
2. **Environment variables**
3. **Configuration file** (`azu.yml`)
4. **Default values** (lowest priority)

## Setting Environment Variables

### Unix/Linux/macOS

```bash
# Set for current session
export AZU_LOG_LEVEL=debug
export AZU_DATABASE_URL=postgresql://localhost/myapp

# Set for specific command
AZU_LOG_LEVEL=debug azu generate endpoint users

# Load from file
source .env
```

### Windows (Command Prompt)

```cmd
# Set for current session
set AZU_LOG_LEVEL=debug
set AZU_DATABASE_URL=postgresql://localhost/myapp

# Set for specific command
set AZU_LOG_LEVEL=debug && azu generate endpoint users
```

### Windows (PowerShell)

```powershell
# Set for current session
$env:AZU_LOG_LEVEL = "debug"
$env:AZU_DATABASE_URL = "postgresql://localhost/myapp"

# Set for specific command
$env:AZU_LOG_LEVEL = "debug"; azu generate endpoint users
```

## Environment Files

### .env File

Create a `.env` file in your project root:

```bash
# .env
AZU_LOG_LEVEL=debug
AZU_DATABASE_URL=postgresql://localhost/myapp_dev
AZU_SERVER_PORT=3000
AZU_ENDPOINT_AUTH_REQUIRED=false
```

Load it in your shell:

```bash
# Load .env file
source .env

# Or use a tool like dotenv
dotenv azu generate endpoint users
```

### Multiple Environment Files

Create environment-specific files:

```bash
# .env.development
AZU_LOG_LEVEL=debug
AZU_DATABASE_URL=postgresql://localhost/myapp_dev
AZU_SERVER_RELOAD=true

# .env.production
AZU_LOG_LEVEL=warn
AZU_DATABASE_URL=postgresql://user:pass@prod-db/myapp_prod
AZU_SERVER_RELOAD=false
AZU_SERVER_WORKERS=4

# .env.test
AZU_LOG_LEVEL=error
AZU_DATABASE_URL=postgresql://localhost/myapp_test
AZU_SERVER_RELOAD=false
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/deploy.yml
name: Deploy
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Crystal
        uses: crystal-lang/install-crystal@v1

      - name: Deploy
        env:
          AZU_DATABASE_URL: ${{ secrets.DATABASE_URL }}
          AZU_LOG_LEVEL: warn
          AZU_SERVER_HOST: 0.0.0.0
          AZU_SERVER_PORT: 8080
        run: |
          azu db migrate
          azu serve
```

### Docker

```dockerfile
# Dockerfile
FROM crystallang/crystal:latest

WORKDIR /app
COPY . .

RUN shards install
RUN crystal build --release src/main.cr

ENV AZU_LOG_LEVEL=warn
ENV AZU_SERVER_HOST=0.0.0.0
ENV AZU_SERVER_PORT=8080

EXPOSE 8080
CMD ["./main"]
```

```yaml
# docker-compose.yml
version: "3.8"
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      - AZU_DATABASE_URL=postgresql://postgres:password@db/myapp
      - AZU_LOG_LEVEL=info
    depends_on:
      - db

  db:
    image: postgres:13
    environment:
      - POSTGRES_DB=myapp
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=password
```

## Security Considerations

### Sensitive Information

Never commit sensitive environment variables to version control:

```bash
# ❌ Don't do this
export AZU_DATABASE_PASSWORD=secret123

# ✅ Use secrets management
export AZU_DATABASE_PASSWORD=$DATABASE_PASSWORD_SECRET
```

### Environment Variable Validation

The CLI validates environment variables:

```bash
# Validate environment configuration
azu config validate --env

# Check specific variable
azu config validate --env AZU_DATABASE_URL
```

## Troubleshooting

### Common Issues

**Variable not recognized**: Ensure the variable name starts with `AZU_` and is properly formatted.

**Value not applied**: Check the configuration precedence order and ensure no higher-priority settings override it.

**Special characters**: Escape special characters in values:

```bash
# Escape special characters
export AZU_DATABASE_URL="postgresql://user:pass@localhost/db?sslmode=require"
```

### Debugging

Enable debug mode to see which environment variables are being used:

```bash
# Enable debug logging
export AZU_LOG_LEVEL=debug

# Run command to see configuration
azu config show --env
```

### Environment Variable Reference

View all available environment variables:

```bash
# List all environment variables
azu config env --list

# Show current values
azu config env --show
```

## Best Practices

1. **Use .env files** for local development
2. **Never commit secrets** to version control
3. **Use environment-specific files** for different deployment stages
4. **Validate configuration** before deployment
5. **Document required variables** in your project README
6. **Use descriptive names** for custom variables
7. **Set sensible defaults** in your configuration files
8. **Test configuration** in all environments
