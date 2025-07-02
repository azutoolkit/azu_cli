# OptionParser Integration Guide

This document explains how the Azu CLI uses Crystal's built-in `OptionParser` for robust command-line argument parsing.

## Overview

The Azu CLI has been enhanced to use Crystal's `OptionParser` class ([API documentation](https://crystal-lang.org/api/1.16.3/OptionParser.html)) for standardized and powerful option parsing. This provides:

- **Automatic help generation**: Rich help messages with proper formatting
- **Type validation**: Built-in validation for different argument types
- **Error handling**: Standardized error messages for invalid options
- **GNU-style options**: Support for both short (`-h`) and long (`--help`) options
- **Flexible parsing**: Support for optional arguments and multiple value types
- **Backward compatibility**: Existing commands continue to work

## Architecture

### Base Command Class

All commands inherit from the enhanced `Command` base class which provides:

```crystal
abstract class Command
  # Storage for parsed options
  getter parsed_options : Hash(String, String | Bool | Array(String))
  getter remaining_args : Array(String)

  # Abstract methods for OptionParser integration
  abstract def execute_with_options(options, args) : String | Nil
  def setup_command_options(parser : OptionParser)
    # Override in subclasses
  end
end
```

### Option Parsing Flow

1. **Global parsing**: Main CLI parses global options and identifies command
2. **Command parsing**: Specific command sets up its options via `setup_command_options`
3. **Validation**: Command validates parsed arguments via `validate_parsed_args`
4. **Execution**: Command executes with parsed options via `execute_with_options`

## Creating Commands with OptionParser

### Basic Command Structure

```crystal
class MyCommand < Command
  command_name "mycommand"
  description "Description of what this command does"
  usage "mycommand [options] <required_arg>"

  # Setup command-specific options
  def setup_command_options(parser : OptionParser)
    parser.separator ""
    parser.separator "Command Options:"

    parser.on("-f FILE", "--file FILE", "Input file path") do |file|
      parsed_options["file"] = file
    end

    parser.on("-c", "--count", "Enable counting") do
      parsed_options["count"] = true
    end

    parser.on("-t TYPE", "--type TYPE", "Processing type") do |type|
      unless ["text", "json", "xml"].includes?(type)
        raise ArgumentError.new("Type must be one of: text, json, xml")
      end
      parsed_options["type"] = type
    end

    parser.separator ""
    parser.separator "Examples:"
    parser.separator "  azu mycommand input.txt --type json"
    parser.separator "  azu mycommand --file data.xml --count"
  end

  # Validate parsed arguments (optional)
  def validate_parsed_args
    if get_option("file").empty? && remaining_args.empty?
      raise ValidationError.new("Either --file or input argument required")
    end
  end

  # Execute with parsed options
  def execute_with_options(options, args) : String | Nil
    file = get_option("file")
    count_enabled = get_option_bool("count")
    processing_type = get_option("type", "text")

    # Use remaining_args for positional arguments
    input_files = args

    # Command implementation here
    log.info("Processing #{input_files.size} files with type: #{processing_type}")

    nil
  end
end
```

### Helper Methods

The base `Command` class provides helper methods for accessing parsed options:

```crystal
# Get string option with default value
get_option("key", "default") : String

# Get boolean option with default value
get_option_bool("key", false) : Bool

# Get array option (for multiple values)
get_option_array("key") : Array(String)

# Check if option exists
has_option?("key") : Bool
```

### Option Types and Patterns

#### String Options

```crystal
parser.on("-f FILE", "--file FILE", "Input file") do |file|
  parsed_options["file"] = file
end
```

#### Boolean Flags

```crystal
parser.on("-v", "--verbose", "Enable verbose output") do
  parsed_options["verbose"] = true
end
```

#### Optional Arguments

```crystal
parser.on("-p [PORT]", "--port [PORT]", "Port number (default: 3000)") do |port|
  parsed_options["port"] = port || "3000"
end
```

#### Validated Options

```crystal
parser.on("-e ENV", "--environment ENV", "Environment") do |env|
  unless ["development", "test", "production"].includes?(env)
    raise ArgumentError.new("Invalid environment: #{env}")
  end
  parsed_options["environment"] = env
end
```

#### Multiple Values

```crystal
parser.on("-t TAG", "--tag TAG", "Add tag (can be used multiple times)") do |tag|
  if existing = parsed_options["tags"]?
    if existing.is_a?(Array(String))
      existing << tag
    else
      parsed_options["tags"] = [existing.as(String), tag]
    end
  else
    parsed_options["tags"] = [tag]
  end
end
```

