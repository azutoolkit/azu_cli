# Logging System

The Azu CLI logging system provides structured, configurable logging capabilities that integrate seamlessly with the application's configuration system. It supports multiple log levels, output formats, and destinations while maintaining high performance and developer-friendly output.

## Overview

The logging system is designed to be:

- **Structured**: Consistent log format with contextual information
- **Configurable**: Multiple log levels and output formats
- **Performance**: Minimal overhead with async logging capabilities
- **Developer-Friendly**: Colored output and readable formatting
- **Extensible**: Easy to add custom loggers and formatters

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Logging System                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Logger    │  │   Formatter │  │   Handler   │          │
│  │   Manager   │  │   Manager   │  │   Manager   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Console   │  │    File     │  │   Network   │          │
│  │   Handler   │  │   Handler   │  │   Handler   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Default   │  │    JSON     │  │   Custom    │          │
│  │  Formatter  │  │  Formatter  │  │  Formatter  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│                    Configuration System                     │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### Logger Manager

The logger manager provides a centralized interface for logging operations:

```crystal
class Azu::Logger
  @@instance : Azu::Logger?
  @@level : Log::Severity = Log::Severity::Info
  @@handlers : Array(Log::Handler) = [] of Log::Handler
  @@formatter : Log::Formatter = DefaultFormatter.new

  def self.instance : Azu::Logger
    @@instance ||= new
  end

  def initialize
    setup_logging
  end

  private def setup_logging
    config = Azu::Config.current.logging

    # Set log level
    @@level = parse_level(config.level)

    # Setup handlers
    setup_handlers(config)

    # Setup formatter
    setup_formatter(config.format)
  end

  private def setup_handlers(config : LoggingConfig)
    @@handlers.clear

    # Console handler
    console_handler = Log::IOHandler.new(
      io: STDOUT,
      formatter: @@formatter,
      level: @@level
    )
    @@handlers << console_handler

    # File handler (if configured)
    if file_path = config.file
      file_handler = Log::IOHandler.new(
        io: File.new(file_path, "a"),
        formatter: @@formatter,
        level: @@level
      )
      @@handlers << file_handler
    end
  end

  private def setup_formatter(format : String)
    @@formatter = case format.downcase
    when "json"
      JSONFormatter.new
    when "default"
      DefaultFormatter.new
    when "simple"
      SimpleFormatter.new
    else
      DefaultFormatter.new
    end
  end

  private def parse_level(level : String) : Log::Severity
    case level.downcase
    when "debug"
      Log::Severity::Debug
    when "info"
      Log::Severity::Info
    when "warn", "warning"
      Log::Severity::Warn
    when "error"
      Log::Severity::Error
    when "fatal"
      Log::Severity::Fatal
    else
      Log::Severity::Info
    end
  end

  # Logging methods
  def self.debug(message : String, context : Hash(String, String) = {} of String => String)
    log(Log::Severity::Debug, message, context)
  end

  def self.info(message : String, context : Hash(String, String) = {} of String => String)
    log(Log::Severity::Info, message, context)
  end

  def self.warn(message : String, context : Hash(String, String) = {} of String => String)
    log(Log::Severity::Warn, message, context)
  end

  def self.error(message : String, context : Hash(String, String) = {} of String => String)
    log(Log::Severity::Error, message, context)
  end

  def self.fatal(message : String, context : Hash(String, String) = {} of String => String)
    log(Log::Severity::Fatal, message, context)
  end

  private def self.log(severity : Log::Severity, message : String, context : Hash(String, String))
    entry = Log::Entry.new(
      severity: severity,
      message: message,
      source: "Azu::CLI",
      timestamp: Time.utc,
      context: context
    )

    @@handlers.each do |handler|
      handler.call(entry) if entry.severity >= handler.level
    end
  end
end
```

### Formatters

Formatters define how log messages are formatted for output:

