# azu dev

> **Note**: The `azu dev` command is not currently implemented. Please use [`azu serve`](serve.md) instead.

## Overview

The `azu dev` command was planned as an enhanced development environment with additional tools and features. However, the core development functionality is available through the `azu serve` command.

## Recommended Alternative: azu serve

Use `azu serve` for all development server needs:

```bash
# Start development server
azu serve

# Start on custom port
azu serve --port 4000

# Start with specific environment
azu serve --env development

# Start with verbose output
azu serve --verbose
```

## Available Options in azu serve

| Option      | Description           | Default     |
| ----------- | --------------------- | ----------- |
| `--port`    | Server port           | 4000        |
| `--host`    | Server host           | localhost   |
| `--env`     | Environment           | development |
| `--no-watch`| Disable file watching | false       |
| `--verbose` | Enable verbose output | false       |

## Features Available in azu serve

- Hot reloading with automatic file watching
- Automatic recompilation on file changes
- Detailed error reporting
- Environment configuration
- Verbose mode for debugging

For complete documentation, see [azu serve](serve.md).

---

**See Also:**

- [azu serve](serve.md) - Development server command
- [Development Server Configuration](../configuration/dev-server-config.md) - Server configuration options
