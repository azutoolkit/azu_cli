# Template Engine (ECR)

Azu CLI uses Crystal's ECR (Embedded Crystal) as its template engine for code generation. ECR provides a powerful, type-safe way to embed Crystal code within templates, enabling dynamic content generation while maintaining compile-time safety.

## Overview

ECR (Embedded Crystal) is Crystal's built-in template engine that allows you to embed Crystal code directly within text templates. It provides:

- **Type Safety**: Compile-time checking of embedded Crystal code
- **Performance**: Templates are compiled to native code, not interpreted
- **Simplicity**: Familiar Crystal syntax within templates
- **Flexibility**: Full access to Crystal's language features
- **Integration**: Seamless integration with Crystal's compilation process

## ECR Basics

### Template Structure

ECR templates consist of text content with embedded Crystal code:

```crystal
# Basic ECR template
class <%= @name_camelcase %> < CQL::Model
  table :<%= @name_underscore.pluralize %>

  <% @attributes.each do |attr| %>
  column :<%= attr.name %>, <%= attr.column_type %>
  <% end %>

  timestamps
end
```

### ECR Tags

ECR uses specific tags to embed Crystal code:

```crystal
<% %>     # Execute Crystal code (no output)
<%= %>    # Execute Crystal code and output result
<%% %>    # Output literal <% %> (escape)
```

### Template Rendering

Templates are rendered using the `ECR.render` method:

```crystal
class Azu::Generators::Base
  def render_template(context : Hash(String, String)) : String
    ECR.render(template_path, context)
  end

  def template_path : String
    "src/templates/generators/model/model.cr.ecr"
  end
end
```

## Template Variables

### Context Object

Templates receive a context object with variables:

```crystal
# Setting up template context
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

# Using context in template
class <%= @name_camelcase %> < CQL::Model
  table :<%= @name_underscore.pluralize %>

  <% if @description.presence %>
  # <%= @description %>
  <% end %>
end
```

### Variable Types

Templates can work with various data types:

```crystal
# String variables
@name : String

# Array variables
@attributes : Array(Attribute)

# Hash variables
@options : Hash(String, String)

# Boolean variables
@skip_tests : Bool

# Custom objects
@attribute : Attribute
```

## Template Organization

### Directory Structure

Templates are organized by generator type and purpose:

```
src/templates/
├── generators/
│   ├── model/
│   │   ├── model.cr.ecr
│   │   └── model_spec.cr.ecr
│   ├── endpoint/
│   │   ├── index_endpoint.cr.ecr
│   │   ├── show_endpoint.cr.ecr
│   │   ├── create_endpoint.cr.ecr
│   │   ├── update_endpoint.cr.ecr
│   │   ├── destroy_endpoint.cr.ecr
│   │   └── endpoint_spec.cr.ecr
│   ├── service/
│   │   ├── service.cr.ecr
│   │   └── service_spec.cr.ecr
│   ├── component/
│   │   ├── component.cr.ecr
│   │   └── component_spec.cr.ecr
│   ├── validator/
│   │   ├── validator.cr.ecr
│   │   └── validator_spec.cr.ecr
│   └── middleware/
│       ├── middleware.cr.ecr
│       └── middleware_spec.cr.ecr
├── project/
│   ├── README.md.ecr
│   ├── shard.yml.ecr
│   ├── src/
│   │   ├── main.cr.ecr
│   │   ├── server.cr.ecr
│   │   └── initializers/
│   │       ├── database.cr.ecr
│   │       └── logger.cr.ecr
│   └── spec/
│       ├── spec_helper.cr.ecr
│       └── main_spec.cr.ecr
└── scaffold/
    ├── src/
    │   ├── contracts/
    │   │   └── resource/
    │   │       ├── create_contract.cr.ecr
    │   │       ├── update_contract.cr.ecr
    │   │       └── index_contract.cr.ecr
    │   ├── endpoints/
    │   │   └── resource/
    │   │       ├── create_endpoint.cr.ecr
    │   │       ├── update_endpoint.cr.ecr
    │   │       └── index_endpoint.cr.ecr
    │   └── pages/
    │       └── resource/
    │           ├── create_page.cr.ecr
    │           ├── update_page.cr.ecr
    │           └── index_page.cr.ecr
    └── public/
        └── templates/
            └── pages/
                └── resource/
                    ├── create_page.jinja.ecr
                    ├── update_page.jinja.ecr
                    └── index_page.jinja.ecr
```

