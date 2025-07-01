# Plugin System

The Azu CLI plugin system is built on top of Topia's plugin architecture, providing a powerful and extensible way to add custom functionality to the CLI. Plugins can extend generators, add new commands, modify templates, and integrate with external tools.

## Overview

The plugin system enables:

- **Extensibility**: Add custom functionality without modifying core code
- **Modularity**: Separate concerns and maintain clean architecture
- **Reusability**: Share plugins across projects and teams
- **Integration**: Connect with external tools and services
- **Customization**: Tailor the CLI to specific project needs

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Plugin System                            │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Plugin    │  │   Plugin    │  │   Plugin    │          │
│  │   Registry  │  │   Loader    │  │   Manager   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Generator   │  │   Command   │  │  Template   │          │
│  │  Plugins    │  │   Plugins   │  │   Plugins   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Custom    │  │   External  │  │   Utility   │          │
│  │  Plugins    │  │   Plugins   │  │   Plugins   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│                    Topia Plugin Framework                   │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### Plugin Registry

The plugin registry manages all available plugins:

```crystal
class Azu::Plugin::Registry
  @@plugins = {} of String => Azu::Plugin::Base.class
  @@generators = {} of String => Azu::Plugin::Generator.class
  @@commands = {} of String => Azu::Plugin::Command.class
  @@templates = {} of String => Azu::Plugin::Template.class

  def self.register(plugin_class : Azu::Plugin::Base.class)
    plugin = plugin_class.new
    @@plugins[plugin.name] = plugin_class

    # Register by type
    case plugin
    when .is_a?(Azu::Plugin::Generator)
      @@generators[plugin.name] = plugin.as(Azu::Plugin::Generator)
    when .is_a?(Azu::Plugin::Command)
      @@commands[plugin.name] = plugin.as(Azu::Plugin::Command)
    when .is_a?(Azu::Plugin::Template)
      @@templates[plugin.name] = plugin.as(Azu::Plugin::Template)
    end
  end

  def self.get(name : String) : Azu::Plugin::Base?
    plugin_class = @@plugins[name]?
    return nil unless plugin_class

    plugin_class.new
  end

  def self.generators : Array(String)
    @@generators.keys
  end

  def self.commands : Array(String)
    @@commands.keys
  end

  def self.templates : Array(String)
    @@templates.keys
  end

  def self.available : Array(String)
    @@plugins.keys
  end
end
```

### Plugin Base Class

All plugins inherit from the base plugin class:

```crystal
abstract class Azu::Plugin::Base
  abstract def name : String
  abstract def description : String
  abstract def version : String

  def initialize
    register_hooks
  end

  # Lifecycle hooks
  def on_load
    # Called when plugin is loaded
  end

  def on_unload
    # Called when plugin is unloaded
  end

  def on_command(command : String, args : Array(String))
    # Called before command execution
  end

  def on_generation(generator_type : String, name : String, options : Hash(String, String))
    # Called before code generation
  end

  protected def register_hooks
    # Override to register custom hooks
  end

  protected def log(message : String, level : String = "info")
    Azu::Logger.send(level, "[#{name}] #{message}")
  end
end
```

### Plugin Loader

The plugin loader discovers and loads plugins:

```crystal
class Azu::Plugin::Loader
  getter plugin_paths : Array(String)

  def initialize
    @plugin_paths = [
      "plugins/",
      "~/.azu/plugins/",
      "/usr/local/share/azu/plugins/"
    ]
  end

  def load_plugins
    @plugin_paths.each do |path|
      load_plugins_from_path(path)
    end
  end

  private def load_plugins_from_path(path : String)
    return unless Dir.exists?(path)

    Dir.each_child(path) do |entry|
      plugin_path = File.join(path, entry)
      next unless Dir.exists?(plugin_path)

      load_plugin(plugin_path)
    end
  end

  private def load_plugin(plugin_path : String)
    # Look for plugin manifest
    manifest_path = File.join(plugin_path, "plugin.yml")
    return unless File.exists?(manifest_path)

    manifest = YAML.parse(File.read(manifest_path))

    # Load main plugin file
    main_file = File.join(plugin_path, manifest["main"].as_s)
    return unless File.exists?(main_file)

    # Compile and load plugin
    load_plugin_file(main_file, manifest)
  rescue ex
    Azu::Logger.error("Failed to load plugin from #{plugin_path}: #{ex.message}")
  end

  private def load_plugin_file(file_path : String, manifest : YAML::Any)
    # In a real implementation, this would compile and load the plugin
    # For now, we'll simulate plugin loading
    Azu::Logger.info("Loading plugin: #{manifest["name"]}")
  end
end
```

## Plugin Types

### Generator Plugins

Generator plugins extend the code generation system:

```crystal
class Azu::Plugin::Generator < Azu::Plugin::Base
  abstract def generate(name : String, options : Hash(String, String))
  abstract def template_path : String

  def on_generation(generator_type : String, name : String, options : Hash(String, String))
    return unless generator_type == self.name

    log("Generating #{name} with options: #{options}")
    generate(name, options)
  end

  protected def create_file(path : String, content : String)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    log("Created: #{path}")
  end

  protected def render_template(context : Hash(String, String)) : String
    ECR.render(template_path, context)
  end
end

# Example: API Documentation Generator Plugin
class ApiDocGenerator < Azu::Plugin::Generator
  def name : String
    "api_doc"
  end

  def description : String
    "Generate API documentation from endpoints"
  end

  def version : String
    "1.0.0"
  end

  def generate(name : String, options : Hash(String, String))
    # Generate API documentation
    context = {
      "name" => name,
      "format" => options["format"]? || "markdown"
    }

    content = render_template(context)
    create_file("docs/api/#{name.underscore}.md", content)
  end

  def template_path : String
    "plugins/api_doc/templates/api_doc.md.ecr"
  end
end
```

### Command Plugins

Command plugins add new CLI commands:

```crystal
class Azu::Plugin::Command < Azu::Plugin::Base
  abstract def execute(args : Array(String))
  abstract def help : String

  def on_command(command : String, args : Array(String))
    return unless command == self.name

    log("Executing command with args: #{args}")
    execute(args)
  end
end

# Example: Database Backup Plugin
class DatabaseBackupCommand < Azu::Plugin::Command
  def name : String
    "db:backup"
  end

  def description : String
    "Backup database to file"
  end

  def version : String
    "1.0.0"
  end

  def execute(args : Array(String))
    config = Azu::Config.current
    backup_path = args.first? || "backup_#{Time.utc.to_unix}.sql"

    log("Creating database backup: #{backup_path}")

    # Execute backup command
    system("pg_dump #{config.database.connection_string} > #{backup_path}")

    log("Backup completed: #{backup_path}")
  end

  def help : String
    "Usage: azu db:backup [filename]\n\nCreates a database backup file."
  end
end
```

### Template Plugins

Template plugins modify or add new templates:

```crystal
class Azu::Plugin::Template < Azu::Plugin::Base
  abstract def modify_template(template_name : String, content : String) : String
  abstract def add_template(template_name : String) : String?

  def on_generation(generator_type : String, name : String, options : Hash(String, String))
    # Modify existing templates or add new ones
    if new_template = add_template("#{generator_type}_#{name}")
      log("Added custom template for #{generator_type} #{name}")
    end
  end
end

# Example: TypeScript Template Plugin
class TypeScriptTemplate < Azu::Plugin::Template
  def name : String
    "typescript"
  end

  def description : String
    "Add TypeScript support to generated code"
  end

  def version : String
    "1.0.0"
  end

  def modify_template(template_name : String, content : String) : String
    case template_name
    when "model"
      add_typescript_types(content)
    when "endpoint"
      add_typescript_interfaces(content)
    else
      content
    end
  end

  def add_template(template_name : String) : String?
    case template_name
    when "typescript_config"
      File.read("plugins/typescript/templates/tsconfig.json.ecr")
    else
      nil
    end
  end

  private def add_typescript_types(content : String) : String
    # Add TypeScript type definitions to model
    content.gsub(/class (\w+) < CQL::Model/, "class \\1 < CQL::Model\n  # TypeScript types\n  interface \\1Type {\n    id: number\n    // Add other properties\n  }")
  end

  private def add_typescript_interfaces(content : String) : String
    # Add TypeScript interfaces to endpoints
    content.gsub(/class (\w+)Endpoint/, "class \\1Endpoint\n  # TypeScript interfaces\n  interface \\1Request {\n    // Request properties\n  }\n\n  interface \\1Response {\n    // Response properties\n  }")
  end
end
```

## Plugin Development

### Plugin Structure

A typical plugin has the following structure:

```
plugins/my_plugin/
├── plugin.yml              # Plugin manifest
├── src/
│   └── my_plugin.cr        # Main plugin code
├── templates/
│   └── template.ecr        # Plugin templates
├── spec/
│   └── my_plugin_spec.cr   # Plugin tests
├── README.md               # Plugin documentation
└── shard.yml               # Plugin dependencies
```

### Plugin Manifest

The plugin manifest defines plugin metadata:

```yaml
# plugins/my_plugin/plugin.yml
name: my_plugin
version: 1.0.0
description: A custom plugin for Azu CLI
author: Your Name
email: your.email@example.com
main: src/my_plugin.cr
type: generator
dependencies:
  - crystal: ">= 1.0.0"
  - azu_cli: ">= 0.1.0"
hooks:
  - on_generation
  - on_command
templates:
  - my_template.ecr
```

