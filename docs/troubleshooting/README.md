# Troubleshooting Guide

This guide helps you resolve common issues you might encounter while using Azu CLI. If you can't find a solution here, please check the specific troubleshooting sections or reach out to the community.

## Quick Diagnosis

### Check Your Environment

```bash
# Check Crystal version
crystal --version

# Check Azu CLI version
azu version

# Check if you're in an Azu project
ls -la | grep shard.yml
```

### Common Error Patterns

| Error Pattern                       | Likely Cause                    | Solution                                   |
| ----------------------------------- | ------------------------------- | ------------------------------------------ |
| `command not found: azu`            | Azu CLI not installed           | [Installation Issues](installation.md)     |
| `Error: Database connection failed` | Database not running/configured | [Database Issues](database.md)             |
| `Error: Template not found`         | Missing template files          | [Generation Issues](generation.md)         |
| `Error: Port already in use`        | Another process using the port  | [Development Server Issues](dev-server.md) |
| `Error: Compilation failed`         | Crystal compilation errors      | [Build Issues](build.md)                   |

## Getting Help

### 1. Check the Logs

Enable verbose logging to get more detailed error information:

```bash
# Enable debug logging
export AZU_LOG_LEVEL=debug
azu serve

# Or use the verbose flag
azu serve --verbose
```

### 2. Search Existing Issues

Before reporting a new issue, search existing issues:

- [GitHub Issues](https://github.com/azutoolkit/azu_cli/issues)
- [Discord Community](https://discord.gg/azutoolkit)
- [Documentation](README.md)

### 3. Create a Minimal Reproduction

When reporting an issue, create a minimal reproduction:

```bash
# Create a minimal test case
azu new test-app
cd test-app
# Steps to reproduce the issue
```

### 4. Include System Information

When reporting issues, include:

```bash
# System information
crystal --version
azu version
uname -a
# Error messages and stack traces
```

## Common Solutions

### Reset Your Environment

If you're experiencing strange behavior, try resetting your environment:

```bash
# Clear Crystal cache
rm -rf ~/.cache/crystal

# Reinstall dependencies
shards install

# Reset database
azu db:reset
```

### Update Dependencies

Keep your dependencies up to date:

```bash
# Update Crystal
# Follow instructions at https://crystal-lang.org/install/

# Update Azu CLI
shards update

# Update project dependencies
shards update
```

### Check File Permissions

Ensure proper file permissions:

```bash
# Check file permissions
ls -la

# Fix permissions if needed
chmod +x bin/azu
chmod -R 755 src/
```

## Debugging Techniques

### 1. Enable Debug Mode

```bash
# Set debug environment variable
export AZU_DEBUG=true

# Or use debug flag
azu serve --debug
```

### 2. Check Configuration

```bash
# Validate configuration
azu config:validate

# Show current configuration
azu config:show
```

### 3. Test Individual Components

```bash
# Test database connection
azu db:test

# Test template rendering
azu generate model Test --dry-run

# Test file operations
azu generate model Test --verbose
```

### 4. Use Crystal's Debug Tools

```bash
# Check Crystal syntax
crystal tool hierarchy src/

# Format code
crystal tool format

# Check for issues
ameba
```

## Performance Issues

### Slow Startup

If Azu CLI is starting slowly:

```bash
# Check for large dependency trees
crystal deps tree

# Profile startup time
time azu version

# Check system resources
top
```

### Slow Generation

If code generation is slow:

```bash
# Use dry-run to test without file I/O
azu generate model Test --dry-run

# Check disk space
df -h

# Monitor file system
iostat
```

### Memory Issues

If you're experiencing memory issues:

```bash
# Check memory usage
free -h

# Monitor Crystal process
ps aux | grep crystal

# Use memory profiling
crystal run --stats src/main.cr
```

## Network Issues

### Proxy Configuration

If you're behind a proxy:

```bash
# Set proxy environment variables
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080

# Or configure in your shell profile
echo 'export HTTP_PROXY=http://proxy.example.com:8080' >> ~/.bashrc
```

### SSL/TLS Issues

If you're experiencing SSL/TLS issues:

```bash
# Check SSL certificates
openssl s_client -connect api.example.com:443

# Update CA certificates
# Follow your OS-specific instructions
```

## Platform-Specific Issues

### macOS

Common macOS issues:

```bash
# Fix Homebrew permissions
sudo chown -R $(whoami) /opt/homebrew

# Update Xcode command line tools
xcode-select --install

# Check for conflicting Crystal installations
which crystal
brew list | grep crystal
```

### Linux

Common Linux issues:

```bash
# Install required dependencies
sudo apt-get update
sudo apt-get install build-essential libssl-dev libreadline-dev

# Fix library path issues
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
```

### Windows

Common Windows issues:

```bash
# Use WSL2 for better compatibility
# Install Crystal through WSL2

# Or use Docker
docker run -it crystallang/crystal:latest
```

## Database Issues

### Connection Problems

```bash
# Test database connection
azu db:test

# Check database status
azu db:status

# Verify connection string
echo $DATABASE_URL
```

### Migration Issues

```bash
# Check migration status
azu db:migrate:status

# Reset migrations
azu db:rollback
azu db:migrate

# Check migration files
ls -la src/db/migrations/
```

## Development Server Issues

### Port Conflicts

```bash
# Check what's using the port
lsof -i :3000

# Kill the process
kill -9 <PID>

# Or use a different port
azu serve --port 3001
```

### Hot Reload Issues

```bash
# Disable hot reload temporarily
azu serve --no-reload

# Check file watching limits (Linux)
cat /proc/sys/fs/inotify/max_user_watches

# Increase limits if needed
echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf
```

## Build Issues

### Compilation Errors

```bash
# Check Crystal version compatibility
crystal --version

# Clean build artifacts
rm -rf .crystal/

# Rebuild from scratch
crystal build --release src/main.cr
```

### Dependency Issues

```bash
# Update shard.lock
rm shard.lock
shards install

# Check for conflicting dependencies
shards list

# Update specific dependency
shards update <dependency-name>
```

## Template Issues

### Missing Templates

```bash
# Check template installation
ls -la src/templates/

# Reinstall templates
azu templates:install

# Check template cache
rm -rf .azu/templates/
```

### Template Rendering Errors

```bash
# Validate template syntax
azu templates:validate

# Test template rendering
azu generate model Test --dry-run --verbose

# Check template variables
azu templates:variables
```

## Configuration Issues

### Invalid Configuration

```bash
# Validate configuration
azu config:validate

# Show configuration
azu config:show

# Reset to defaults
azu config:reset
```

### Environment Variables

```bash
# Check environment variables
env | grep AZU

# Set required variables
export AZU_ENV=development
export DATABASE_URL=postgresql://localhost/myapp_development
```

## Community Support

### Discord Community

Join the Azu Toolkit Discord for real-time help:

- [Discord Server](https://discord.gg/azutoolkit)
- Active community of developers
- Quick answers to common questions
- Share your projects and get feedback

### GitHub Issues

For bug reports and feature requests:

- [GitHub Issues](https://github.com/azutoolkit/azu_cli/issues)
- Search existing issues first
- Provide detailed reproduction steps
- Include system information

### Documentation

- [Official Documentation](README.md)
- [API Reference](reference/)
- [Examples](examples/README.md)
- [Best Practices](examples/README.md)

## Contributing to Troubleshooting

If you find a solution that's not documented:

1. **Update this guide** with your solution
2. **Share with the community** on Discord
3. **Submit a PR** to improve the documentation
4. **Help others** with similar issues

## Related Documentation

- [Installation Issues](installation.md) - Installation-specific problems
- [Generation Issues](generation.md) - Code generation problems
- [Database Issues](database.md) - Database-related problems
- [Development Server Issues](dev-server.md) - Server and development issues
- [Build Issues](build.md) - Compilation and build problems