### Template Naming Conventions

Templates follow consistent naming patterns:

```
{generator_type}_{action}.cr.ecr          # Generator templates
{generator_type}_spec.cr.ecr              # Test templates
{action}_{type}.cr.ecr                    # Action-specific templates
{resource}_{action}.jinja.ecr             # Jinja templates
```

## Template Examples

### Model Template

```crystal
# src/templates/generators/model/model.cr.ecr
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

  <% if @description.presence %>
  # <%= @description %>
  <% end %>
end
```

### Endpoint Template

```crystal
# src/templates/generators/endpoint/index_endpoint.cr.ecr
class <%= @name_camelcase.pluralize %>::IndexEndpoint < Azu::Endpoint
  def call
    <%= @name_underscore.pluralize %> = <%= @name_camelcase %>.all

    render_page(<%= @name_camelcase.pluralize %>::IndexPage, <%= @name_underscore.pluralize %>: <%= @name_underscore.pluralize %>)
  end
end
```

### Service Template

```crystal
# src/templates/generators/service/service.cr.ecr
class <%= @name_camelcase %>Service
  def initialize
  end

  <% @attributes.each do |attr| %>
  def create_<%= @name_underscore %>(<%= attr.name %>: <%= attr.column_type %>)
    <%= @name_camelcase %>.create(
      <%= attr.name %>: <%= attr.name %>
    )
  end
  <% end %>

  def find_<%= @name_underscore %>(id: Int64)
    <%= @name_camelcase %>.find(id)
  end

  def update_<%= @name_underscore %>(id: Int64, **params)
    <%= @name_underscore %> = find_<%= @name_underscore %>(id)
    <%= @name_underscore %>.update(**params)
  end

  def delete_<%= @name_underscore %>(id: Int64)
    <%= @name_underscore %> = find_<%= @name_underscore %>(id)
    <%= @name_underscore %>.delete
  end
end
```

### Component Template

```crystal
# src/templates/generators/component/component.cr.ecr
class <%= @name_camelcase %>Component < Azu::Component
  <% @attributes.each do |attr| %>
  property <%= attr.name %> : <%= attr.column_type %>
  <% end %>

  <% @events.each do |event| %>
  event <%= event %> : String
  <% end %>

  def initialize
    <% @attributes.each do |attr| %>
    @<%= attr.name %> = ""
    <% end %>
  end

  def render
    template("src/templates/components/<%= @name_underscore %>.jinja")
  end

  <% if @websocket %>
  def on_connect
    # WebSocket connection logic
  end

  def on_message(message : String)
    # Handle incoming messages
  end
  <% end %>
end
```

### Jinja Template

```jinja
{# src/templates/components/counter.jinja.ecr #}
<div class="counter-component">
  <h3>Counter: {{ count }}</h3>
  <button onclick="increment()">Increment</button>
  <button onclick="decrement()">Decrement</button>
</div>

<script>
function increment() {
  window.azu.sendEvent('increment', {});
}

function decrement() {
  window.azu.sendEvent('decrement', {});
}
</script>
```

## Advanced ECR Features

### Conditional Logic

```crystal
<% if @skip_tests %>
# Tests skipped
<% else %>
# Tests included
<% end %>

<% unless @options.empty? %>
# Options: <%= @options.to_json %>
<% end %>
```

### Loops and Iteration

```crystal
<% @attributes.each do |attr| %>
  column :<%= attr.name %>, <%= attr.column_type %>
<% end %>

<% @actions.each_with_index do |action, index| %>
  <%= action.camelcase %>Endpoint.new
<% end %>
```

### Method Calls

```crystal
class <%= @name.camelcase %> < CQL::Model
  table :<%= @name.underscore.pluralize %>

  <% @attributes.each do |attr| %>
  column :<%= attr.name %>, <%= attr.column_type %>
  <% end %>

  <% if @attributes.any?(&.has_validation?) %>
  validates :<%= @attributes.select(&.has_validation?).map(&.name).join(", ") %>
  <% end %>
end
```

### Error Handling

