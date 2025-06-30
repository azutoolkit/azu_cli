# azu serve

The `azu serve` command starts the development server with hot reloading capabilities. This is the primary command for development, automatically recompiling and restarting your application when files change.

## Overview

```bash
azu serve [options]
```

## Basic Usage

### Start Development Server

```bash
# Start server on default port (3000)
azu serve

# Start on custom port
azu serve --port 4000

# Start with specific environment
azu serve --env development
```

### Development with Hot Reloading

```bash
# Start server with file watching
azu serve

# Output:
# 🚀 Starting Azu development server...
# 📦 Compiling application...
# ✅ Compilation successful!
# 🌐 Server running at: http://localhost:3000
# 🔥 Hot reloading enabled
# 👀 Watching for file changes...
#
# Press Ctrl+C to stop the server
```

## Command Options

| Option          | Description           | Default   |
| --------------- | --------------------- | --------- |
| `--port <port>` | Server port           | 3000      |
| `--host <host>` | Server host           | localhost |
| `--no-watch`    | Disable file watching | false     |
| `--verbose`     | Enable verbose output | false     |

## Development Server Features

### Hot Reloading

The development server automatically detects file changes and recompiles your application:

```bash
# Edit a file in src/
# The server automatically detects changes and recompiles

# Output when file changes:
# 👀 File changed: src/endpoints/users/index_endpoint.cr
# 📦 Recompiling...
# ✅ Recompilation successful!
# 🔄 Server restarted
```

**Watched File Patterns:**

- `src/**/*.cr` - Crystal source files
- `config/**/*.cr` - Configuration files
- `public/templates/**/*.jinja` - Jinja templates
- `public/templates/**/*.html` - HTML templates
- `public/assets/**/*.css` - CSS files
- `public/assets/**/*.js` - JavaScript files

### Error Reporting

The server provides detailed error information during development:

```bash
# When compilation fails:
# ❌ Compilation failed!
#
# Error in src/models/user.cr:15:5
#   undefined method 'validates' for User
#
# Did you mean 'validate'?
#
# validates :email, presence: true
#     ^
#
# 💡 Fix the error and save to recompile
```

### Environment Configuration

```bash
# Development environment (default)
azu serve --env development

# Production-like environment
azu serve --env staging

# Custom environment
azu serve --env custom
```

## Server Configuration

### Port and Host

```bash
# Default configuration
azu serve
# Server: http://localhost:3000

# Custom port
azu serve --port 8080
# Server: http://localhost:8080

# Bind to all interfaces
azu serve --host 0.0.0.0
# Server: http://0.0.0.0:3000

# Custom host and port
azu serve --host 192.168.1.100 --port 4000
# Server: http://192.168.1.100:4000
```

### Verbose Mode

```bash
# Enable verbose output for detailed logging
azu serve --verbose

# Output includes:
# - File change notifications
# - Build process details
# - Debug information
```

## File Watching

### Automatic File Detection

The server watches for changes in:

```
src/
├── *.cr                    # Crystal source files
├── endpoints/              # Endpoint files
├── models/                 # Model files
├── services/               # Service files
├── middleware/             # Middleware files
└── initializers/           # Initializer files

public/
├── assets/                 # Static assets
├── templates/              # Template files
└── *.css, *.js, *.html     # Static files
```

### Manual File Watching

```bash
# Watch specific directories
azu serve --watch src/,config/

# Disable file watching
azu serve --no-watch

# Watch with custom patterns
azu serve --watch "src/**/*.cr"
```

## Performance Options

### Worker Processes

```bash
# Single worker (default)
azu serve --workers 1

# Multiple workers for better performance
azu serve --workers 4

# Auto-detect CPU cores
azu serve --workers auto
```

### Memory and CPU Limits

```bash
# Set memory limit
azu serve --memory-limit 512MB

# Set CPU limit
azu serve --cpu-limit 2
```

## Environment-Specific Configuration

### Development Environment

```crystal
# config/environments/development.cr
Azu.configure do |config|
  config.debug = true
  config.log_level = :debug
  config.host = "localhost"
  config.port = 3000
  config.reload_templates = true
  config.cache_templates = false
end
```