```crystal
# Default formatter with colors
class Azu::Logger::DefaultFormatter < Log::Formatter
  def format(entry : Log::Entry, io : IO)
    # Timestamp
    io << entry.timestamp.to_s("%Y-%m-%d %H:%M:%S")
    io << " "

    # Level with color
    level_color = level_color(entry.severity)
    io << level_color
    io << entry.severity.to_s.upcase.ljust(5)
    io << "\e[0m"
    io << " "

    # Source
    io << "[#{entry.source}] "

    # Message
    io << entry.message

    # Context (if any)
    unless entry.context.empty?
      io << " "
      format_context(entry.context, io)
    end

    io << "\n"
  end

  private def level_color(severity : Log::Severity) : String
    case severity
    when .debug?
      "\e[36m"  # Cyan
    when .info?
      "\e[32m"  # Green
    when .warn?
      "\e[33m"  # Yellow
    when .error?
      "\e[31m"  # Red
    when .fatal?
      "\e[35m"  # Magenta
    else
      "\e[0m"   # Reset
    end
  end

  private def format_context(context : Hash(String, String), io : IO)
    io << "{"
    context.each_with_index do |(key, value), index|
      io << ", " if index > 0
      io << "#{key}=#{value}"
    end
    io << "}"
  end
end

# JSON formatter for structured logging
class Azu::Logger::JSONFormatter < Log::Formatter
  def format(entry : Log::Entry, io : IO)
    json = {
      timestamp: entry.timestamp.to_rfc3339,
      level: entry.severity.to_s.downcase,
      source: entry.source,
      message: entry.message,
      context: entry.context
    }

    io << json.to_json
    io << "\n"
  end
end

# Simple formatter for minimal output
class Azu::Logger::SimpleFormatter < Log::Formatter
  def format(entry : Log::Entry, io : IO)
    io << entry.severity.to_s.upcase
    io << ": "
    io << entry.message
    io << "\n"
  end
end
```

### Handlers

Handlers define where log messages are sent:

```crystal
# Console handler with color support
class Azu::Logger::ConsoleHandler < Log::IOHandler
  def initialize(@io : IO = STDOUT, @formatter : Log::Formatter = DefaultFormatter.new, @level : Log::Severity = Log::Severity::Info)
    super(@io, @formatter, @level)
  end

  def call(entry : Log::Entry)
    return unless entry.severity >= @level

    @formatter.format(entry, @io)
    @io.flush
  end
end

# File handler with rotation
class Azu::Logger::FileHandler < Log::IOHandler
  getter file_path : String
  getter max_size : Int64
  getter max_files : Int32

  def initialize(@file_path : String, @formatter : Log::Formatter = DefaultFormatter.new, @level : Log::Severity = Log::Severity::Info, @max_size : Int64 = 10 * 1024 * 1024, @max_files : Int32 = 5)
    @io = File.new(@file_path, "a")
    super(@io, @formatter, @level)
  end

  def call(entry : Log::Entry)
    return unless entry.severity >= @level

    # Check file size and rotate if needed
    rotate_if_needed

    @formatter.format(entry, @io)
    @io.flush
  end

  private def rotate_if_needed
    return unless File.exists?(@file_path)

    file_size = File.size(@file_path)
    return if file_size < @max_size

    # Close current file
    @io.close

    # Rotate existing files
    (@max_files - 1).downto(1) do |i|
      old_path = "#{@file_path}.#{i}"
      new_path = "#{@file_path}.#{i + 1}"

      if File.exists?(old_path)
        File.move(old_path, new_path) if i < @max_files - 1
      end
    end

    # Move current file to .1
    File.move(@file_path, "#{@file_path}.1")

    # Open new file
    @io = File.new(@file_path, "a")
  end
end

# Network handler for remote logging
class Azu::Logger::NetworkHandler < Log::Handler
  getter url : String
  getter headers : HTTP::Headers

  def initialize(@url : String, @formatter : Log::Formatter = JSONFormatter.new, @level : Log::Severity = Log::Severity::Info)
    @headers = HTTP::Headers.new
    @headers["Content-Type"] = "application/json"
    super(@level)
  end

  def call(entry : Log::Entry)
    return unless entry.severity >= @level

    # Format entry as JSON
    json_data = String.build do |str|
      @formatter.format(entry, str)
    end

    # Send to remote server
    spawn do
      send_log_entry(json_data)
    end
  end

  private def send_log_entry(json_data : String)
    HTTP::Client.post(@url, headers: @headers, body: json_data)
  rescue ex
    # Silently fail for network logging
    STDERR.puts "Failed to send log entry: #{ex.message}"
  end
end
```