```crystal
<% begin %>
  <% @attributes.each do |attr| %>
  column :<%= attr.name %>, <%= attr.column_type %>
  <% end %>
<% rescue ex %>
  # Error processing attributes: <%= ex.message %>
<% end %>
```

## Template Helpers

### String Manipulation

```crystal
# Built-in string methods
@name.camelcase           # "user" -> "User"
@name.underscore          # "User" -> "user"
@name.pluralize           # "user" -> "users"
@name.humanize            # "user" -> "User"
@name.titleize            # "user" -> "User"
@name.dasherize           # "user_name" -> "user-name"
```

### Custom Helpers

```crystal
class Azu::Generators::TemplateHelpers
  def self.indent(text : String, spaces : Int32 = 2) : String
    text.lines.map { |line| " " * spaces + line }.join("\n")
  end

  def self.format_attributes(attributes : Array(Attribute)) : String
    attributes.map { |attr| "#{attr.name}: #{attr.column_type}" }.join(", ")
  end

  def self.generate_validations(attributes : Array(Attribute)) : String
    attributes
      .select(&.has_validation?)
      .map { |attr| "validates :#{attr.name}, #{attr.validation_rules.join(", ")}" }
      .join("\n  ")
  end
end
```

## Template Caching

### Performance Optimization

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

  def self.preload_templates
    Dir.glob("src/templates/**/*.ecr").each do |path|
      get(path)
    end
  end
end
```

### Template Validation

```crystal
class Azu::Generators::TemplateValidator
  def self.validate_template(template_path : String) : Bool
    content = File.read(template_path)

    # Check for basic ECR syntax
    unless content.includes?("<%") || content.includes?("<%=")
      raise "Template #{template_path} contains no ECR tags"
    end

    # Check for balanced tags
    open_tags = content.scan(/<%[^=]/).size
    close_tags = content.scan(/%>/).size

    if open_tags != close_tags
      raise "Unbalanced ECR tags in #{template_path}"
    end

    true
  rescue ex
    Azu::Logger.error("Template validation failed: #{ex.message}")
    false
  end
end
```

## Template Customization

### User Customization

Users can override default templates by creating custom template files:

```crystal
class Azu::Generators::Base
  def template_path : String
    # Check for custom template first
    custom_path = "templates/generators/#{generator_type}/#{template_name}.cr.ecr"
    return custom_path if File.exists?(custom_path)

    # Fall back to default
    "src/templates/generators/#{generator_type}/#{template_name}.cr.ecr"
  end

  private def generator_type : String
    self.class.name.underscore.split("::").last
  end

  private def template_name : String
    "model"  # Override in subclasses
  end
end
```

### Template Inheritance

Templates can inherit from base templates:

```crystal
# Base model template
# src/templates/generators/model/base_model.cr.ecr
class <%= @name_camelcase %> < CQL::Model
  table :<%= @name_underscore.pluralize %>

  <% yield %>

  timestamps
end

# Specific model template
# src/templates/generators/model/user_model.cr.ecr
<% ECR.embed "src/templates/generators/model/base_model.cr.ecr" %>
  column :name, String
  column :email, String

  validates :name, presence: true
  validates :email, presence: true, format: /^[^@]+@[^@]+\.[^@]+$/
<% end %>
```

## Best Practices

### Template Design

1. **Keep Templates Simple**: Avoid complex logic in templates
2. **Use Helper Methods**: Move complex logic to helper classes
3. **Consistent Indentation**: Maintain readable code structure
4. **Error Handling**: Include proper error handling in templates
5. **Documentation**: Add comments to explain complex template logic

### Performance

1. **Template Caching**: Cache frequently used templates
2. **Minimize File I/O**: Load templates once and reuse
3. **Efficient Loops**: Use appropriate iteration methods
4. **Memory Management**: Clean up template cache when needed

### Maintainability

1. **Consistent Naming**: Use consistent naming conventions
2. **Modular Design**: Break complex templates into smaller parts
3. **Version Control**: Track template changes in version control
4. **Testing**: Test template rendering with various inputs

## Related Documentation

- [Generator System](generator-system.md) - Code generation architecture
- [CLI Framework (Topia)](cli-framework.md) - Command-line interface framework
- [Commands Reference](../commands/generate.md) - Generate command documentation
- [Template Variables](../reference/template-variables.md) - Template variable reference
