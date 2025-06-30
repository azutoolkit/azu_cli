# azu dev

The `azu dev` command provides an enhanced development environment with additional tools and features for productive development. It's an alternative to `azu serve` with extra development capabilities.

## Overview

```bash
azu dev [options]
```

## Basic Usage

### Start Development Environment

```bash
# Start development environment
azu dev

# Start with custom port
azu dev --port 4000

# Start with specific environment
azu dev --env development
```

### Development with Hot Reloading

```bash
# Start development server with enhanced features
azu dev

# Output:
# 🚀 Starting Azu development environment...
# 📦 Compiling application...
# ✅ Compilation successful!
# 🌐 Server running at: http://localhost:3000
# 🔥 Hot reloading enabled
# 👀 Watching for file changes...
# 📊 Development dashboard at: http://localhost:3000/dev
# 🧪 Test runner available
# 📝 Code formatter active
#
# Press Ctrl+C to stop the server
```

## Command Options

| Option                | Description                  | Default     |
| --------------------- | ---------------------------- | ----------- |
| `--port <port>`       | Server port                  | 3000        |
| `--host <host>`       | Server host                  | localhost   |
| `--env <environment>` | Environment name             | development |
| `--debug`             | Enable debug mode            | true        |
| `--dashboard`         | Enable development dashboard | true        |
| `--tests`             | Enable test runner           | true        |
| `--format`            | Enable code formatting       | true        |
| `--lint`              | Enable linting               | true        |
| `--coverage`          | Enable code coverage         | false       |
| `--workers <number>`  | Number of worker processes   | 1           |

## Development Features

### Development Dashboard

Access the development dashboard at `http://localhost:3000/dev`:

```bash
# Dashboard features:
# - Application status
# - Database information
# - Route listing
# - Performance metrics
# - Error logs
# - Test results
# - Code coverage
```

### Enhanced File Watching

```bash
# Watches additional file types
src/
├── *.cr                    # Crystal source files
├── endpoints/              # Endpoint files
├── models/                 # Model files
├── services/               # Service files
├── middleware/             # Middleware files
├── initializers/           # Initializer files
└── pages/                  # Page components

public/
├── assets/                 # Static assets
├── templates/              # Template files
└── *.css, *.js, *.html     # Static files

config/
├── *.yml                   # Configuration files
└── environments/           # Environment configs

spec/
├── *_spec.cr               # Test files
└── factories/              # Test factories
```

### Automatic Code Formatting

```bash
# Automatically format code on save
# Uses crystal tool format

# Format specific files
crystal tool format src/models/user.cr

# Format entire project
crystal tool format src/
```

### Linting and Code Quality

```bash
# Run Ameba linter automatically
# Checks for code quality issues

# Manual linting
ameba src/

# Fix auto-fixable issues
ameba --fix src/
```

### Test Runner Integration

```bash
# Run tests automatically on file changes
# Tests run in background

# Manual test execution
crystal spec

# Run specific test files
crystal spec spec/models/user_spec.cr

# Run with coverage
crystal spec --coverage
```

## Development Dashboard

### Dashboard Features

**Application Status:**

- Server uptime
- Memory usage
- CPU usage
- Request count
- Error rate

**Database Information:**

- Connection status
- Migration status
- Table count
- Query performance

**Route Listing:**

- All registered routes
- HTTP methods
- Endpoint classes
- Route parameters

**Performance Metrics:**

- Response times
- Throughput
- Memory allocation
- Garbage collection

**Error Logs:**

- Recent errors
- Stack traces
- Error frequency
- Error categories

**Test Results:**

- Test status
- Coverage reports
- Failed tests
- Test performance

### Accessing Dashboard

```bash
# Start development server
azu dev

# Access dashboard
# http://localhost:3000/dev

# Dashboard sections:
# /dev/status      - Application status
# /dev/database    - Database information
# /dev/routes      - Route listing
# /dev/performance - Performance metrics
# /dev/errors      - Error logs
# /dev/tests       - Test results
# /dev/coverage    - Code coverage
```

## Examples

### Basic Development

```bash
# Start development environment
azu dev

# Visit application
# http://localhost:3000

# Visit dashboard
# http://localhost:3000/dev
```

### Custom Configuration

```bash
# Development with custom settings
azu dev --port 4000 --host 0.0.0.0 --debug

# Development without dashboard
azu dev --dashboard=false

# Development with coverage
azu dev --coverage
```

### Team Development

```bash
# Share development server
azu dev --host 0.0.0.0 --port 3000

# Multiple developers can access:
# http://your-ip:3000
# http://your-ip:3000/dev
```

## Development Workflow

### 1. Start Development

