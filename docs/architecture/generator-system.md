# Generator System

The Azu CLI generator system is responsible for creating new files, code structures, and project scaffolding. It provides a flexible, extensible framework for code generation using templates and dynamic content.

## Overview

The generator system follows a modular architecture that separates concerns between different types of generators while sharing common functionality through a base generator class. Each generator is responsible for creating specific types of files and follows consistent patterns.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Generator System                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Base Gen.   │  │ Model Gen.  │  │ Endpoint Gen│          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Service Gen│  │ Page Gen.   │  │ Contract Gen│          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Middleware  │  │ Component   │  │ Validator   │          │
│  │ Generator   │  │ Generator   │  │ Generator   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
├─────────────────────────────────────────────────────────────┤
│                    Template Engine (ECR)                    │
├─────────────────────────────────────────────────────────────┤
│                    File System                              │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### Base Generator

All generators inherit from the base generator class, which provides common functionality:

```crystal
abstract class Azu::Generators::Base
  getter name : String
  getter options : Hash(String, String)
  getter attributes : Array(Attribute)

  def initialize(@name : String, @options : Hash(String, String) = {} of String => String)
    @attributes = parse_attributes(@options["attributes"]? || "")
  end

  # Abstract methods that must be implemented by subclasses
  abstract def generate
  abstract def template_path : String
  abstract def output_path : String

  # Common functionality
  def render_template(context : Hash(String, String)) : String
    ECR.render(template_path, context)
  end

  def create_file(path : String, content : String)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    Azu::Logger.info("Created: #{path}")
  end

  def template_context : Hash(String, String)
    {
      "name" => @name,
      "name_camelcase" => @name.camelcase,
      "name_underscore" => @name.underscore,
      "name_pluralize" => @name.pluralize,
      "name_humanize" => @name.humanize,
      "attributes" => @attributes.to_json,
      "description" => @options["description"]? || "",
      "template" => self.class.name.underscore,
      "options" => @options.to_json
    }
  end

  private def parse_attributes(attributes_string : String) : Array(Attribute)
    return [] of Attribute if attributes_string.empty?

    attributes_string.split(",").map do |attr|
      name, type = attr.strip.split(":")
      Attribute.new(name, type || "string")
    end
  end
end
```

### Attribute System

The generator system includes a flexible attribute system for defining model fields:

```crystal
class Azu::Generators::Attribute
  getter name : String
  getter type : String
  getter options : Hash(String, String)

  def initialize(@name : String, @type : String, @options : Hash(String, String) = {} of String => String)
  end

  def column_type : String
    case @type.downcase
    when "string", "str"
      "String"
    when "integer", "int"
      "Int32"
    when "bigint", "int64"
      "Int64"
    when "float"
      "Float32"
    when "double", "decimal"
      "Float64"
    when "boolean", "bool"
      "Bool"
    when "text"
      "String"
    when "datetime", "timestamp"
      "Time"
    when "date"
      "Date"
    when "json"
      "JSON::Any"
    else
      "String"
    end
  end

  def validation_rules : Array(String)
    rules = [] of String

    case @type.downcase
    when "string", "str"
      rules << "presence: true"
      rules << "length: {minimum: 2}" if @name.includes?("name")
    when "integer", "int", "bigint", "int64"
      rules << "presence: true"
      rules << "numericality: {greater_than: 0}" if @name.includes?("id")
    when "email"
      rules << "presence: true"
      rules << "format: /^[^@]+@[^@]+\\.[^@]+$/"
    end

    rules
  end
end
```

## Generator Types

### Model Generator

Creates CQL ORM models with proper structure and validations:

```crystal
class Azu::Generators::Model < Azu::Generators::Base
  def generate
    create_model_file
    create_spec_file unless @options["skip_tests"]? == "true"
  end

  def template_path : String
    "src/templates/generators/model/model.cr.ecr"
  end

  def output_path : String
    "src/models/#{@name.underscore}.cr"
  end

  private def create_model_file
    content = render_template(template_context)
    create_file(output_path, content)
  end

  private def create_spec_file
    spec_content = render_template(spec_template_context)
    spec_path = "spec/models/#{@name.underscore}_spec.cr"
    create_file(spec_path, spec_content)
  end

  private def spec_template_path : String
    "src/templates/generators/model/model_spec.cr.ecr"
  end

  private def spec_template_context : Hash(String, String)
    template_context.merge({
      "spec_class" => "#{@name.camelcase}Spec"
    })
  end
end
```

