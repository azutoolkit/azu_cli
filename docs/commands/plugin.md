# Plugin Command

Manage Azu CLI plugins to extend functionality with custom commands and generators.

## Synopsis

```bash
azu plugin <operation> [arguments] [options]
```

## Description

The plugin command provides functionality to list, install, uninstall, enable, disable, and inspect plugins for the Azu CLI. Plugins allow you to extend the CLI with custom commands, generators, and functionality specific to your workflow or organization.

## Operations

### `azu plugin list`

Display all installed plugins.

#### Synopsis

```bash
azu plugin list
```

#### Description

Lists all available plugins, including both built-in plugins that ship with Azu CLI and any external plugins you've installed.

#### Example Output

```
Installed plugins:

Built-in plugins:
  generator    - Code generation plugin
  database     - Database operations plugin
  development  - Development server plugin

External plugins:
  custom-auth  - Custom authentication plugin (v1.2.0)
  analytics    - Analytics integration plugin (v0.5.0)
```

#### Examples

```bash
# List all plugins
azu plugin list
```

---

### `azu plugin install`

Install a plugin from a repository or local path.

#### Synopsis

```bash
azu plugin install <name> [options]
```

#### Description

Downloads and installs a plugin, making it available for use with the Azu CLI. Plugins can be installed from:

- Official Azu plugin registry
- GitHub repositories
- Local file paths

#### Arguments

| Argument | Description                   |
| -------- | ----------------------------- |
| `<name>` | Plugin name or repository URL |

#### Options

| Option                | Description                                  |
| --------------------- | -------------------------------------------- |
| `--source <url>`      | Plugin source URL                            |
| `--version <version>` | Specific version to install                  |
| `--local <path>`      | Install from local directory                 |
| `--global`            | Install globally (available to all projects) |

#### Examples

```bash
# Install plugin from registry
azu plugin install custom-validator

# Install from GitHub
azu plugin install https://github.com/username/azu-plugin-name

# Install specific version
azu plugin install analytics --version 0.5.0

# Install from local directory
azu plugin install --local ~/my-plugins/custom-generator

# Install globally
azu plugin install monitoring --global
```

#### Plugin Structure

Plugins should follow this structure:

```
my-plugin/
├── shard.yml
├── src/
│   └── my_plugin/
│       ├── commands/
│       │   └── custom_command.cr
│       ├── generators/
│       │   └── custom_generator.cr
│       └── plugin.cr
└── README.md
```

#### Plugin Definition

```crystal
# src/my_plugin/plugin.cr
require "topia/plugin"

module MyPlugin
  class Plugin < Topia::Plugin
    name "my-plugin"
    version "1.0.0"
    description "Custom plugin functionality"

    def setup
      register_command Commands::CustomCommand
      register_generator Generators::CustomGenerator
    end
  end
end
```

---

### `azu plugin uninstall`

Remove an installed plugin.

#### Synopsis

```bash
azu plugin uninstall <name>
```

#### Description

Removes a plugin from your system, cleaning up all associated files and configuration.

#### Arguments

| Argument | Description                     |
| -------- | ------------------------------- |
| `<name>` | Name of the plugin to uninstall |

#### Examples

```bash
# Uninstall plugin
azu plugin uninstall analytics

# Uninstall with confirmation
azu plugin uninstall custom-auth --force
```

#### Safety

- Built-in plugins cannot be uninstalled
- Confirmation prompt shown before removal
- Backup created automatically

---

### `azu plugin enable`

Enable a previously disabled plugin.

#### Synopsis

```bash
azu plugin enable <name>
```

#### Description

Activates a plugin that was previously disabled, making its commands and features available again.

#### Arguments

| Argument | Description                  |
| -------- | ---------------------------- |
| `<name>` | Name of the plugin to enable |

#### Examples

```bash
# Enable plugin
azu plugin enable analytics

# Enable multiple plugins
azu plugin enable plugin1 plugin2 plugin3
```

---

### `azu plugin disable`

