# Shard Generator

The Shard Generator creates a properly formatted `shard.yml` file following Crystal Programming Language conventions and best practices.

## Overview

The shard generator produces a `shard.yml` file that includes:

- **Project metadata**: name, version, authors, license
- **Crystal version requirements**: specifies minimum Crystal version
- **Dependencies**: project dependencies with proper source formatting
- **Development dependencies**: tools needed for development
- **Targets**: executable definitions with entry points

## Usage

### Basic Usage

Generate a basic `shard.yml` file:

```bash
azu generate shard my_project
```

This creates a `shard.yml` file in the current directory with:

- Project name: `my-project` (kebab-case)
- Version: `0.1.0`
- Crystal version: `>= 1.16.0`
- License: `MIT`
- Default Azu framework dependencies

### Advanced Usage

Generate with custom configuration:

```bash
azu generate shard my_project \
  --version "1.0.0" \
  --crystal-version ">= 1.15.0" \
  --license "Apache-2.0" \
  --authors "John Doe <john@example.com>,Jane Smith <jane@example.com>" \
  --database "mysql" \
  --output-dir "."
```

### Database Support

Generate shard.yml with specific database support:

```bash
# PostgreSQL (default)
azu generate shard my_project --database postgresql

# MySQL
azu generate shard my_project --database mysql

# SQLite
azu generate shard my_project --database sqlite
```

### Programmatic Usage

```crystal
require "azu_cli/generators/shard_generator"

# Basic usage
generator = AzuCLI::Generators::ShardGenerator.new("my_project")
generator.generate!

# Custom configuration
generator = AzuCLI::Generators::ShardGenerator.new(
  "my_awesome_app",
  output_dir: "/path/to/project",
  version: "2.0.0",
  crystal_version: ">= 1.16.0",
  license: "MIT",
  authors: ["Developer <dev@example.com>"],
  dependencies: {
    "custom_lib" => "user/custom_lib"
  },
  dev_dependencies: {
    "webmock" => "manastech/webmock.cr",
    "ameba" => "crystal-ameba/ameba"
  },
  database: "mysql"
)

output_path = generator.generate!
```

## Generated Output

### Example shard.yml

Generated with MySQL database support:

```yaml
name: my-awesome-app
version: 1.0.0

authors:
  - John Doe <john@example.com>

crystal: ">= 1.16.0"

license: MIT

# Generated with database support for: mysql

targets:
  my-awesome-app:
    main: src/my_awesome_app.cr

dependencies:
  azu:
    github: azutoolkit/azu
  topia:
    github: azutoolkit/topia
  cql:
    github: azutoolkit/cql
  session:
    github: azutoolkit/session
  mysql:
    github: crystal-lang/crystal-mysql

development_dependencies:
  webmock:
    github: manastech/webmock.cr
  ameba:
    github: crystal-ameba/ameba
```

## Configuration Options

### Project Metadata

| Option    | Type          | Default                          | Description                            |
| --------- | ------------- | -------------------------------- | -------------------------------------- |
| `name`    | String        | Required                         | Project name (converted to kebab-case) |
| `version` | String        | `"0.1.0"`                        | Semantic version                       |
| `authors` | Array(String) | `["Your Name <your@email.com>"]` | Author information                     |
| `license` | String        | `"MIT"`                          | License identifier                     |

### Crystal Configuration

| Option            | Type   | Default       | Description             |
| ----------------- | ------ | ------------- | ----------------------- |
| `crystal_version` | String | `">= 1.16.0"` | Minimum Crystal version |

### Dependencies

| Option             | Type                 | Default          | Description              |
| ------------------ | -------------------- | ---------------- | ------------------------ |
| `dependencies`     | Hash(String, String) | Azu defaults     | Runtime dependencies     |
| `dev_dependencies` | Hash(String, String) | Testing defaults | Development dependencies |

### Database Configuration

| Option     | Type   | Default        | Description                                                          |
| ---------- | ------ | -------------- | -------------------------------------------------------------------- |
| `database` | String | `"postgresql"` | Database type (`postgresql`, `mysql`, `sqlite`) - adds correct shard |

