# Development Server Configuration

Development server configuration in Azu CLI manages the development environment, including hot reloading, file watching, debugging options, and development-specific settings. This enables fast development cycles with automatic rebuilding and reloading.

## Overview

The development server provides:

- **Hot Reloading**: Automatic rebuild and restart on file changes
- **File Watching**: Monitor source files for changes
- **Live Reloading**: Browser refresh on template changes
- **Debug Mode**: Enhanced debugging capabilities
- **Development Tools**: Built-in development utilities

## Development Server Configuration Structure

### Base Development Configuration

```yaml
# config/development.yml
development:
  # Server settings
  server:
    host: <%= ENV["AZU_HOST"] || "localhost" %>
    port: <%= ENV["AZU_PORT"] || 3000 %>
    workers: 1
    backlog: 1024

  # Hot reloading
  hot_reload:
    enabled: true
    rebuild_on_change: true
    restart_on_change: true
    browser_reload: true

  # File watching
  file_watcher:
    enabled: true
    watch_paths:
      - src/
      - config/
      - public/templates/
    ignored_paths:
      - .git/
      - node_modules/
      - .crystal/
      - bin/
      - tmp/
      - log/
    ignored_extensions:
      - .tmp
      - .swp
      - .swo

  # Compilation
  compilation:
    incremental: true
    parallel: true
    cache_dir: .crystal/
    debug: true
    warnings: true

  # Debugging
  debugging:
    enabled: true
    port: 5005
    suspend: false
    log_level: debug

  # Development tools
  tools:
    inspector: true
    profiler: true
    memory_tracker: true
    performance_monitor: true
```

## Server Configuration

### Basic Server Settings

```yaml
# Server configuration
development:
  server:
    # Network settings
    host: localhost
    port: 3000
    workers: 1
    backlog: 1024

    # SSL/TLS (for HTTPS in development)
    ssl:
      enabled: false
      cert_file: cert.pem
      key_file: key.pem

    # HTTP settings
    http:
      keep_alive: true
      timeout: 30
      max_request_size: 10MB

    # CORS (for API development)
    cors:
      enabled: true
      origins: ["http://localhost:3000", "http://localhost:3001"]
      methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"]
      headers: ["Content-Type", "Authorization"]
```

### Advanced Server Settings

```yaml
# Advanced server configuration
development:
  server:
    # Performance tuning
    performance:
      tcp_nodelay: true
      reuse_address: true
      keep_alive_timeout: 5

    # Security headers
    security_headers:
      enabled: true
      headers:
        X-Frame-Options: DENY
        X-Content-Type-Options: nosniff
        X-XSS-Protection: "1; mode=block"
        Referrer-Policy: strict-origin-when-cross-origin

    # Rate limiting
    rate_limiting:
      enabled: false
      requests_per_minute: 100
      burst_size: 10

    # Compression
    compression:
      enabled: true
      level: 6
      types:
        - text/html
        - text/css
        - application/javascript
        - application/json
```

## Hot Reloading Configuration

### Hot Reload Settings

```yaml
# Hot reload configuration
development:
  hot_reload:
    # Enable/disable hot reloading
    enabled: true

    # Rebuild settings
    rebuild_on_change: true
    restart_on_change: true
    browser_reload: true

    # Rebuild triggers
    triggers:
      # Crystal files
      crystal_files: true
      # Configuration files
      config_files: true
      # Template files
      template_files: true
      # Asset files
      asset_files: false

    # Rebuild behavior
    behavior:
      # Wait time before rebuild
      debounce_ms: 100
      # Maximum rebuild frequency
      max_rebuilds_per_minute: 60
      # Show rebuild progress
      show_progress: true
      # Show rebuild errors
      show_errors: true

    # Browser integration
    browser:
      # Auto-reload browser
      auto_reload: true
      # Reload delay
      reload_delay: 500
      # Reload strategy
      strategy: "full" # full, partial, smart
```

