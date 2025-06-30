# azu help

The `azu help` command provides comprehensive help information for the Azu CLI tool and its commands.

## Usage

```bash
azu help [COMMAND]
```

## Description

The `help` command displays detailed information about available commands, their options, and usage examples. It's the primary way to discover and understand the Azu CLI's capabilities.

## Options

- `[COMMAND]` - Optional command name to get specific help for that command

## Examples

### Show general help

```bash
azu help
```

This displays the main help screen with all available commands:

```
Azu CLI - Crystal Web Framework Command Line Interface

Usage: azu [COMMAND] [OPTIONS]

Commands:
  new         Create a new Azu project
  init        Initialize an existing project with Azu
  generate    Generate components, models, and other code
  serve       Start the development server
  dev         Development tools and utilities
  db:create   Create the database
  db:migrate  Run database migrations
  db:rollback Rollback database migrations
  db:seed     Seed the database with initial data
  db:reset    Reset the database (drop, create, migrate, seed)
  help        Show this help message
  version     Show version information

Options:
  -h, --help    Show this help message
  -v, --version Show version information

For more information about a specific command, run:
  azu help [COMMAND]
```

### Get help for a specific command

```bash
azu help new
```

This shows detailed help for the `new` command:

```
azu new - Create a new Azu project

Usage: azu new PROJECT_NAME [OPTIONS]

Arguments:
  PROJECT_NAME    Name of the project to create

Options:
  -t, --template TEMPLATE    Template to use (default: web)
  -d, --database DATABASE    Database adapter (postgresql, mysql, sqlite)
  -a, --auth                 Include authentication setup
  -r, --real-time            Include real-time features
  -s, --skip-git             Skip git initialization
  -f, --force                Overwrite existing directory
  -h, --help                 Show this help message

Examples:
  azu new my-blog
  azu new my-api --template api --database postgresql
  azu new my-app --auth --real-time
```

### Get help for database commands

```bash
azu help db:create
```

## Help Format

The help output includes:

- **Command description**: Brief explanation of what the command does
- **Usage syntax**: How to use the command with arguments and options
- **Arguments**: Required and optional arguments with descriptions
- **Options**: Available flags and their purposes
- **Examples**: Common usage patterns and examples
- **Related commands**: Suggestions for related commands

## Interactive Help

For an interactive help experience, you can also use:

```bash
azu --help
```

This provides the same information as `azu help` but in a more compact format.

## Getting Help Online

For additional help and documentation:

- **Documentation**: https://github.com/azutoolkit/azu-cli/docs
- **GitHub Issues**: https://github.com/azutoolkit/azu-cli/issues
- **Discord Community**: Join our Discord for real-time support

## Tips

- Use `azu help` to discover new commands
- Combine with `grep` to search for specific functionality: `azu help | grep database`
- Use `--help` flag with any command for quick reference
- Check the examples section for common usage patterns