Temporarily disable a plugin without uninstalling it.

#### Synopsis

```bash
azu plugin disable <name>
```

#### Description

Deactivates a plugin while keeping it installed. Disabled plugins do not load their commands or run initialization code.

#### Arguments

| Argument | Description                   |
| -------- | ----------------------------- |
| `<name>` | Name of the plugin to disable |

#### Examples

```bash
# Disable plugin
azu plugin disable analytics

# Disable for troubleshooting
azu plugin disable problematic-plugin
```

#### Use Cases

- Troubleshooting plugin conflicts
- Temporarily removing functionality
- Testing without plugins
- Development and debugging

---

### `azu plugin info`

Display detailed information about a plugin.

#### Synopsis

```bash
azu plugin info <name>
```

#### Description

Shows comprehensive information about a specific plugin, including version, description, status, dependencies, and provided commands.

#### Arguments

| Argument | Description                   |
| -------- | ----------------------------- |
| `<name>` | Name of the plugin to inspect |

#### Example Output

```
Plugin information for: analytics

Name: analytics
Version: 0.5.0
Status: enabled
Type: external
Author: Analytics Team
License: MIT

Description:
  Integrates application analytics with external tracking services.
  Provides commands for tracking events, users, and custom metrics.

Dependencies:
  - http_client >= 1.0.0
  - json >= 1.0.0

Commands:
  analytics:setup    - Configure analytics integration
  analytics:track    - Send tracking event
  analytics:report   - Generate analytics report

Generators:
  analytics:event    - Generate analytics event tracker

Installation Path:
  /usr/local/lib/azu/plugins/analytics

Repository:
  https://github.com/analytics-team/azu-plugin-analytics
```

#### Examples

```bash
# Show plugin information
azu plugin info analytics

# Check built-in plugin details
azu plugin info generator
```

---

## Built-in Plugins

Azu CLI ships with several built-in plugins:

### Generator Plugin

**Name:** `generator`
**Description:** Code generation plugin for Azu CLI

Provides all code generation commands:

- `azu generate model`
- `azu generate endpoint`
- `azu generate scaffold`
- And more...

### Database Plugin

**Name:** `database`
**Description:** Database operations plugin for Azu CLI

Provides database management commands:

- `azu db:create`
- `azu db:migrate`
- `azu db:rollback`
- And more...

### Development Plugin

**Name:** `development`
**Description:** Development server plugin for Azu CLI

Provides development tools:

- `azu serve`
- `azu test --watch`
- Hot reloading functionality

---

## Creating Custom Plugins

### Plugin Template

```crystal
# shard.yml
name: my-plugin
version: 1.0.0

dependencies:
  topia:
    github: azutoolkit/topia
  azu_cli:
    github: azutoolkit/azu_cli

# src/my_plugin.cr
require "topia/plugin"
require "./my_plugin/**"

module MyPlugin
  class Plugin < Topia::Plugin
    name "my-plugin"
    version "1.0.0"
    description "My custom plugin"
    author "Your Name"
    license "MIT"

    def setup
      # Register commands
      register_command Commands::MyCommand

      # Register generators
      register_generator Generators::MyGenerator

      # Run initialization code
      configure_plugin
    end

    private def configure_plugin
      # Plugin configuration
    end
  end
end
```

### Custom Command Example

```crystal
# src/my_plugin/commands/my_command.cr
require "azu_cli/commands/base"

module MyPlugin
  module Commands
    class MyCommand < AzuCLI::Commands::Base
      def initialize
        super("my:command", "Description of my command")
      end

      def execute : Result
        Logger.info("Executing my custom command")

        # Command implementation

        success("Command completed")
      end

      def show_help
        puts "Usage: azu my:command [options]"
        puts ""
        puts "Description:"
        puts "  My custom command implementation"
        puts ""
        puts "Options:"
        puts "  --option <value>    Custom option"
      end
    end
  end
end
```

### Custom Generator Example

