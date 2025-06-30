# Page Generator

The Page Generator creates page components that handle the presentation layer of your Azu web application, including HTML templates and page-specific logic.

## Usage

```bash
azu generate page PAGE_NAME [OPTIONS]
```

## Description

Pages in Azu applications represent the view layer of your web application. They combine HTML templates with Crystal code to render dynamic content and handle user interactions. Pages can include forms, data display, and client-side functionality.

## Options

- `PAGE_NAME` - Name of the page to generate (required)
- `-d, --description DESCRIPTION` - Description of the page
- `-t, --template TEMPLATE` - Template to use (default: basic)
- `-f, --force` - Overwrite existing files
- `-h, --help` - Show help message

## Examples

### Generate a basic page

```bash
azu generate page WelcomePage
```

This creates:

- `src/pages/welcome_page.cr` - The page class
- `src/pages/welcome_page.jinja` - The HTML template
- `spec/pages/welcome_page_spec.cr` - Test file

### Generate a page with description

```bash
azu generate page UserProfilePage --description "Displays user profile information and settings"
```

### Generate specific page types

```bash
azu generate page BlogPostPage --template blog
azu generate page ContactFormPage --template form
```

## Generated Files

### Page Class (`src/pages/PAGE_NAME.cr`)

```crystal
# <%= @description || @name.underscore.humanize %> page
class <%= @name %>Page < Azu::Page
  def initialize
  end

  def call(context : Azu::Context) : String
    # Add your page logic here
    # Example:
    # @users = User.all
    # @current_user = context.current_user

    render "pages/<%= @name.underscore %>.jinja"
  end
end
```

### HTML Template (`src/pages/PAGE_NAME.jinja`)

```jinja
{% extends "layout.jinja" %}

{% block title %}{{ @name.underscore.humanize }}{% endblock %}

{% block content %}
<div class="container">
  <h1>{{ @name.underscore.humanize }}</h1>

  <!-- Add your page content here -->
  <p>Welcome to the <%= @name.underscore.humanize %> page!</p>
</div>
{% endblock %}
```

### Test File (`spec/pages/PAGE_NAME_spec.cr`)

```crystal
require "../spec_helper"

describe <%= @name %>Page do
  describe "#call" do
    it "renders the page" do
      page = <%= @name %>Page.new
      context = Azu::Context.new

      result = page.call(context)

      result.should be_a(String)
      result.should contain("<%= @name.underscore.humanize %>")
    end
  end
end
```

## Page Patterns

### Basic Page Pattern

```crystal
class WelcomePage < Azu::Page
  def call(context : Azu::Context) : String
    @greeting = "Hello, World!"
    @current_time = Time.utc

    render "pages/welcome.jinja"
  end
end
```

### Page with Data Loading

```crystal
class UsersPage < Azu::Page
  def call(context : Azu::Context) : String
    @users = User.all
    @total_count = User.count
    @current_page = context.params["page"]?.try(&.to_i) || 1

    render "pages/users.jinja"
  end
end
```

### Page with Form Handling

```crystal
class ContactPage < Azu::Page
  def call(context : Azu::Context) : String
    if context.request.method == "POST"
      handle_form_submission(context)
    end

    @form_data = context.params
    @errors = context.flash["errors"]?

    render "pages/contact.jinja"
  end

  private def handle_form_submission(context : Azu::Context)
    contract = ContactContract.new(context.params.to_h)

    if contract.valid?
      # Process form data
      Contact.create(contract.valid_data)
      context.flash["success"] = "Message sent successfully!"
      context.redirect("/contact")
    else
      context.flash["errors"] = contract.errors
    end
  end
end
```

### Page with Authentication

```crystal
class DashboardPage < Azu::Page
  def call(context : Azu::Context) : String
    user = context.current_user

    unless user
      context.redirect("/login")
      return ""
    end

    @user = user
    @recent_activity = user.recent_activity
    @stats = user.statistics

    render "pages/dashboard.jinja"
  end
end
```

## Template Patterns

### Basic Template

```jinja
{% extends "layout.jinja" %}

{% block title %}Welcome{% endblock %}

{% block content %}
<div class="container">
  <h1>Welcome to Our Application</h1>
  <p>Current time: {{ current_time }}</p>

  <div class="features">
    <h2>Features</h2>
    <ul>
      <li>Feature 1</li>
      <li>Feature 2</li>
      <li>Feature 3</li>
    </ul>
  </div>
</div>
{% endblock %}
```

### Template with Data Display

```jinja
{% extends "layout.jinja" %}

{% block title %}Users{% endblock %}

{% block content %}
<div class="container">
  <h1>Users ({{ total_count }})</h1>

  <div class="users-list">
    {% for user in users %}
    <div class="user-card">
      <h3>{{ user.name }}</h3>
      <p>{{ user.email }}</p>
      <p>Joined: {{ user.created_at.strftime("%B %d, %Y") }}</p>
    </div>
    {% endfor %}
  </div>

  {% if users.empty? %}
  <p>No users found.</p>
  {% endif %}
</div>
{% endblock %}
```

### Template with Forms

```jinja
{% extends "layout.jinja" %}

{% block title %}Contact Us{% endblock %}

{% block content %}
<div class="container">
  <h1>Contact Us</h1>

  {% if errors %}
  <div class="alert alert-danger">
    <ul>
      {% for field, field_errors in errors %}
        {% for error in field_errors %}
        <li>{{ field }}: {{ error }}</li>
        {% endfor %}
      {% endfor %}
    </ul>
  </div>
  {% endif %}

  <form method="POST" action="/contact">
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
</div>
{% endblock %}
```