### Hot Reload Implementation

```crystal
# Hot reload implementation
class HotReloader
  def initialize(config : DevelopmentConfig)
    @config = config
    @file_watcher = FileWatcher.new(config.file_watcher)
    @browser_reloader = BrowserReloader.new(config.hot_reload.browser)
    @compiler = Compiler.new(config.compilation)
  end

  def start
    @file_watcher.watch do |changed_files|
      handle_file_changes(changed_files)
    end
  end

  private def handle_file_changes(files : Array(String))
    return unless @config.hot_reload.enabled

    # Debounce changes
    sleep(@config.hot_reload.behavior.debounce_ms.milliseconds)

    # Determine rebuild type
    if should_rebuild?(files)
      rebuild_application
    elsif should_restart?(files)
      restart_application
    elsif should_reload_browser?(files)
      reload_browser
    end
  end

  private def should_rebuild?(files : Array(String)) : Bool
    files.any? { |file| file.ends_with?(".cr") || file.ends_with?(".yml") }
  end

  private def should_restart?(files : Array(String)) : Bool
    files.any? { |file| file.includes?("config/") && file.ends_with?(".yml") }
  end

  private def should_reload_browser?(files : Array(String)) : Bool
    files.any? { |file| file.ends_with?(".jinja") || file.ends_with?(".html") }
  end
end
```

## File Watching Configuration

### File Watcher Settings

```yaml
# File watcher configuration
development:
  file_watcher:
    # Enable/disable file watching
    enabled: true

    # Watch paths
    watch_paths:
      - src/
      - config/
      - public/templates/
      - public/assets/

    # Ignored paths
    ignored_paths:
      - .git/
      - node_modules/
      - .crystal/
      - bin/
      - tmp/
      - log/
      - spec/

    # Ignored file extensions
    ignored_extensions:
      - .tmp
      - .swp
      - .swo
      - .log
      - .pid

    # Watch options
    options:
      # Recursive watching
      recursive: true
      # Follow symlinks
      follow_symlinks: false
      # Watch for new files
      watch_new_files: true
      # Watch for deleted files
      watch_deleted_files: true

    # Performance settings
    performance:
      # Polling interval (for systems without inotify)
      poll_interval: 1000
      # Maximum files to watch
      max_files: 10000
      # Buffer size for file events
      buffer_size: 1024
```

### File Watcher Implementation

```crystal
# File watcher implementation
class FileWatcher
  def initialize(config : FileWatcherConfig)
    @config = config
    @watched_files = Set(String).new
    @callbacks = [] of Proc(Array(String), Nil)
  end

  def watch(&block : Array(String) -> Nil)
    @callbacks << block

    spawn do
      watch_files
    end
  end

  private def watch_files
    # Use system-specific file watching
    if FileWatcher.supports_inotify?
      watch_with_inotify
    else
      watch_with_polling
    end
  end

  private def watch_with_inotify
    # Use inotify for Linux systems
    Inotify.watch(@config.watch_paths) do |event|
      handle_file_event(event)
    end
  end

  private def watch_with_polling
    # Fallback to polling
    loop do
      check_for_changes
      sleep(@config.performance.poll_interval.milliseconds)
    end
  end

  private def handle_file_event(event : FileEvent)
    return if should_ignore?(event.path)

    changed_files = [event.path]
    notify_callbacks(changed_files)
  end

  private def should_ignore?(path : String) : Bool
    @config.ignored_paths.any? { |ignored| path.includes?(ignored) } ||
    @config.ignored_extensions.any? { |ext| path.ends_with?(ext) }
  end

  private def notify_callbacks(files : Array(String))
    @callbacks.each do |callback|
      callback.call(files)
    end
  end
end
```

## Compilation Configuration

### Compilation Settings

