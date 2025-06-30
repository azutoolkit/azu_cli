# Component Generator

The Component Generator creates reusable UI components that can be shared across different pages and templates in your Azu application.

## Usage

```bash
azu generate component COMPONENT_NAME [OPTIONS]
```

## Description

Components in Azu applications are reusable UI elements that encapsulate both presentation logic and styling. They can be used across multiple pages to maintain consistency and reduce code duplication. Components can include forms, cards, navigation elements, and other UI patterns.

## Options

- `COMPONENT_NAME` - Name of the component to generate (required)
- `-d, --description DESCRIPTION` - Description of the component
- `-t, --template TEMPLATE` - Template to use (default: basic)
- `-f, --force` - Overwrite existing files
- `-h, --help` - Show help message

## Examples

### Generate a basic component

```bash
azu generate component UserCard
```

This creates:

- `src/components/user_card.cr` - The component class
- `src/components/user_card.jinja` - The component template
- `spec/components/user_card_spec.cr` - Test file

### Generate a component with description

```bash
azu generate component NavigationBar --description "Main navigation component with user menu"
```

### Generate specific component types

```bash
azu generate component ContactForm --template form
azu generate component Pagination --template pagination
```

## Generated Files

### Component Class (`src/components/COMPONENT_NAME.cr`)

```crystal
# <%= @description || @name.underscore.humanize %> component
class <%= @name %>Component < Azu::Component
  def initialize
  end

  def call(context : Azu::Context, **args) : String
    # Add your component logic here
    # Example:
    # @user = args[:user]
    # @show_avatar = args[:show_avatar]? || true

    render "components/<%= @name.underscore %>.jinja"
  end
end
```

### Component Template (`src/components/COMPONENT_NAME.jinja`)

```jinja
<!-- <%= @name.underscore.humanize %> component -->
<div class="<%= @name.underscore %>-component">
  <!-- Add your component content here -->
  <h3><%= @name.underscore.humanize %></h3>
  <p>This is the <%= @name.underscore.humanize %> component.</p>
</div>
```

### Test File (`spec/components/COMPONENT_NAME_spec.cr`)

```crystal
require "../spec_helper"

describe <%= @name %>Component do
  describe "#call" do
    it "renders the component" do
      component = <%= @name %>Component.new
      context = Azu::Context.new

      result = component.call(context)

      result.should be_a(String)
      result.should contain("<%= @name.underscore.humanize %>")
    end
  end
end
```

## Component Patterns

### Basic Component Pattern

```crystal
class UserCardComponent < Azu::Component
  def call(context : Azu::Context, **args) : String
    @user = args[:user]
    @show_avatar = args[:show_avatar]? || true
    @show_email = args[:show_email]? || false

    render "components/user_card.jinja"
  end
end
```

### Component with Data Processing

```crystal
class PostListComponent < Azu::Component
  def call(context : Azu::Context, **args) : String
    @posts = args[:posts] || Post.all
    @limit = args[:limit]? || 10
    @show_author = args[:show_author]? || true

    # Process posts
    @posts = @posts.limit(@limit)

    render "components/post_list.jinja"
  end
end
```

### Form Component Pattern

```crystal
class ContactFormComponent < Azu::Component
  def call(context : Azu::Context, **args) : String
    @form_data = args[:form_data]? || {} of String => String
    @errors = args[:errors]? || {} of String => Array(String)
    @action = args[:action]? || "/contact"
    @method = args[:method]? || "POST"

    render "components/contact_form.jinja"
  end
end
```

### Navigation Component Pattern

```crystal
class NavigationComponent < Azu::Component
  def call(context : Azu::Context, **args) : String
    @current_user = context.current_user
    @current_path = context.request.path
    @menu_items = build_menu_items

    render "components/navigation.jinja"
  end

  private def build_menu_items : Array(MenuItem)
    items = [] of MenuItem

    items << MenuItem.new("Home", "/", "home")
    items << MenuItem.new("About", "/about", "info")

    if @current_user
      items << MenuItem.new("Dashboard", "/dashboard", "dashboard")
      items << MenuItem.new("Profile", "/profile", "user")
    end

    items
  end
end
```

## Template Patterns

### Basic Component Template