### Template with Navigation

```jinja
{% extends "layout.jinja" %}

{% block title %}Dashboard{% endblock %}

{% block content %}
<div class="container">
  <div class="row">
    <div class="col-md-3">
      {% include "helpers/_nav.jinja" %}
    </div>

    <div class="col-md-9">
      <h1>Welcome, {{ user.name }}!</h1>

      <div class="stats">
        <div class="stat-card">
          <h3>Recent Activity</h3>
          {% for activity in recent_activity %}
          <div class="activity-item">
            <span class="activity-time">{{ activity.created_at.strftime("%H:%M") }}</span>
            <span class="activity-text">{{ activity.description }}</span>
          </div>
          {% endfor %}
        </div>
      </div>
    </div>
  </div>
</div>
{% endblock %}
```

## Using Pages

### Route Registration

Register pages in your application routes:

```crystal
class Application < Azu::Application
  # Basic page routes
  get "/", WelcomePage
  get "/users", UsersPage
  get "/contact", ContactPage
  get "/dashboard", DashboardPage

  # Pages with parameters
  get "/users/:id", UserShowPage
  get "/posts/:slug", PostShowPage
end
```

### Page with Parameters

```crystal
class UserShowPage < Azu::Page
  def call(context : Azu::Context) : String
    user_id = context.params["id"]
    @user = User.find(user_id)

    unless @user
      context.response.status_code = 404
      return render "pages/404.jinja"
    end

    render "pages/user_show.jinja"
  end
end
```

### Page with Flash Messages

```crystal
class LoginPage < Azu::Page
  def call(context : Azu::Context) : String
    @error = context.flash["error"]?
    @success = context.flash["success"]?

    render "pages/login.jinja"
  end
end
```

## Best Practices

### 1. Keep Pages Focused

Each page should have a single responsibility:

```crystal
# Good: Focused on user listing
class UsersPage < Azu::Page
  def call(context : Azu::Context) : String
    @users = User.all
    render "pages/users.jinja"
  end
end

# Good: Focused on user details
class UserShowPage < Azu::Page
  def call(context : Azu::Context) : String
    @user = User.find(context.params["id"])
    render "pages/user_show.jinja"
  end
end
```

### 2. Use Instance Variables for Template Data

```crystal
class BlogPage < Azu::Page
  def call(context : Azu::Context) : String
    # Good: Use instance variables
    @posts = Post.all
    @categories = Category.all
    @current_user = context.current_user

    render "pages/blog.jinja"
  end
end
```

### 3. Handle Errors Gracefully

```crystal
class PostShowPage < Azu::Page
  def call(context : Azu::Context) : String
    @post = Post.find_by(slug: context.params["slug"])

    unless @post
      context.response.status_code = 404
      return render "pages/404.jinja"
    end

    render "pages/post_show.jinja"
  end
end
```

### 4. Use Layouts and Partials

```jinja
<!-- Use layouts for consistent structure -->
{% extends "layout.jinja" %}

<!-- Use partials for reusable components -->
{% include "helpers/_user_card.jinja" %}
{% include "helpers/_pagination.jinja" %}
```

## Testing Pages

### Unit Testing

```crystal
describe WelcomePage do
  describe "#call" do
    it "renders welcome page with greeting" do
      page = WelcomePage.new
      context = Azu::Context.new

      result = page.call(context)

      result.should contain("Hello, World!")
      result.should contain("Welcome")
    end
  end
end
```

### Integration Testing

```crystal
describe "Page integration" do
  it "displays users page" do
    get "/users"

    response.status_code.should eq(200)
    response.body.should contain("Users")
  end

  it "handles 404 for missing user" do
    get "/users/999999"

    response.status_code.should eq(404)
    response.body.should contain("Not Found")
  end
end
```

## Common Page Types

### 1. List Pages

Display collections of data:

```crystal
class PostsPage < Azu::Page
  def call(context : Azu::Context) : String
    @posts = Post.all.order(created_at: :desc)
    @total_posts = Post.count

    render "pages/posts.jinja"
  end
end
```

### 2. Show Pages

Display individual records:

```crystal
class PostShowPage < Azu::Page
  def call(context : Azu::Context) : String
    @post = Post.find_by(slug: context.params["slug"])
    @comments = @post.comments if @post

    render "pages/post_show.jinja"
  end
end
```

### 3. Form Pages

Handle user input:

```crystal
class NewPostPage < Azu::Page
  def call(context : Azu::Context) : String
    if context.request.method == "POST"
      handle_post_creation(context)
    end

    @categories = Category.all
    render "pages/new_post.jinja"
  end
end
```

### 4. Dashboard Pages

Display user-specific information:

```crystal
class DashboardPage < Azu::Page
  def call(context : Azu::Context) : String
    @user = context.current_user
    @recent_posts = @user.posts.limit(5)
    @stats = @user.statistics

    render "pages/dashboard.jinja"
  end
end
```

## Related Commands

- `azu generate endpoint` - Generate API endpoints
- `azu generate model` - Generate data models
- `azu generate contract` - Generate validation contracts
- `azu generate service` - Generate business logic services

## Templates

The page generator supports different templates:

- `basic` - Simple page with basic structure
- `blog` - Blog post page template
- `form` - Form handling page template
- `dashboard` - Dashboard page template
- `list` - List display page template

To use a specific template:

```bash
azu generate page BlogPostPage --template blog
```