```crystal
# src/my_plugin/generators/my_generator.cr
require "teeplate"

module MyPlugin
  module Generators
    class MyGenerator < Teeplate::FileTree
      directory "#{__DIR__}/templates"

      @name : String

      def initialize(@name)
      end

      def snake_case_name
        @name.underscore
      end

      def camel_case_name
        @name.camelcase
      end
    end
  end
end
```

---

## Plugin Configuration

### Global Configuration

Plugins can be configured globally in `~/.azu/config.yml`:

```yaml
plugins:
  enabled:
    - generator
    - database
    - development
    - my-plugin

  disabled:
    - experimental-plugin

  settings:
    my-plugin:
      option1: value1
      option2: value2
```

### Project Configuration

Project-specific plugin settings in `.azu/config.yml`:

```yaml
plugins:
  my-plugin:
    enabled: true
    options:
      project_specific: true
      custom_setting: value
```

---

## Best Practices

### 1. Follow Naming Conventions

```crystal
# Good plugin names
azu-plugin-analytics
azu-plugin-custom-auth
azu-plugin-deployment

# Bad plugin names
my_plugin
custom
tool
```

### 2. Provide Comprehensive Documentation

Include:

- README with installation instructions
- Command documentation
- Configuration examples
- Troubleshooting guide

### 3. Version Your Plugin

Use semantic versioning:

```crystal
version "1.2.3"
#        │ │ └─ Patch: Bug fixes
#        │ └─── Minor: New features (backward compatible)
#        └───── Major: Breaking changes
```

### 4. Test Thoroughly

```crystal
# spec/my_plugin/commands/my_command_spec.cr
require "../../spec_helper"

describe MyPlugin::Commands::MyCommand do
  it "executes successfully" do
    command = MyPlugin::Commands::MyCommand.new
    result = command.execute
    result.should be_successful
  end
end
```

### 5. Handle Dependencies Gracefully

```crystal
def setup
  unless system_has_redis?
    Logger.warn("Redis not found - some features disabled")
    return
  end

  register_command Commands::RedisCommand
end
```

---

## Troubleshooting

### Plugin Not Loading

Check plugin is enabled:

```bash
azu plugin list
```

Enable if disabled:

```bash
azu plugin enable my-plugin
```

### Command Not Found

Verify plugin provides the command:

```bash
azu plugin info my-plugin
```

Check plugin is properly registered:

```crystal
# In plugin.cr
def setup
  register_command Commands::MyCommand  # Ensure this line exists
end
```

### Version Conflicts

Check installed versions:

```bash
azu plugin info my-plugin
```

Update to compatible version:

```bash
azu plugin uninstall my-plugin
azu plugin install my-plugin --version 2.0.0
```

### Plugin Installation Fails

Check dependencies:

```bash
# Verify Crystal version
crystal --version

# Check Azu CLI version
azu version
```

Install dependencies:

```bash
cd /path/to/plugin
shards install
```

---

## Plugin Registry

### Official Plugins

Visit the official plugin registry:

```
https://plugins.azutoolkit.org
```

### Community Plugins

Browse community-contributed plugins:

```bash
# Search for plugins
azu plugin search <keyword>

# Show popular plugins
azu plugin popular

# Show recently updated
azu plugin recent
```

---

## Environment Variables

| Variable              | Description                                | Default           |
| --------------------- | ------------------------------------------ | ----------------- |
| `AZU_PLUGINS_DIR`     | Plugin installation directory              | `~/.azu/plugins`  |
| `AZU_DISABLE_PLUGINS` | Comma-separated list of plugins to disable |                   |
| `AZU_PLUGIN_REGISTRY` | Custom plugin registry URL                 | Official registry |

---

## Related Commands

- [`azu help`](help.md) - Show help including plugin commands
- [`azu version`](version.md) - Show version including plugin versions

## See Also

- [Plugin Development Guide](../guides/plugin-development.md)
- [Topia Plugin API](https://github.com/azutoolkit/topia)
- [Plugin Registry](https://plugins.azutoolkit.org)