```yaml
# Compilation configuration
development:
  compilation:
    # Compilation mode
    mode: incremental

    # Performance settings
    incremental: true
    parallel: true
    cache_dir: .crystal/

    # Debug settings
    debug: true
    warnings: true
    assertions: true

    # Compilation flags
    flags:
      - --debug
      - --warnings
      - --no-debug
      - --threads 2

    # Conditional compilation
    defines:
      - DEVELOPMENT
      - DEBUG
      - ENABLE_LOGGING

    # Optimization
    optimization:
      level: 0 # No optimization for fast compilation
      strip_symbols: false

    # Output settings
    output:
      directory: bin/
      filename: <%= @project_name.underscore %>_dev
      static: false
```

### Compiler Implementation

```crystal
# Compiler implementation
class Compiler
  def initialize(config : CompilationConfig)
    @config = config
    @cache = CompilationCache.new(config.cache_dir)
  end

  def compile : Bool
    Azu::Logger.info("Compiling application...")

    start_time = Time.monotonic

    # Build command
    command = build_compile_command

    # Execute compilation
    result = Process.run(command, shell: true, error: Process::Redirect::Pipe)

    duration = Time.monotonic - start_time

    if result.success?
      Azu::Logger.info("Compilation successful (#{duration.total_milliseconds}ms)")
      true
    else
      Azu::Logger.error("Compilation failed: #{result.error_message}")
      false
    end
  end

  private def build_compile_command : String
    parts = ["crystal", "build"]

    # Add flags
    @config.flags.each { |flag| parts << flag }

    # Add defines
    @config.defines.each { |define| parts << "-D#{define}" }

    # Add output
    parts << "-o#{@config.output.directory}/#{@config.output.filename}"

    # Add main file
    parts << "src/main.cr"

    parts.join(" ")
  end
end
```

## Debugging Configuration

### Debug Settings

```yaml
# Debugging configuration
development:
  debugging:
    # Enable/disable debugging
    enabled: true

    # Debug server settings
    server:
      port: 5005
      host: localhost
      suspend: false

    # Debug options
    options:
      # Show debug info
      show_debug_info: true
      # Show stack traces
      show_stack_traces: true
      # Show variable values
      show_variables: true
      # Show call stack
      show_call_stack: true

    # Logging
    logging:
      level: debug
      show_timestamps: true
      show_source_location: true
      show_thread_id: true

    # Performance profiling
    profiling:
      enabled: true
      cpu_profiling: true
      memory_profiling: true
      allocation_tracking: true
```

### Debug Implementation

```crystal
# Debug implementation
class Debugger
  def initialize(config : DebuggingConfig)
    @config = config
    @profiler = Profiler.new(config.profiling)
  end

  def start
    return unless @config.enabled

    # Start debug server
    start_debug_server

    # Start profiler
    start_profiler

    Azu::Logger.info("Debug mode enabled on port #{@config.server.port}")
  end

  private def start_debug_server
    spawn do
      # Start debug server implementation
      DebugServer.new(@config.server).start
    end
  end

  private def start_profiler
    return unless @config.profiling.enabled

    @profiler.start
  end

  def log_debug(message : String, context : Hash(String, String) = {} of String => String)
    return unless @config.enabled

    Azu::Logger.debug("[DEBUG] #{message}", context)
  end
end
```

## Development Tools Configuration

### Development Tools

```yaml
# Development tools configuration
development:
  tools:
    # Code inspector
    inspector:
      enabled: true
      port: 3001
      auto_open: true

    # Performance profiler
    profiler:
      enabled: true
      port: 3002
      sampling_rate: 1000

    # Memory tracker
    memory_tracker:
      enabled: true
      track_allocations: true
      track_gc: true
      leak_detection: true

    # Performance monitor
    performance_monitor:
      enabled: true
      metrics:
        - response_time
        - memory_usage
        - cpu_usage
        - request_count
      dashboard_port: 3003

    # API documentation
    api_docs:
      enabled: true
      port: 3004
      auto_generate: true
      include_examples: true
```