### Plugin Implementation

```crystal
# plugins/my_plugin/src/my_plugin.cr
require "azu_cli"

class MyPlugin < Azu::Plugin::Generator
  def name : String
    "my_plugin"
  end

  def description : String
    "A custom plugin for Azu CLI"
  end

  def version : String
    "1.0.0"
  end

  def generate(name : String, options : Hash(String, String))
    log("Generating with MyPlugin")

    context = {
      "name" => name,
      "options" => options.to_json
    }

    content = render_template(context)
    create_file("src/generated/#{name.underscore}.cr", content)
  end

  def template_path : String
    File.join(__DIR__, "../templates/template.ecr")
  end

  protected def register_hooks
    # Register custom hooks
    Azu::Plugin::Registry.register_hook("on_generation", self)
  end
end

# Register the plugin
Azu::Plugin::Registry.register(MyPlugin)
```

## Plugin Integration

### Command Integration

Plugins can integrate with existing commands:

```crystal
class Azu::Commands::Generate < Azu::Commands::Base
  def call
    # Execute core generation
    generator = Azu::Generators::Registry.create(@name, @generator_type, @options)
    generator.generate

    # Execute plugin hooks
    Azu::Plugin::Registry.plugins.each do |plugin|
      plugin.on_generation(@generator_type, @name, @options)
    end
  end
end
```

### Configuration Integration

Plugins can extend the configuration system:

```crystal
class Azu::Config::PluginConfig
  getter plugins : Hash(String, Hash(String, Any))

  def initialize(config : Hash(String, Any))
    @plugins = config["plugins"]?.try(&.as_h) || {} of String => Any
  end

  def plugin_config(plugin_name : String) : Hash(String, Any)?
    @plugins[plugin_name]?.try(&.as_h)
  end
end

# In configuration file
plugins:
  my_plugin:
    enabled: true
    options:
      custom_option: "value"
```

## Plugin Management

### Plugin Commands

Azu CLI provides commands for managing plugins:

```crystal
class Azu::Commands::Plugin < Azu::Commands::Base
  def call
    case @subcommand
    when "list"
      list_plugins
    when "install"
      install_plugin(@name)
    when "uninstall"
      uninstall_plugin(@name)
    when "update"
      update_plugin(@name)
    when "info"
      show_plugin_info(@name)
    else
      show_help
    end
  end

  private def list_plugins
    puts "Installed Plugins:"
    puts ""

    Azu::Plugin::Registry.available.each do |name|
      plugin = Azu::Plugin::Registry.get(name)
      next unless plugin

      puts "  #{name} (#{plugin.version})"
      puts "    #{plugin.description}"
      puts ""
    end
  end

  private def install_plugin(name : String)
    Azu::Logger.info("Installing plugin: #{name}")
    # Plugin installation logic
  end

  private def uninstall_plugin(name : String)
    Azu::Logger.info("Uninstalling plugin: #{name}")
    # Plugin uninstallation logic
  end

  private def update_plugin(name : String)
    Azu::Logger.info("Updating plugin: #{name}")
    # Plugin update logic
  end

  private def show_plugin_info(name : String)
    plugin = Azu::Plugin::Registry.get(name)
    return Azu::Logger.error("Plugin not found: #{name}") unless plugin

    puts "Plugin: #{name}"
    puts "Version: #{plugin.version}"
    puts "Description: #{plugin.description}"
  end
end
```

## Best Practices

### Plugin Design

1. **Single Responsibility**: Each plugin should have one clear purpose
2. **Dependency Management**: Minimize dependencies and document them
3. **Error Handling**: Handle errors gracefully and provide meaningful messages
4. **Documentation**: Provide clear documentation for plugin usage

### Performance

1. **Lazy Loading**: Load plugins only when needed
2. **Caching**: Cache plugin results when appropriate
3. **Resource Management**: Clean up resources when plugins are unloaded
4. **Async Operations**: Use async operations for long-running tasks

### Security

1. **Input Validation**: Validate all plugin inputs
2. **File Operations**: Use safe file operations and path validation
3. **Code Execution**: Be careful with dynamic code execution
4. **Access Control**: Limit plugin access to sensitive operations

### Testing

1. **Unit Tests**: Write tests for plugin functionality
2. **Integration Tests**: Test plugin integration with Azu CLI
3. **Mocking**: Use mocks for external dependencies
4. **Coverage**: Maintain good test coverage

## Related Documentation

- [CLI Framework (Topia)](cli-framework.md) - Command-line interface framework
- [Generator System](generator-system.md) - Code generation architecture
- [Template Engine (ECR)](template-engine.md) - Template system
- [Configuration System](configuration.md) - Configuration management
- [Commands Reference](../commands/README.md) - Command documentation
