# CLI Framework (Topia)

Azu CLI is built on top of [Topia](https://github.com/azutoolkit/topia), a modern, high-performance task automation framework built with Crystal. Topia provides the foundation for command parsing, task execution, and the overall CLI architecture.

## Overview

Topia is a Crystal-powered task automation and build pipeline framework that transforms development workflows. It provides:

- **Code over Configuration** - Write workflows in pure Crystal, no complex config files
- **High Performance** - Built for speed with async operations, caching, and parallelism
- **Composable** - Chain tasks, plugins, and commands like building blocks
- **Type Safe** - Leverage Crystal's compile-time type checking for bulletproof workflows
- **Developer Friendly** - Professional CLI, interactive modes, and comprehensive debugging tools

## Core Components

### Task System

Topia's task system is the foundation of Azu CLI's command execution:

```crystal
# Simple command task
Topia.task("build")
  .describe("Build the application")
  .command("crystal build --release src/main.cr")

# Task with dependencies
Topia.task("test")
  .describe("Run tests")
  .depends_on("build")
  .command("crystal spec")

# Task with file watching
Topia.task("dev")
  .describe("Development server with hot reload")
  .src("./src/**/*.cr")
  .pipe(FileWatcher.new)
  .command("crystal run src/main.cr")
```

### Command Execution

Topia provides robust command execution with error handling and output management:

```crystal
class Azu::Commands::Base
  include Topia::Command

  def execute_command(command : String, args : Array(String) = [] of String)
    Topia::Command.execute(command, args) do |result|
      case result
      when .success?
        Azu::Logger.info("Command executed successfully")
      when .failure?
        Azu::Logger.error("Command failed: #{result.error}")
        raise CommandError.new("Command execution failed")
      end
    end
  end
end
```

### Plugin System

Topia's plugin system allows Azu CLI to extend functionality through composable plugins:

```crystal
# File processing plugin for code generation
class FileProcessor < Topia::BasePlugin
  def run(input, args)
    case input
    when Array(Topia::InputFile)
      announce "Processing #{input.size} files..."
      input.map { |file| process_file(file) }
    else
      error "Expected Array(InputFile), got #{input.class}"
      input
    end
  end

  private def process_file(file : Topia::InputFile)
    # Process file content
    file.contents = file.contents.gsub(/old/, "new")
    file
  end
end
```

## CLI Architecture

### Command Parsing

Topia provides automatic command-line argument parsing:

```crystal
# Azu CLI command structure
class Azu::CLI
  include Topia::CLI

  def initialize
    @parser = Topia::Parser.new do |parser|
      parser.banner = "Azu CLI - Crystal web framework command line tool"

      parser.on("new PROJECT_NAME", "Create a new Azu project") do |name|
        Azu::Commands::New.new(name).call
      end

      parser.on("generate TYPE NAME", "Generate code") do |type, name|
        Azu::Commands::Generate.new(type, name).call
      end

      parser.on("serve", "Start development server") do
        Azu::Commands::Serve.new.call
      end
    end
  end

  def run(args = ARGV)
    @parser.parse(args)
  end
end
```

### Subcommand Support

Topia enables hierarchical command structures:

```crystal
# Generate command with subcommands
class Azu::Commands::Generate < Azu::Commands::Base
  def call
    case @subcommand
    when "model"
      Azu::Generators::Model.new(@name, @options).generate
    when "endpoint"
      Azu::Generators::Endpoint.new(@name, @options).generate
    when "scaffold"
      Azu::Generators::Scaffold.new(@name, @options).generate
    else
      raise ArgumentError.new("Unknown generator type: #{@subcommand}")
    end
  end
end
```

## Performance Features

### Async Operations

Topia provides non-blocking operations for better performance:

```crystal
# Async file watching for development server
class Azu::Commands::Serve < Azu::Commands::Base
  def call
    Topia.task("serve")
      .src("./src/**/*.cr")
      .pipe(AsyncFileWatcher.new)
      .command("crystal run src/main.cr")
      .run
  end
end

class AsyncFileWatcher < Topia::BasePlugin
  def run(input, args)
    spawn do
      watch_files(input)
    end
    input
  end

  private def watch_files(files)
    # Non-blocking file watching
    files.each do |file|
      if file.modified?
        rebuild_application
      end
    end
  end
end
```

### Intelligent Caching

Topia provides automatic caching based on input file checksums and command signatures:

```crystal
# Cached task execution
Topia.task("expensive_build")
  .src("./src/**/*.cr")
  .pipe(SlowCompiler.new)
  .dist("./build/")
  .cache(true)  # Enable caching

# First run: Full execution
# Subsequent runs: Instant cache hits (if nothing changed)
```

### Parallel Execution

Topia supports concurrent task execution for improved performance:

```crystal
# Parallel test execution
Topia.task("test")
  .parallel(4)  # Run 4 tests in parallel
  .src("./spec/**/*_spec.cr")
  .pipe(TestRunner.new)
  .run
```

## Configuration Integration

### Environment Variable Support

Topia integrates with Azu CLI's configuration system:

```crystal
# Configuration-aware task execution
class Azu::Commands::Database < Azu::Commands::Base
  def call
    config = Azu::Config.current

    Topia.task("database_operation")
      .env({
        "DATABASE_URL" => config.database.url,
        "DB_HOST" => config.database.host,
        "DB_PORT" => config.database.port.to_s
      })
      .command("crystal run db/migrate.cr")
      .run
  end
end
```

### YAML Configuration

Topia supports YAML-based configuration:

```yaml
# topia.yml
tasks:
  build:
    command: "crystal build --release src/main.cr"
    description: "Build the application"

  test:
    command: "crystal spec"
    description: "Run tests"
    depends_on: ["build"]

  serve:
    command: "crystal run src/main.cr"
    description: "Start development server"
    watch: ["src/**/*.cr"]
```

## Debugging and Monitoring

### Enhanced Debugging

Topia provides comprehensive debugging capabilities:

```crystal
# Debug mode with detailed logging
Topia.debug = true

# CLI debugging options
./azu_cli -d task_name                    # Debug mode with detailed logging
./azu_cli --verbose --stats task_name     # Verbose output with performance stats
./azu_cli --profile task_name             # Performance profiling
./azu_cli --dependencies task_name        # Analyze task dependencies
./azu_cli --where task_name               # Find task source location
./azu_cli --dry-run task_name             # Preview execution without running
```

### Performance Metrics

Topia provides detailed performance insights:

```crystal
# Performance profiling
Topia.task("monitored")
  .describe("Task with rich monitoring")
  .command("long_running_process")
  .profile(true)  # Enable performance profiling

# Automatically tracks:
# - Execution time
# - Success/failure rates
# - Cache hits
# - Memory usage
# - CPU utilization
```

## Lifecycle Hooks

### Plugin Lifecycle

Topia provides lifecycle hooks for plugins:

```crystal
class Azu::Generators::Base < Topia::BasePlugin
  def on(event : String)
    case event
    when "pre_run"
      setup_environment
    when "after_run"
      cleanup_resources
    when "error"
      handle_error
    end
  end

  private def setup_environment
    Azu::Logger.info("Setting up generator environment")
    # Initialize generator state
  end

  private def cleanup_resources
    Azu::Logger.info("Cleaning up generator resources")
    # Clean up temporary files
  end

  private def handle_error
    Azu::Logger.error("Generator encountered an error")
    # Error recovery logic
  end
end
```

## Integration with Azu CLI

### Command Structure

Azu CLI uses Topia's command system for all CLI operations:

```crystal
# Main CLI entry point
class Azu::CLI
  include Topia::CLI

  def initialize
    setup_commands
    setup_middleware
  end

  private def setup_commands
    # Project management commands
    register_command("new", Azu::Commands::New)
    register_command("init", Azu::Commands::Init)

    # Code generation commands
    register_command("generate", Azu::Commands::Generate)

    # Database commands
    register_command("db", Azu::Commands::Database)

    # Development commands
    register_command("serve", Azu::Commands::Serve)
    register_command("dev", Azu::Commands::Dev)
  end

  private def setup_middleware
    # Add middleware for logging, error handling, etc.
    use(Azu::Middleware::Logging)
    use(Azu::Middleware::ErrorHandler)
  end
end
```

### Error Handling

Topia provides robust error handling for Azu CLI:

```crystal
class Azu::Middleware::ErrorHandler < Topia::Middleware
  def call(context : Topia::Context) : Topia::Context
    begin
      call_next(context)
    rescue ex : Azu::Error
      Azu::Logger.error("Azu CLI error: #{ex.message}")
      context.exit_code = 1
    rescue ex : Exception
      Azu::Logger.error("Unexpected error: #{ex.message}")
      Azu::Logger.debug(ex.backtrace.join("\n"))
      context.exit_code = 1
    end
    context
  end
end
```

## Performance Benefits

### Before Topia Integration

- **Build time**: 45s
- **CPU usage**: 15% (spinner)
- **Memory**: Growing over time
- **Cache hits**: 0%

### After Topia Integration

- **Build time**: 12s (with parallelism + caching)
- **CPU usage**: <1% (async spinner)
- **Memory**: Stable with cleanup
- **Cache hits**: 85%+

### Real-World Results

- **Medium project (50 files)**: 40s → 8s (**5x faster**)
- **Large project (200+ files)**: 3min → 45s (**4x faster**)
- **CI pipeline**: 8min → 2min (**4x faster**)

## Best Practices

### Task Design

1. **Keep tasks focused**: Each task should have a single responsibility
2. **Use dependencies**: Leverage Topia's dependency system for proper ordering
3. **Enable caching**: Use caching for expensive operations
4. **Profile performance**: Use Topia's profiling tools to identify bottlenecks

### Plugin Development

1. **Follow the interface**: Implement `Topia::BasePlugin` correctly
2. **Handle errors gracefully**: Provide meaningful error messages
3. **Use lifecycle hooks**: Implement proper setup and cleanup
4. **Document your plugin**: Provide clear documentation for users

### Configuration

1. **Use environment variables**: For sensitive configuration
2. **Provide defaults**: Always provide sensible default values
3. **Validate configuration**: Use Topia's validation features
4. **Keep it simple**: Avoid overly complex configuration structures

## Related Documentation

- [Topia Repository](https://github.com/azutoolkit/topia) - Official Topia documentation
- [Architecture Overview](README.md) - Overall Azu CLI architecture
- [Generator System](generator-system.md) - Code generation architecture
- [Configuration System](configuration.md) - Configuration management
- [Plugin System](plugins.md) - Plugin development guide