```jinja
<!-- User Card Component -->
<div class="user-card">
  {% if show_avatar %}
  <div class="user-avatar">
    <img src="{{ user.avatar_url }}" alt="{{ user.name }}">
  </div>
  {% endif %}

  <div class="user-info">
    <h3>{{ user.name }}</h3>
    {% if show_email %}
    <p>{{ user.email }}</p>
    {% endif %}
    <p>Joined: {{ user.created_at.strftime("%B %Y") }}</p>
  </div>
</div>
```

### List Component Template

```jinja
<!-- Post List Component -->
<div class="post-list">
  {% for post in posts %}
  <div class="post-item">
    <h4><a href="/posts/{{ post.slug }}">{{ post.title }}</a></h4>
    <p>{{ post.excerpt }}</p>

    {% if show_author %}
    <div class="post-meta">
      <span>By {{ post.author.name }}</span>
      <span>{{ post.created_at.strftime("%B %d, %Y") }}</span>
    </div>
    {% endif %}
  </div>
  {% endfor %}

  {% if posts.empty? %}
  <p class="no-posts">No posts found.</p>
  {% endif %}
</div>
```

### Form Component Template

```jinja
<!-- Contact Form Component -->
<form method="{{ method }}" action="{{ action }}" class="contact-form">
  {% if errors %}
  <div class="form-errors">
    <ul>
      {% for field, field_errors in errors %}
        {% for error in field_errors %}
        <li>{{ field }}: {{ error }}</li>
        {% endfor %}
      {% endfor %}
    </ul>
  </div>
  {% endif %}

  <div class="form-group">
    <label for="name">Name:</label>
    <input type="text" id="name" name="name" value="{{ form_data.name }}" required>
  </div>

  <div class="form-group">
    <label for="email">Email:</label>
    <input type="email" id="email" name="email" value="{{ form_data.email }}" required>
  </div>

  <div class="form-group">
    <label for="message">Message:</label>
    <textarea id="message" name="message" rows="5" required>{{ form_data.message }}</textarea>
  </div>

  <button type="submit" class="btn btn-primary">Send Message</button>
</form>
```

### Navigation Component Template

```jinja
<!-- Navigation Component -->
<nav class="main-navigation">
  <div class="nav-brand">
    <a href="/">My App</a>
  </div>

  <ul class="nav-menu">
    {% for item in menu_items %}
    <li class="nav-item {% if current_path == item.path %}active{% endif %}">
      <a href="{{ item.path }}" class="nav-link">
        <i class="icon-{{ item.icon }}"></i>
        {{ item.label }}
      </a>
    </li>
    {% endfor %}
  </ul>

  {% if current_user %}
  <div class="nav-user">
    <span>Welcome, {{ current_user.name }}</span>
    <a href="/logout" class="btn btn-logout">Logout</a>
  </div>
  {% else %}
  <div class="nav-auth">
    <a href="/login" class="btn btn-login">Login</a>
    <a href="/register" class="btn btn-register">Register</a>
  </div>
  {% endif %}
</nav>
```

## Using Components

### In Pages

Use components in your page classes:

```crystal
class UsersPage < Azu::Page
  def call(context : Azu::Context) : String
    @users = User.all
    @user_card_component = UserCardComponent.new

    render "pages/users.jinja"
  end
end
```

### In Templates

Include components in your templates:

```jinja
{% extends "layout.jinja" %}

{% block content %}
<div class="container">
  <h1>Users</h1>

  <div class="users-grid">
    {% for user in users %}
      {{ user_card_component.call(context, user: user, show_avatar: true, show_email: false) }}
    {% endfor %}
  </div>
</div>
{% endblock %}
```

### In Layouts

Use components in your layout templates:

```jinja
<!DOCTYPE html>
<html>
<head>
  <title>{% block title %}{% endblock %}</title>
</head>
<body>
  {{ navigation_component.call(context) }}

  <main>
    {% block content %}{% endblock %}
  </main>

  {{ footer_component.call(context) }}
</body>
</html>
```

## Best Practices

### 1. Keep Components Focused

Each component should have a single responsibility:

```crystal
# Good: Focused on user display
class UserCardComponent < Azu::Component
  def call(context : Azu::Context, **args) : String
    @user = args[:user]
    render "components/user_card.jinja"
  end
end

# Good: Focused on user actions
class UserActionsComponent < Azu::Component
  def call(context : Azu::Context, **args) : String
    @user = args[:user]
    @current_user = context.current_user
    render "components/user_actions.jinja"
  end
end
```