## Configuration Integration

### Logging Configuration

The logging system integrates with the main configuration system:

```crystal
class Azu::Config::LoggingConfig
  getter level : String
  getter format : String
  getter file : String?
  getter colored_output : Bool
  getter network_url : String?

  def initialize(config : Hash(String, Any))
    @level = config["level"]?.try(&.as_s) || "info"
    @format = config["format"]?.try(&.as_s) || "default"
    @file = config["file"]?.try(&.as_s)
    @colored_output = config["colored_output"]?.try(&.as_bool) || true
    @network_url = config["network_url"]?.try(&.as_s)
  end
end
```

### Configuration Usage

```crystal
# In configuration files
logging:
  level: info
  format: default
  colored_output: true
  file: logs/application.log
  network_url: https://logs.example.com/api/logs

# Environment-specific logging
development:
  logging:
    level: debug
    format: default
    colored_output: true

production:
  logging:
    level: info
    format: json
    colored_output: false
    file: logs/application.log
```

## Usage Examples

### Basic Logging

```crystal
# Simple logging
Azu::Logger.info("Application started")
Azu::Logger.debug("Debug information")
Azu::Logger.warn("Warning message")
Azu::Logger.error("Error occurred")
Azu::Logger.fatal("Fatal error")

# Logging with context
Azu::Logger.info("User created", {
  "user_id" => "123",
  "email" => "user@example.com"
})

Azu::Logger.error("Database connection failed", {
  "host" => "localhost",
  "port" => "5432",
  "error" => "Connection refused"
})
```

### Command Logging

```crystal
class Azu::Commands::Generate < Azu::Commands::Base
  def call
    Azu::Logger.info("Starting code generation", {
      "generator" => @generator_type,
      "name" => @name,
      "options" => @options.to_json
    })

    begin
      generator = Azu::Generators::Registry.create(@name, @generator_type, @options)
      generator.generate

      Azu::Logger.info("Code generation completed successfully", {
        "generator" => @generator_type,
        "name" => @name
      })
    rescue ex
      Azu::Logger.error("Code generation failed", {
        "generator" => @generator_type,
        "name" => @name,
        "error" => ex.message
      })
      raise
    end
  end
end
```

### Database Logging

```crystal
class Azu::Commands::Database < Azu::Commands::Base
  def call
    config = Azu::Config.current

    Azu::Logger.info("Database operation started", {
      "operation" => @subcommand,
      "host" => config.database.host,
      "port" => config.database.port.to_s,
      "database" => config.database.name
    })

    case @subcommand
    when "create"
      create_database
    when "migrate"
      run_migrations
    when "seed"
      seed_database
    else
      Azu::Logger.error("Unknown database command", {
        "command" => @subcommand
      })
    end
  end

  private def create_database
    Azu::Logger.debug("Creating database...")
    # Database creation logic
    Azu::Logger.info("Database created successfully")
  end

  private def run_migrations
    Azu::Logger.debug("Running migrations...")
    # Migration logic
    Azu::Logger.info("Migrations completed successfully")
  end
end
```

### Development Server Logging