### Endpoint Generator

Creates HTTP endpoints with contracts and pages:

```crystal
class Azu::Generators::Endpoint < Azu::Generators::Base
  getter actions : Array(String)

  def initialize(@name : String, @options : Hash(String, String) = {} of String => String)
    super
    @actions = parse_actions(@options["actions"]? || "index,show,create,update,destroy")
  end

  def generate
    create_endpoint_files
    create_contract_files
    create_page_files
    create_spec_files unless @options["skip_tests"]? == "true"
  end

  def template_path : String
    "src/templates/generators/endpoint/endpoint.cr.ecr"
  end

  def output_path : String
    "src/endpoints/#{@name.underscore.pluralize}/"
  end

  private def create_endpoint_files
    @actions.each do |action|
      create_endpoint_file(action)
    end
  end

  private def create_endpoint_file(action : String)
    template_file = "src/templates/generators/endpoint/#{action}_endpoint.cr.ecr"
    output_file = "#{output_path}#{action}_endpoint.cr"

    context = template_context.merge({
      "action" => action,
      "action_camelcase" => action.camelcase
    })

    content = ECR.render(template_file, context)
    create_file(output_file, content)
  end

  private def parse_actions(actions_string : String) : Array(String)
    actions_string.split(",").map(&.strip)
  end
end
```

### Service Generator

Creates domain services for business logic:

```crystal
class Azu::Generators::Service < Azu::Generators::Base
  def generate
    create_service_file
    create_spec_file unless @options["skip_tests"]? == "true"
  end

  def template_path : String
    "src/templates/generators/service/service.cr.ecr"
  end

  def output_path : String
    "src/services/#{@name.underscore}_service.cr"
  end

  private def create_service_file
    content = render_template(template_context)
    create_file(output_path, content)
  end

  private def create_spec_file
    spec_content = render_template(spec_template_context)
    spec_path = "spec/services/#{@name.underscore}_service_spec.cr"
    create_file(spec_path, spec_content)
  end

  private def spec_template_path : String
    "src/templates/generators/service/service_spec.cr.ecr"
  end
end
```

### Component Generator

Creates interactive UI components with real-time features:

```crystal
class Azu::Generators::Component < Azu::Generators::Base
  getter events : Array(String)
  getter websocket : Bool

  def initialize(@name : String, @options : Hash(String, String) = {} of String => String)
    super
    @events = parse_events(@options["events"]? || "")
    @websocket = @options["websocket"]? == "true"
  end

  def generate
    create_component_file
    create_template_file
    create_spec_file unless @options["skip_tests"]? == "true"
  end

  def template_path : String
    "src/templates/generators/component/component.cr.ecr"
  end

  def output_path : String
    "src/components/#{@name.underscore}_component.cr"
  end

  private def create_component_file
    content = render_template(template_context)
    create_file(output_path, content)
  end

  private def create_template_file
    template_content = render_template(template_template_context)
    template_path = "src/templates/components/#{@name.underscore}.jinja.ecr"
    create_file(template_path, template_content)
  end

  private def parse_events(events_string : String) : Array(String)
    return [] of String if events_string.empty?
    events_string.split(",").map(&.strip)
  end
end
```

### Validator Generator

Creates custom CQL validators:

```crystal
class Azu::Generators::Validator < Azu::Generators::Base
  getter validator_type : String
  getter model_name : String?

  def initialize(@name : String, @options : Hash(String, String) = {} of String => String)
    super
    @validator_type = @options["type"]? || "custom"
    @model_name = @options["model"]?
  end

  def generate
    create_validator_file
    create_spec_file unless @options["skip_tests"]? == "true"
  end

  def template_path : String
    "src/templates/generators/validator/validator.cr.ecr"
  end

  def output_path : String
    "src/validators/#{@name.underscore}_validator.cr"
  end

  private def create_validator_file
    content = render_template(template_context)
    create_file(output_path, content)
  end
end
```