### Production Environment

```crystal
# config/environments/production.cr
Azu.configure do |config|
  config.debug = false
  config.log_level = :info
  config.host = "0.0.0.0"
  config.port = ENV.fetch("PORT", "8080").to_i
  config.reload_templates = false
  config.cache_templates = true
end
```

## Examples

### Basic Development

```bash
# Start development server
azu serve

# Visit http://localhost:3000
# Make changes to files
# Server automatically recompiles and restarts
```

### Custom Configuration

```bash
# Development with custom settings
azu serve --port 4000 --host 0.0.0.0 --debug

# Production-like testing
azu serve --env staging --port 8080

# SSL development
azu serve --ssl --port 443
```

### Team Development

```bash
# Share server on network
azu serve --host 0.0.0.0 --port 3000

# Multiple developers can access:
# http://your-ip:3000
```

### Mobile Development

```bash
# Access from mobile devices
azu serve --host 0.0.0.0 --port 3000

# Find your IP address
ifconfig | grep "inet " | grep -v 127.0.0.1

# Access from mobile: http://your-ip:3000
```

## Troubleshooting

### Port Already in Use

```bash
# Check what's using the port
lsof -i :3000

# Kill the process
kill -9 <PID>

# Or use a different port
azu serve --port 4000
```

### Compilation Errors

```bash
# Check for syntax errors
crystal build src/main.cr

# Fix errors and save
# Server will automatically recompile
```

### File Watching Issues

```bash
# Check file permissions
ls -la src/

# Restart server
# Press Ctrl+C and run again
azu serve

# Disable file watching temporarily
azu serve --no-watch
```

### Memory Issues

```bash
# Increase memory limit
azu serve --memory-limit 1GB

# Check memory usage
ps aux | grep azu

# Restart server periodically
# Press Ctrl+C and run again
```

### SSL Certificate Issues

```bash
# Generate self-signed certificate
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Use custom certificate
azu serve --ssl --ssl-cert cert.pem --ssl-key key.pem
```

## Best Practices

### 1. Development Workflow

```bash
# Start server
azu serve

# In another terminal, run tests
crystal spec --watch

# Make changes to files
# Server automatically recompiles
# Tests automatically run
```

### 2. Environment Management

```bash
# Use different environments
azu serve --env development  # Default
azu serve --env staging      # Pre-production
azu serve --env test         # Testing
```

### 3. Performance Optimization

```bash
# For large applications
azu serve --workers 4 --memory-limit 1GB

# For simple applications
azu serve --workers 1 --memory-limit 256MB
```

### 4. Security

```bash
# Don't bind to 0.0.0.0 in production
# Use reverse proxy (nginx, etc.)

# For development sharing
azu serve --host 0.0.0.0 --port 3000
```

### 5. Monitoring

```bash
# Enable debug mode for development
azu serve --debug

# Monitor logs
tail -f log/development.log

# Check server status
curl http://localhost:3000/health
```

## Integration with Other Tools

### VS Code Integration

```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Azu Server",
      "type": "crystal",
      "request": "launch",
      "program": "${workspaceFolder}/src/main.cr",
      "args": ["serve", "--port", "3000"]
    }
  ]
}
```

### Docker Development

```dockerfile
# Dockerfile.dev
FROM crystallang/crystal:latest

WORKDIR /app
COPY . .

RUN shards install

EXPOSE 3000

CMD ["crystal", "run", "src/main.cr", "--", "serve", "--host", "0.0.0.0"]
```

```bash
# Run with Docker
docker build -f Dockerfile.dev -t my-app-dev .
docker run -p 3000:3000 -v $(pwd):/app my-app-dev
```

---

The `azu serve` command is essential for Azu development, providing a fast, reliable development server with hot reloading capabilities.

**Next Steps:**

- [Development Workflows](../workflows/README.md) - Learn development patterns
- [Database Commands](database.md) - Manage your database
- [Generate Command](generate.md) - Create new components