### 2. Use Flexible Parameters

Make components configurable through parameters:

```crystal
class PostCardComponent < Azu::Component
  def call(context : Azu::Context, **args) : String
    @post = args[:post]
    @show_author = args[:show_author]? || true
    @show_date = args[:show_date]? || true
    @show_excerpt = args[:show_excerpt]? || true
    @truncate_length = args[:truncate_length]? || 150

    render "components/post_card.jinja"
  end
end
```

### 3. Handle Missing Data Gracefully

```crystal
class UserAvatarComponent < Azu::Component
  def call(context : Azu::Context, **args) : String
    @user = args[:user]
    @size = args[:size]? || "medium"
    @default_avatar = args[:default_avatar]? || "/images/default-avatar.png"

    render "components/user_avatar.jinja"
  end
end
```

### 4. Use Semantic HTML

```jinja
<!-- Good: Semantic HTML structure -->
<article class="post-card">
  <header class="post-header">
    <h2 class="post-title">{{ post.title }}</h2>
    <time class="post-date">{{ post.created_at.strftime("%B %d, %Y") }}</time>
  </header>

  <div class="post-content">
    {{ post.excerpt }}
  </div>

  <footer class="post-footer">
    <a href="/posts/{{ post.slug }}" class="read-more">Read More</a>
  </footer>
</article>
```

## Testing Components

### Unit Testing

```crystal
describe UserCardComponent do
  describe "#call" do
    it "renders user card with avatar" do
      component = UserCardComponent.new
      context = Azu::Context.new
      user = User.new(name: "John Doe", email: "john@example.com")

      result = component.call(context, user: user, show_avatar: true)

      result.should contain("John Doe")
      result.should contain("john@example.com")
      result.should contain("user-avatar")
    end

    it "renders user card without avatar" do
      component = UserCardComponent.new
      context = Azu::Context.new
      user = User.new(name: "John Doe", email: "john@example.com")

      result = component.call(context, user: user, show_avatar: false)

      result.should_not contain("user-avatar")
    end
  end
end
```

### Integration Testing

```crystal
describe "Component integration" do
  it "displays user cards on users page" do
    get "/users"

    response.status_code.should eq(200)
    response.body.should contain("user-card")
    response.body.should contain("John Doe")
  end
end
```

## Common Component Types

### 1. Display Components

Show data in a consistent format:

```crystal
class DataCardComponent < Azu::Component
  def call(context : Azu::Context, **args) : String
    @title = args[:title]
    @value = args[:value]
    @icon = args[:icon]?
    @color = args[:color]? || "primary"

    render "components/data_card.jinja"
  end
end
```

### 2. Form Components

Reusable form elements:

```crystal
class FormFieldComponent < Azu::Component
  def call(context : Azu::Context, **args) : String
    @name = args[:name]
    @label = args[:label]
    @type = args[:type]? || "text"
    @value = args[:value]?
    @errors = args[:errors]? || [] of String
    @required = args[:required]? || false

    render "components/form_field.jinja"
  end
end
```

### 3. Navigation Components

Site navigation elements:

```crystal
class BreadcrumbComponent < Azu::Component
  def call(context : Azu::Context, **args) : String
    @items = args[:items] || [] of BreadcrumbItem
    @separator = args[:separator]? || ">"

    render "components/breadcrumb.jinja"
  end
end
```

### 4. Layout Components

Structural layout elements:

```crystal
class SidebarComponent < Azu::Component
  def call(context : Azu::Context, **args) : String
    @title = args[:title]?
    @items = args[:items] || [] of SidebarItem
    @collapsible = args[:collapsible]? || false

    render "components/sidebar.jinja"
  end
end
```

## Related Commands

- `azu generate page` - Generate page components
- `azu generate endpoint` - Generate API endpoints
- `azu generate model` - Generate data models
- `azu generate service` - Generate business logic services

## Templates

The component generator supports different templates:

- `basic` - Simple component with basic structure
- `card` - Card display component template
- `form` - Form component template
- `navigation` - Navigation component template
- `list` - List display component template

To use a specific template:

```bash
azu generate component ProductCard --template card
```