## Template System

### ECR Templates

The generator system uses Crystal's ECR (Embedded Crystal) for template rendering:

```crystal
# Model template example
class <%= @name_camelcase %> < CQL::Model
  table :<%= @name_underscore.pluralize %>

  <% @attributes.each do |attr| %>
  column :<%= attr.name %>, <%= attr.column_type %>
  <% end %>

  timestamps

  <% @attributes.each do |attr| %>
  <% attr.validation_rules.each do |rule| %>
  validates :<%= attr.name %>, <%= rule %>
  <% end %>
  <% end %>
end
```

### Template Variables

Templates have access to a rich set of variables:

```crystal
# Common template variables
@name                               # Resource name (e.g., "user")
@name_camelcase                     # CamelCase (e.g., "User")
@name_underscore                    # snake_case (e.g., "user")
@name_pluralize                     # Plural form (e.g., "users")
@name_humanize                      # Human readable (e.g., "User")

# Generator-specific variables
@attributes                         # Array of attributes
@description                        # Resource description
@template                          # Template type
@options                           # Generator options
@actions                           # Array of actions (for endpoints)
@events                            # Array of events (for components)
@validator_type                    # Validator type
@model_name                        # Associated model name
```

### Template Organization

Templates are organized by generator type:

```
src/templates/generators/
├── model/
│   ├── model.cr.ecr
│   └── model_spec.cr.ecr
├── endpoint/
│   ├── index_endpoint.cr.ecr
│   ├── show_endpoint.cr.ecr
│   ├── create_endpoint.cr.ecr
│   ├── update_endpoint.cr.ecr
│   ├── destroy_endpoint.cr.ecr
│   └── endpoint_spec.cr.ecr
├── service/
│   ├── service.cr.ecr
│   └── service_spec.cr.ecr
├── component/
│   ├── component.cr.ecr
│   └── component_spec.cr.ecr
├── validator/
│   ├── validator.cr.ecr
│   └── validator_spec.cr.ecr
└── middleware/
    ├── middleware.cr.ecr
    └── middleware_spec.cr.ecr
```

## Generator Registry

The generator system includes a registry for managing available generators:

```crystal
class Azu::Generators::Registry
  @@generators = {} of String => Azu::Generators::Base.class

  def self.register(name : String, generator_class : Azu::Generators::Base.class)
    @@generators[name] = generator_class
  end

  def self.get(name : String) : Azu::Generators::Base.class?
    @@generators[name]?
  end

  def self.available : Array(String)
    @@generators.keys
  end

  def self.create(name : String, generator_type : String, options : Hash(String, String)) : Azu::Generators::Base
    generator_class = get(generator_type)
    raise ArgumentError.new("Unknown generator: #{generator_type}") unless generator_class

    generator_class.new(name, options)
  end
end

# Register generators
Azu::Generators::Registry.register("model", Azu::Generators::Model)
Azu::Generators::Registry.register("endpoint", Azu::Generators::Endpoint)
Azu::Generators::Registry.register("service", Azu::Generators::Service)
Azu::Generators::Registry.register("component", Azu::Generators::Component)
Azu::Generators::Registry.register("validator", Azu::Generators::Validator)
Azu::Generators::Registry.register("middleware", Azu::Generators::Middleware)
```

## Command Integration

### Generate Command

The generate command orchestrates the generator system:

```crystal
class Azu::Commands::Generate < Azu::Commands::Base
  getter generator_type : String
  getter name : String
  getter options : Hash(String, String)

  def initialize(@generator_type : String, @name : String, @options : Hash(String, String) = {} of String => String)
  end

  def call
    Azu::Logger.info("Generating #{@generator_type}: #{@name}")

    generator = Azu::Generators::Registry.create(@name, @generator_type, @options)
    generator.generate

    Azu::Logger.info("Generated #{@generator_type} successfully")
  rescue ex : ArgumentError
    Azu::Logger.error("Generator error: #{ex.message}")
    show_available_generators
  rescue ex : Exception
    Azu::Logger.error("Generation failed: #{ex.message}")
    Azu::Logger.debug(ex.backtrace.join("\n"))
  end

  private def show_available_generators
    Azu::Logger.info("Available generators:")
    Azu::Generators::Registry.available.each do |generator|
      Azu::Logger.info("  - #{generator}")
    end
  end
end
```