## Global Options

All commands automatically inherit these global options:

- `-h, --help`: Show command help
- `-v, --version`: Show version information
- `--verbose`: Enable verbose output
- `--quiet`: Suppress non-essential output
- `--force`: Force operation without prompts

## Error Handling

The OptionParser integration provides standardized error handling:

### Invalid Options

```crystal
# Automatically handled:
azu mycommand --invalid-option
# Error: Invalid option: --invalid-option
# Run 'azu mycommand --help' to see available options
```

### Missing Required Arguments

```crystal
parser.on("-f FILE", "--file FILE", "Required file") do |file|
  parsed_options["file"] = file
end

# Usage: azu mycommand --file
# Error: Missing required argument for option: --file
```

### Custom Validation

```crystal
def validate_parsed_args
  if get_option("input").empty?
    raise ValidationError.new(
      "Input file is required",
      ["Use --input FILE to specify input file",
       "Or provide filename as argument"]
    )
  end
end
```

## Help Generation

OptionParser automatically generates help messages:

```bash
$ azu serve --help
Usage: azu serve [options]

  -h, --help                       Show help for this command
  -v, --version                    Show version information
      --verbose                    Enable verbose output
      --quiet                      Suppress output
      --force                      Force operation without prompts

Server Options:
  -p PORT, --port PORT             Port to listen on (default: 3000)
  -H HOST, --host HOST             Host to bind to (default: 0.0.0.0)
  -e ENV, --environment ENV        Environment to run in (default: development)
      --no-reload                  Disable automatic reloading
      --ssl                        Enable SSL/TLS
      --ssl-cert CERT              SSL certificate file
      --ssl-key KEY                SSL private key file
      --open                       Open browser after starting server

Examples:
  azu serve                          # Start server on default port
  azu serve -p 8080                 # Start on port 8080
  azu serve --host localhost        # Bind to localhost only
  azu serve -e production           # Run in production mode
  azu serve --ssl --ssl-cert cert.pem --ssl-key key.pem
  azu serve --no-reload --quiet     # Disable auto-reload and output
```

## Backward Compatibility

Existing commands continue to work through compatibility methods:

```crystal
# Legacy execute method is automatically mapped to new system
def execute(args : Hash(String, String | Array(String))) : String | Nil
  # Automatically converts to execute_with_options format
end
```

## Best Practices

### Option Naming

- Use descriptive long option names: `--database` not `--db`
- Provide short aliases for common options: `-p` for `--port`
- Use kebab-case for multi-word options: `--skip-interactive`

### Help Messages

- Group related options with `parser.separator`
- Provide examples in help text
- Include default values in descriptions
- Use clear, actionable descriptions

### Validation

- Validate options early in `validate_parsed_args`
- Provide helpful error messages with suggestions
- Check file existence for file arguments
- Validate enum values for restricted options

### Error Messages

- Be specific about what went wrong
- Suggest correct usage
- Include examples when helpful
- Reference help command for more information

## Migration Guide

To migrate an existing command to use OptionParser:

1. **Add `setup_command_options` method**:

   ```crystal
   def setup_command_options(parser : OptionParser)
     # Define your options here
   end
   ```

2. **Replace `execute` with `execute_with_options`**:

   ```crystal
   def execute_with_options(options, args) : String | Nil
     # Use get_option() methods instead of get_flag()
     # Use args directly instead of get_positional_args()
   end
   ```

3. **Update option access**:

   ```crystal
   # Old way:
   force = has_flag?(args, "force")
   file = get_flag(args, "file", "")

   # New way:
   force = get_option_bool("force")
   file = get_option("file")
   ```

4. **Add validation (optional)**:
   ```crystal
   def validate_parsed_args
     # Add custom validation logic
   end
   ```

The legacy `execute` method can be kept for backward compatibility, or removed once migration is complete.

## Examples

See the following commands for complete examples:

- `src/azu_cli/commands/new.cr` - Complex command with multiple options
- `src/azu_cli/commands/serve.cr` - Server command with validation
- `src/azu_cli/commands/generate_optimized.cr` - Generation command with subcommands

## Resources

- [Crystal OptionParser API](https://crystal-lang.org/api/1.16.3/OptionParser.html)
- [GNU-style command-line options](https://www.gnu.org/software/libc/manual/html_node/Argument-Syntax.html)
- [Crystal CLI best practices](https://crystal-lang.org/reference/1.16/guides/cli.html)