### Default Dependencies

**Runtime Dependencies:**

- `azu`: Azu web framework
- `topia`: CLI framework
- `cql`: Crystal Query Language ORM
- `session`: Session management

**Development Dependencies:**

- `webmock`: HTTP mocking for tests
- `ameba`: Crystal code linter

**Database-Specific Dependencies (automatically added):**

- **PostgreSQL**: `pg` (will/crystal-pg)
- **MySQL**: `mysql` (crystal-lang/crystal-mysql)
- **SQLite**: `sqlite3` (crystal-lang/crystal-sqlite3)

## Naming Conventions

The generator follows Crystal Programming Language conventions:

### Project Names

The generator automatically converts project names to appropriate formats:

- Input: `MyAwesomeApp` → Output: `my-awesome-app` (kebab-case for shard name)
- Input: `my_cool_project` → Output: `my-cool-project` (kebab-case for shard name)
- Input: `simpleapp` → Output: `simpleapp` (no change needed)

### Target Names

Targets use the kebab-case project name with source files in snake_case:

```yaml
targets:
  my-awesome-app: # kebab-case target name
    main: src/my_awesome_app.cr # snake_case file name
```

## Dependency Source Formats

The generator supports multiple dependency source formats:

### GitHub Dependencies

```yaml
dependencies:
  my_shard:
    github: username/repository
```

### Git Dependencies

```yaml
dependencies:
  my_shard:
    git: https://github.com/username/repository.git
```

### Path Dependencies

```yaml
dependencies:
  my_shard:
    path: ../local/path/to/shard
```

## Validation

The generator validates:

- **Project names**: Must be valid Crystal identifiers
- **Version strings**: Cannot be empty
- **Author information**: Must include at least one author
- **Dependency sources**: Must be valid GitHub repo format (owner/repo)
- **Crystal version**: Must be specified

## Integration with Azu CLI

The shard generator integrates with the main `azu generate` command:

```bash
# List available generators
azu generate --help

# Generate shard.yml
azu generate shard my_project

# Generate with options
azu generate shard my_project --version 2.0.0 --license Apache-2.0
```

## Best Practices

### Version Management

- Use semantic versioning (MAJOR.MINOR.PATCH)
- Start with `0.1.0` for new projects
- Increment versions following semantic versioning rules

### Crystal Version Requirements

- Use `>=` for minimum version requirements
- Specify the minimum version your code actually requires
- Test with multiple Crystal versions when possible

### Dependency Management

- Pin dependency versions for production applications
- Use latest stable versions for libraries
- Document why each dependency is needed

### Author Information

- Include full name and email address
- Use consistent format: `Name <email@domain.com>`
- List multiple authors for team projects

### License Selection

- Choose appropriate license for your project
- Common choices: MIT, Apache-2.0, GPL-3.0
- Include LICENSE file in repository

## Troubleshooting

### Common Issues

**Invalid project name error:**

```
Error: Name must be a valid identifier
```

_Solution_: Use valid Crystal identifier (letters, numbers, underscores, starting with letter/underscore)

**Dependency format error:**

```
Error: Invalid GitHub repository format
```

_Solution_: Use `owner/repository` format for GitHub dependencies

**Missing author information:**

```
Error: Authors cannot be empty
```

_Solution_: Provide at least one author in the format `Name <email>`

### Debugging

Enable verbose output to see what the generator is doing:

```crystal
generator = AzuCLI::Generators::ShardGenerator.new("my_project")
generator.generate!
```

Check the generated file manually:

```bash
cat shard.yml
```

Validate the generated shard.yml:

```bash
shards install --dry-run
```

## Related Documentation

- [Crystal Language Shards Guide](https://crystal-lang.org/reference/guides/shards.html)
- [Azu Framework Documentation](https://github.com/azutoolkit/azu)
- [Generator Architecture](../architecture/generator-system.md)
- [CLI Commands Reference](../commands/generate.md)