```bash
# Start development environment
azu dev

# In another terminal, run additional tools
crystal spec --watch
ameba --watch src/
```

### 2. Make Changes

```bash
# Edit files in src/
# Changes are automatically detected

# Server recompiles and restarts
# Tests run automatically
# Code is formatted
# Linting runs
```

### 3. Monitor Progress

```bash
# Check dashboard for:
# - Compilation status
# - Test results
# - Performance metrics
# - Error logs

# Visit: http://localhost:3000/dev
```

### 4. Debug Issues

```bash
# Check error logs in dashboard
# http://localhost:3000/dev/errors

# Check test failures
# http://localhost:3000/dev/tests

# Check performance issues
# http://localhost:3000/dev/performance
```

## Advanced Features

### Code Coverage

```bash
# Enable coverage tracking
azu dev --coverage

# View coverage in dashboard
# http://localhost:3000/dev/coverage

# Coverage includes:
# - Line coverage
# - Branch coverage
# - Function coverage
# - File coverage
```

### Performance Profiling

```bash
# Enable performance profiling
azu dev --profile

# Profile information available in dashboard
# http://localhost:3000/dev/performance

# Profile data includes:
# - Request timing
# - Database queries
# - Memory usage
# - CPU usage
```

### Database Monitoring

```bash
# Database monitoring in dashboard
# http://localhost:3000/dev/database

# Database information includes:
# - Connection status
# - Migration status
# - Query count
# - Query timing
# - Table sizes
```

### Error Tracking

```bash
# Error tracking in dashboard
# http://localhost:3000/dev/errors

# Error information includes:
# - Error count
# - Error types
# - Stack traces
# - Error frequency
# - Error context
```

## Configuration

### Development Configuration

```crystal
# config/environments/development.cr
Azu.configure do |config|
  config.debug = true
  config.log_level = :debug
  config.host = "localhost"
  config.port = 3000

  # Development-specific settings
  config.development.dashboard = true
  config.development.auto_format = true
  config.development.auto_lint = true
  config.development.test_runner = true
  config.development.coverage = false
end
```

### Dashboard Configuration

```yaml
# azu.yml
development:
  dashboard:
    enabled: true
    port: 3000
    host: localhost
    auth: false
    metrics:
      enabled: true
      interval: 5s
    tests:
      enabled: true
      auto_run: true
    coverage:
      enabled: false
      threshold: 80
```

## Troubleshooting

### Dashboard Not Accessible

```bash
# Check if dashboard is enabled
azu dev --dashboard=true

# Check dashboard port
# Default: http://localhost:3000/dev

# Check firewall settings
# Ensure port is accessible
```

### Tests Not Running

```bash
# Check test configuration
azu dev --tests=true

# Run tests manually
crystal spec

# Check test files exist
ls -la spec/
```

### Code Formatting Issues

```bash
# Check Crystal installation
crystal --version

# Run formatter manually
crystal tool format src/

# Check for syntax errors
crystal build src/main.cr
```

### Performance Issues

```bash
# Reduce worker processes
azu dev --workers 1

# Disable features
azu dev --coverage=false --profile=false

# Check system resources
top
htop
```

## Best Practices

### 1. Development Workflow

```bash
# Use azu dev for development
azu dev

# Use azu serve for simple testing
azu serve

# Use production build for performance testing
crystal build src/main.cr --release
```

### 2. Dashboard Usage

```bash
# Monitor dashboard regularly
# http://localhost:3000/dev

# Check for:
# - Compilation errors
# - Test failures
# - Performance issues
# - Database problems
```

### 3. Code Quality

```bash
# Keep code formatted
# crystal tool format runs automatically

# Fix linting issues
# ameba runs automatically

# Maintain test coverage
# Tests run automatically
```

### 4. Performance Monitoring

```bash
# Monitor performance in dashboard
# http://localhost:3000/dev/performance

# Watch for:
# - Slow requests
# - High memory usage
# - Database bottlenecks
# - Error spikes
```

## Integration with IDEs

### VS Code Integration

```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Azu Dev",
      "type": "crystal",
      "request": "launch",
      "program": "${workspaceFolder}/src/main.cr",
      "args": ["dev", "--port", "3000"]
    }
  ]
}
```

### JetBrains Integration

```bash
# Run configuration
# Program: src/main.cr
# Arguments: dev --port 3000
# Working directory: project root
```

---

The `azu dev` command provides an enhanced development environment with dashboard, testing, formatting, and monitoring capabilities.

**Next Steps:**

- [Development Workflows](../workflows/README.md) - Learn development patterns
- [Testing Your Application](../workflows/testing.md) - Comprehensive testing
- [Database Commands](database.md) - Manage your database