## Environment-Specific Configuration

### Development Environment

```yaml
# config/development.yml
development:
  server:
    host: localhost
    port: 3000

  hot_reload:
    enabled: true
    rebuild_on_change: true
    browser_reload: true

  file_watcher:
    enabled: true
    watch_paths:
      - src/
      - config/
      - public/templates/

  compilation:
    incremental: true
    debug: true
    warnings: true

  debugging:
    enabled: true
    port: 5005

  tools:
    inspector: true
    profiler: true
    memory_tracker: true
```

### Test Environment

```yaml
# config/test.yml
development:
  server:
    host: localhost
    port: 3001

  hot_reload:
    enabled: false
    rebuild_on_change: false
    browser_reload: false

  file_watcher:
    enabled: false

  compilation:
    incremental: false
    debug: false
    warnings: false

  debugging:
    enabled: false

  tools:
    inspector: false
    profiler: false
    memory_tracker: false
```

## Development Server Commands

### Server Management Commands

```bash
# Start development server
azu serve

# Start with custom port
azu serve --port 4000

# Start with custom host
azu serve --host 0.0.0.0

# Disable hot reloading
azu serve --no-reload

# Enable debug mode
azu serve --debug

# Start with profiling
azu serve --profile

# Show server status
azu serve --status

# Stop development server
azu serve --stop
```

### Development Tools Commands

```bash
# Open code inspector
azu dev inspector

# Open performance profiler
azu dev profiler

# Open memory tracker
azu dev memory

# Open performance monitor
azu dev monitor

# Generate API documentation
azu dev api-docs

# Show development tools
azu dev tools
```

## Environment Variables

### Development Environment Variables

```bash
# Server settings
export AZU_HOST="localhost"
export AZU_PORT="3000"
export AZU_WORKERS="1"

# Hot reloading
export AZU_HOT_RELOAD="true"
export AZU_REBUILD_ON_CHANGE="true"
export AZU_BROWSER_RELOAD="true"

# File watching
export AZU_FILE_WATCHER="true"
export AZU_WATCH_PATHS="src/,config/,public/templates/"

# Compilation
export AZU_INCREMENTAL="true"
export AZU_PARALLEL="true"
export AZU_DEBUG="true"
export AZU_WARNINGS="true"

# Debugging
export AZU_DEBUG_MODE="true"
export AZU_DEBUG_PORT="5005"

# Development tools
export AZU_INSPECTOR="true"
export AZU_PROFILER="true"
export AZU_MEMORY_TRACKER="true"
```

## Best Practices

### Development Workflow

1. **Hot Reloading**: Enable hot reloading for fast development cycles
2. **File Watching**: Configure appropriate watch paths and ignored paths
3. **Incremental Compilation**: Use incremental compilation for faster builds
4. **Debug Mode**: Enable debug mode during development
5. **Development Tools**: Use built-in development tools for debugging

### Performance

1. **Watch Paths**: Limit watch paths to necessary directories
2. **Ignored Paths**: Exclude unnecessary directories from watching
3. **Debouncing**: Use appropriate debounce times for file changes
4. **Compilation Cache**: Enable compilation caching
5. **Parallel Compilation**: Use parallel compilation when possible

### Debugging

1. **Debug Mode**: Enable debug mode for detailed error information
2. **Profiling**: Use profiling tools to identify performance bottlenecks
3. **Memory Tracking**: Monitor memory usage during development
4. **Logging**: Use appropriate log levels for debugging
5. **Error Handling**: Implement proper error handling and reporting

## Related Documentation

- [Configuration Overview](README.md) - General configuration guide
- [Project Configuration](project-config.md) - Project-specific configuration
- [Database Configuration](database-config.md) - Database configuration
- [Generator Configuration](generator-config.md) - Code generation configuration
- [Environment Variables](environment.md) - Environment variable reference
