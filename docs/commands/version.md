# azu version

The `azu version` command displays version information about the Azu CLI tool and its dependencies.

## Usage

```bash
azu version [OPTIONS]
```

## Description

The `version` command shows the current version of the Azu CLI, along with information about the Crystal runtime and key dependencies. This is useful for debugging, reporting issues, and ensuring compatibility.

## Options

- `-h, --help` - Show help message for this command
- `-v, --verbose` - Show detailed version information including all dependencies

## Examples

### Show basic version information

```bash
azu version
```

Output:

```
Azu CLI v0.0.1+13
Crystal v1.16.0
```

### Show detailed version information

```bash
azu version --verbose
```

Output:

```
Azu CLI v0.0.1+13
Crystal v1.16.0 [a1b2c3d4e5] (2024-01-15)

Dependencies:
  azu v0.1.0
  cql v0.1.0
  topia v0.1.0

Platform: darwin 24.5.0
Architecture: x86_64
```

## Version Information

The version command displays:

- **Azu CLI version**: The current version of the CLI tool
- **Crystal version**: The Crystal language version being used
- **Dependencies**: Versions of key dependencies (in verbose mode)
- **Platform information**: Operating system and architecture details

## Version Format

Azu CLI uses semantic versioning with the format `MAJOR.MINOR.PATCH+BUILD`:

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)
- **BUILD**: Build number for development versions

## Checking Compatibility

Use the version command to verify compatibility:

```bash
# Check if you have a compatible version
azu version | grep "Azu CLI v0.0.1"

# Check Crystal version compatibility
azu version | grep "Crystal v1.16"
```

## Integration with Other Tools

The version command can be used in scripts and CI/CD pipelines:

```bash
# In a shell script
VERSION=$(azu version | head -n1 | cut -d' ' -f3)
echo "Using Azu CLI version: $VERSION"

# In CI/CD
if azu version | grep -q "Azu CLI v0.0.1"; then
  echo "✅ Compatible version detected"
else
  echo "❌ Incompatible version"
  exit 1
fi
```

## Troubleshooting

If the version command fails:

1. **Check installation**: Ensure Azu CLI is properly installed
2. **Check Crystal**: Verify Crystal is installed and in PATH
3. **Check permissions**: Ensure the binary has execute permissions
4. **Reinstall**: Try reinstalling the CLI tool

## Related Commands

- `azu help` - Get help information
- `azu new` - Create a new project
- `azu init` - Initialize an existing project

## Version History

For a complete version history and changelog, see the [Changelog](../appendices/changelog.md) documentation.
