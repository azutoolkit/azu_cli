# Version Command

The `azu version` command displays version information about Azu CLI and its dependencies.

## Overview

```bash
azu version [options]
```

## Basic Usage

```bash
# Show version information
azu version

# Show version with verbose output
azu version --verbose
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--verbose`, `-v` | Show detailed version information | false |

## Examples

### Basic Version Information

```bash
$ azu version
Azu CLI v0.0.1+13
Crystal 1.15.1
Topia CLI Framework

Plugins:
  - Generator Plugin v1.0.0
  - Database Plugin v1.0.0
  - Development Plugin v1.0.0
```

### Verbose Version Information

```bash
$ azu version --verbose
Azu CLI v0.0.1+13
Crystal 1.15.1
Topia CLI Framework

Plugins:
  - Generator Plugin v1.0.0
  - Database Plugin v1.0.0
  - Development Plugin v1.0.0

System Information:
  - OS: macOS 14.0
  - Architecture: arm64
  - Crystal Version: 1.15.1
  - LLVM Version: 16.0.0
```

## Version Information Details

### Azu CLI Version

The version follows semantic versioning (SemVer) format:

- **Major version**: Breaking changes
- **Minor version**: New features (backward compatible)
- **Patch version**: Bug fixes (backward compatible)
- **Build number**: Development builds (e.g., `+13`)

### Crystal Version

Shows the Crystal programming language version used to compile Azu CLI:

- **Version**: Crystal language version
- **LLVM**: Underlying LLVM version
- **Architecture**: Target architecture

### Plugin Versions

Lists all loaded plugins and their versions:

- **Generator Plugin**: Code generation functionality
- **Database Plugin**: Database management commands
- **Development Plugin**: Development server and tools

## Use Cases

### Development Environment

```bash
# Check if you have the latest version
azu version

# Compare with latest release
# Visit: https://github.com/azutoolkit/azu_cli/releases
```

### Troubleshooting

```bash
# Check version compatibility
azu version

# Report version information in bug reports
azu version --verbose > version-info.txt
```

### CI/CD Integration

```bash
# In CI scripts
VERSION=$(azu version | head -1 | cut -d' ' -f3)
echo "Building with Azu CLI $VERSION"
```

## Version Compatibility

### Crystal Version Requirements

Azu CLI requires specific Crystal versions:

| Azu CLI Version | Crystal Version | Notes |
|----------------|-----------------|-------|
| 0.0.1+13 | 1.15.0+ | Current stable |
| 0.0.1+12 | 1.14.0+ | Previous stable |
| 0.0.1+11 | 1.13.0+ | Legacy support |

### Plugin Compatibility

Plugins are versioned independently:

- **Generator Plugin**: Compatible with Azu CLI 0.0.1+
- **Database Plugin**: Compatible with Azu CLI 0.0.1+
- **Development Plugin**: Compatible with Azu CLI 0.0.1+

## Troubleshooting

### Version Mismatch

```bash
# If you see version conflicts
crystal --version
azu version

# Update Crystal if needed
# Follow Crystal installation guide
```

### Plugin Issues

```bash
# Check plugin versions
azu version

# Reinstall plugins if needed
azu plugin install --force
```

### Build Issues

```bash
# Check Crystal version compatibility
crystal --version
azu version

# Rebuild if needed
crystal build src/azu_cli.cr
```

## Integration Examples

### Version Checking Script

```bash
#!/bin/bash
# check-version.sh

CURRENT_VERSION=$(azu version | head -1 | cut -d' ' -f3)
REQUIRED_VERSION="0.0.1+13"

if [ "$CURRENT_VERSION" != "$REQUIRED_VERSION" ]; then
    echo "Version mismatch: $CURRENT_VERSION != $REQUIRED_VERSION"
    exit 1
fi

echo "Version check passed: $CURRENT_VERSION"
```

### CI/CD Version Validation

```yaml
# .github/workflows/version-check.yml
name: Version Check
on: [push, pull_request]

jobs:
  version-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install Crystal
        uses: oprypin/install-crystal@v1
        with:
          crystal-version: 1.15.1
      - name: Install Azu CLI
        run: make install
      - name: Check Version
        run: |
          azu version
          VERSION=$(azu version | head -1 | cut -d' ' -f3)
          echo "Azu CLI version: $VERSION"
```

### Development Environment Setup

```bash
# setup-dev.sh
echo "Setting up development environment..."

# Check Crystal version
crystal --version

# Install Azu CLI
make install

# Verify installation
azu version

echo "Development environment ready!"
```

## Best Practices

### 1. Version Pinning

```bash
# Pin specific version in CI/CD
VERSION="0.0.1+13"
azu version | grep -q "$VERSION" || exit 1
```

### 2. Version Reporting

```bash
# Include version in logs
echo "$(date): Azu CLI $(azu version | head -1)" >> app.log
```

### 3. Compatibility Checking

```bash
# Check compatibility before operations
CRYSTAL_VERSION=$(crystal --version | head -1 | cut -d' ' -f2)
if [[ "$CRYSTAL_VERSION" < "1.15.0" ]]; then
    echo "Crystal version $CRYSTAL_VERSION is not supported"
    exit 1
fi
```

### 4. Version Documentation

```bash
# Document versions in README
echo "## Requirements" >> README.md
echo "- Azu CLI: $(azu version | head -1)" >> README.md
echo "- Crystal: $(crystal --version | head -1)" >> README.md
```

## Related Commands

- [Help Command](help.md) - Get help information
- [Generate Command](generate.md) - Generate code
- [Database Commands](database.md) - Database management
- [Serve Command](serve.md) - Development server

---

The version command is essential for debugging, compatibility checking, and environment validation in Azu CLI applications.

**Next Steps:**

- [Help Command](help.md) - Learn about getting help
- [Installation Guide](../getting-started/installation.md) - Install Azu CLI
- [Quick Start Guide](../getting-started/quick-start.md) - Get started quickly