```crystal
class Azu::Commands::Serve < Azu::Commands::Base
  def call
    config = Azu::Config.current

    Azu::Logger.info("Starting development server", {
      "host" => config.server.host,
      "port" => config.server.port.to_s,
      "watch" => config.server.watch.to_s,
      "rebuild" => config.server.rebuild.to_s
    })

    if config.server.watch
      Azu::Logger.info("File watching enabled")
      setup_file_watcher
    end

    start_server
  end

  private def setup_file_watcher
    Azu::Logger.debug("Setting up file watcher")
    # File watching setup
  end

  private def start_server
    Azu::Logger.info("Server started successfully")
    # Server startup logic
  end
end
```

## Performance Considerations

### Async Logging

For high-performance scenarios, the logging system supports async operations:

```crystal
class Azu::Logger::AsyncHandler < Log::Handler
  @queue = Channel(Log::Entry).new(1000)
  @running = true

  def initialize(@handler : Log::Handler)
    super(@handler.level)
    spawn { process_queue }
  end

  def call(entry : Log::Entry)
    return unless entry.severity >= @level

    # Non-blocking send to queue
    @queue.send(entry) rescue nil
  end

  private def process_queue
    while @running
      entry = @queue.receive
      @handler.call(entry)
    end
  end

  def shutdown
    @running = false
  end
end
```

### Log Level Filtering

The logging system efficiently filters messages by level:

```crystal
class Azu::Logger::LevelFilter < Log::Handler
  def initialize(@handler : Log::Handler, @min_level : Log::Severity)
    super(@handler.level)
  end

  def call(entry : Log::Entry)
    return unless entry.severity >= @min_level
    @handler.call(entry)
  end
end
```

## Custom Loggers

### Creating Custom Loggers

Users can create custom loggers for specific use cases:

```crystal
class Azu::Logger::CustomLogger
  def self.log_generation(generator_type : String, name : String, success : Bool)
    if success
      Azu::Logger.info("✅ Generated #{generator_type}: #{name}")
    else
      Azu::Logger.error("❌ Failed to generate #{generator_type}: #{name}")
    end
  end

  def self.log_database_operation(operation : String, success : Bool, details : String? = nil)
    context = {"operation" => operation}
    context["details"] = details if details

    if success
      Azu::Logger.info("🗄️  Database #{operation} completed", context)
    else
      Azu::Logger.error("🗄️  Database #{operation} failed", context)
    end
  end

  def self.log_server_status(status : String, port : Int32)
    Azu::Logger.info("🌐 Server #{status} on port #{port}")
  end
end
```

### Usage of Custom Loggers

```crystal
# In generators
Azu::Logger::CustomLogger.log_generation("model", "User", true)

# In database commands
Azu::Logger::CustomLogger.log_database_operation("migrate", true, "5 migrations applied")

# In server commands
Azu::Logger::CustomLogger.log_server_status("started", 3000)
```

## Best Practices

### Log Level Usage

1. **Debug**: Detailed information for debugging
2. **Info**: General application flow information
3. **Warn**: Warning conditions that don't stop execution
4. **Error**: Error conditions that affect functionality
5. **Fatal**: Critical errors that require immediate attention

### Context Information

1. **Include relevant context**: Add useful information to log messages
2. **Structured data**: Use consistent key-value pairs for context
3. **Avoid sensitive data**: Never log passwords, tokens, or personal information
4. **Performance data**: Include timing and resource usage when relevant

### Performance

1. **Use appropriate log levels**: Don't log debug information in production
2. **Async logging**: Use async handlers for high-volume logging
3. **File rotation**: Configure log file rotation to manage disk space
4. **Network logging**: Handle network failures gracefully

### Security

1. **Sanitize input**: Remove sensitive information from log messages
2. **Access control**: Restrict access to log files in production
3. **Audit trails**: Maintain logs for security auditing
4. **Compliance**: Ensure logging meets compliance requirements

## Related Documentation

- [Configuration System](configuration.md) - Configuration management
- [CLI Framework (Topia)](cli-framework.md) - Command-line interface framework
- [Commands Reference](../commands/README.md) - Command documentation
- [Environment Variables](../reference/cli-options.md) - Environment variable reference