## Error Handling

### Validation

The generator system includes comprehensive validation:

```crystal
class Azu::Generators::Validator
  def validate_name(name : String)
    unless name.match(/^[a-zA-Z][a-zA-Z0-9_]*$/)
      raise ArgumentError.new("Invalid name: #{name}. Must start with a letter and contain only letters, numbers, and underscores.")
    end
  end

  def validate_attributes(attributes : Array(Attribute))
    attributes.each do |attr|
      validate_attribute(attr)
    end
  end

  def validate_attribute(attr : Attribute)
    unless attr.name.match(/^[a-z][a-z0-9_]*$/)
      raise ArgumentError.new("Invalid attribute name: #{attr.name}. Must be snake_case.")
    end
  end
end
```

### File Safety

The generator system ensures safe file operations:

```crystal
class Azu::Generators::FileManager
  def self.safe_create_file(path : String, content : String, force : Bool = false)
    if File.exists?(path) && !force
      raise FileExistsError.new("File already exists: #{path}. Use --force to overwrite.")
    end

    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
  end

  def self.backup_file(path : String)
    return unless File.exists?(path)

    backup_path = "#{path}.backup.#{Time.utc.to_unix}"
    File.copy(path, backup_path)
    Azu::Logger.info("Backed up: #{path} -> #{backup_path}")
  end
end
```

## Performance Considerations

### Template Caching

Templates are cached for better performance:

```crystal
class Azu::Generators::TemplateCache
  @@cache = {} of String => String

  def self.get(template_path : String) : String
    @@cache[template_path]? || load_template(template_path)
  end

  private def self.load_template(template_path : String) : String
    content = File.read(template_path)
    @@cache[template_path] = content
    content
  end

  def self.clear
    @@cache.clear
  end
end
```

### Batch Operations

The generator system supports batch operations for multiple files:

```crystal
class Azu::Generators::BatchGenerator
  def self.generate_multiple(generators : Array(Azu::Generators::Base))
    generators.each do |generator|
      spawn do
        generator.generate
      end
    end
  end
end
```

## Extensibility

### Custom Generators

Users can create custom generators by extending the base class:

```crystal
class CustomGenerator < Azu::Generators::Base
  def generate
    # Custom generation logic
    create_custom_files
  end

  def template_path : String
    "src/templates/custom/custom.cr.ecr"
  end

  def output_path : String
    "src/custom/#{@name.underscore}.cr"
  end

  private def create_custom_files
    # Implementation
  end
end

# Register custom generator
Azu::Generators::Registry.register("custom", CustomGenerator)
```

### Template Customization

Users can customize templates by creating their own template files:

```crystal
# Override default model template
class Azu::Generators::Model < Azu::Generators::Base
  def template_path : String
    # Check for custom template first
    custom_path = "templates/generators/model/model.cr.ecr"
    return custom_path if File.exists?(custom_path)

    # Fall back to default
    "src/templates/generators/model/model.cr.ecr"
  end
end
```

## Best Practices

### Generator Design

1. **Single Responsibility**: Each generator should have one clear purpose
2. **Consistent Interface**: Follow the base generator interface
3. **Error Handling**: Provide meaningful error messages
4. **Validation**: Validate inputs before generation
5. **Documentation**: Document generator options and behavior

### Template Design

1. **Readable Code**: Generate clean, readable code
2. **Consistent Style**: Follow Crystal coding conventions
3. **Flexible**: Make templates adaptable to different use cases
4. **Well-Documented**: Include comments in generated code
5. **Testable**: Generate code that's easy to test

### Performance

1. **Template Caching**: Cache frequently used templates
2. **Batch Operations**: Support generating multiple files efficiently
3. **Lazy Loading**: Load templates only when needed
4. **Memory Management**: Clean up resources after generation

## Related Documentation

- [Template Engine (ECR)](template-engine.md) - ECR template system details
- [CLI Framework (Topia)](cli-framework.md) - Command-line interface framework
- [Configuration System](configuration.md) - Configuration management
- [Commands Reference](../commands/generate.md) - Generate command documentation
