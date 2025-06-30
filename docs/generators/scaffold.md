# Scaffold Generator

The Scaffold Generator creates a complete set of files for a resource, including models, endpoints, contracts, pages, and templates. This is the most comprehensive generator for creating full CRUD functionality.

## Usage

```bash
azu generate scaffold RESOURCE_NAME [OPTIONS]
```

## Description

The scaffold generator creates a complete set of files needed for a full-featured resource with CRUD (Create, Read, Update, Delete) operations. It generates models, endpoints, contracts, pages, templates, and tests all at once, providing a solid foundation for building resource-based features.

## Options

- `RESOURCE_NAME` - Name of the resource to scaffold (required)
- `-d, --description DESCRIPTION` - Description of the resource
- `-a, --attributes ATTRIBUTES` - Comma-separated list of attributes with types
- `-t, --template TEMPLATE` - Template to use (default: basic)
- `-f, --force` - Overwrite existing files
- `-h, --help` - Show help message

## Examples

### Generate a basic scaffold

```bash
azu generate scaffold User
```

This creates:

- `src/models/user.cr` - The model class
- `src/endpoints/users/` - All endpoint files
- `src/contracts/users/` - All contract files
- `src/pages/users/` - All page files
- `src/db/migrations/TIMESTAMP_create_users.cr` - Migration file
- `spec/` - All test files

### Generate a scaffold with attributes

```bash
azu generate scaffold Post --attributes "title:string,content:text,author_id:integer,published:boolean"
```

### Generate a scaffold with description

```bash
azu generate scaffold Product --description "E-commerce products with inventory management"
```

## Generated Files

### Model (`src/models/RESOURCE_NAME.cr`)

```crystal
# <%= @description || @name.underscore.humanize %> model
class <%= @name.camelcase %> < CQL::Model
  table :<%= @name.underscore.pluralize %>

  # Generated columns based on attributes
  # column :name, String
  # column :email, String
  # column :age, Int32

  # Timestamps
  timestamps

  # Validations
  validates :name, presence: true
  # Add more validations as needed

  # Associations
  # has_many :posts, Post
  # belongs_to :user, User
end
```

### Migration (`src/db/migrations/TIMESTAMP_create_RESOURCE_NAME.cr`)

```crystal
class Create<%= @name.camelcase.pluralize %> < CQL::Migration
  def up
    create_table :<%= @name.underscore.pluralize %> do |t|
      # Generated columns based on attributes
      # t.string :name, null: false
      # t.string :email, null: false, unique: true
      # t.integer :age, null: true

      t.timestamps
    end

    # Add indexes
    # add_index :<%= @name.underscore.pluralize %>, :email, unique: true
  end

  def down
    drop_table :<%= @name.underscore.pluralize %>
  end
end
```

### Endpoints (`src/endpoints/RESOURCE_NAME/`)

#### Index Endpoint (`index_endpoint.cr`)

```crystal
class <%= @name.camelcase.pluralize %>::IndexEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    @<%= @name.underscore.pluralize %> = <%= @name.camelcase %>.all

    render "endpoints/<%= @name.underscore.pluralize %>/index.json"
  end
end
```

#### Show Endpoint (`show_endpoint.cr`)

```crystal
class <%= @name.camelcase.pluralize %>::ShowEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    @<%= @name.underscore %> = <%= @name.camelcase %>.find(context.params["id"])

    unless @<%= @name.underscore %>
      return Azu::Response.new(status: 404, body: {error: "Not found"}.to_json)
    end

    render "endpoints/<%= @name.underscore.pluralize %>/show.json"
  end
end
```

#### Create Endpoint (`create_endpoint.cr`)

```crystal
class <%= @name.camelcase.pluralize %>::CreateEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    contract = <%= @name.camelcase %>Contract.new(context.params.to_h)

    unless contract.valid?
      return Azu::Response.new(
        status: 422,
        body: {errors: contract.errors}.to_json
      )
    end

    @<%= @name.underscore %> = <%= @name.camelcase %>.create(contract.valid_data)

    render "endpoints/<%= @name.underscore.pluralize %>/create.json", status: 201
  end
end
```

#### Update Endpoint (`update_endpoint.cr`)

```crystal
class <%= @name.camelcase.pluralize %>::UpdateEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    @<%= @name.underscore %> = <%= @name.camelcase %>.find(context.params["id"])

    unless @<%= @name.underscore %>
      return Azu::Response.new(status: 404, body: {error: "Not found"}.to_json)
    end

    contract = <%= @name.camelcase %>Contract.new(context.params.to_h)

    unless contract.valid?
      return Azu::Response.new(
        status: 422,
        body: {errors: contract.errors}.to_json
      )
    end

    @<%= @name.underscore %>.update(contract.valid_data)

    render "endpoints/<%= @name.underscore.pluralize %>/update.json"
  end
end
```

#### Destroy Endpoint (`destroy_endpoint.cr`)

```crystal
class <%= @name.camelcase.pluralize %>::DestroyEndpoint < Azu::Endpoint
  def call(context : Azu::Context) : Azu::Response
    @<%= @name.underscore %> = <%= @name.camelcase %>.find(context.params["id"])

    unless @<%= @name.underscore %>
      return Azu::Response.new(status: 404, body: {error: "Not found"}.to_json)
    end

    @<%= @name.underscore %>.delete

    Azu::Response.new(status: 204)
  end
end
```

### Contracts (`src/contracts/RESOURCE_NAME/`)

#### Base Contract (`contract.cr`)

```crystal
class <%= @name.camelcase %>Contract < Azu::Contract
  # Generated fields based on attributes
  # field :name, String, required: true
  # field :email, String, required: true, format: /^[^@]+@[^@]+\.[^@]+$/
  # field :age, Int32, min: 0, max: 150

  # Custom validations
  # def validate_custom_rule
  #   # Add custom validation logic
  # end
end
```

### Pages (`src/pages/RESOURCE_NAME/`)

#### Index Page (`index_page.cr`)

```crystal
class <%= @name.camelcase.pluralize %>Page < Azu::Page
  def call(context : Azu::Context) : String
    @<%= @name.underscore.pluralize %> = <%= @name.camelcase %>.all
    @total_count = <%= @name.camelcase %>.count

    render "pages/<%= @name.underscore.pluralize %>/index.jinja"
  end
end
```

#### Show Page (`show_page.cr`)

```crystal
class <%= @name.camelcase %>ShowPage < Azu::Page
  def call(context : Azu::Context) : String
    @<%= @name.underscore %> = <%= @name.camelcase %>.find(context.params["id"])

    unless @<%= @name.underscore %>
      context.response.status_code = 404
      return render "pages/404.jinja"
    end

    render "pages/<%= @name.underscore.pluralize %>/show.jinja"
  end
end
```

#### New Page (`new_page.cr`)

```crystal
class <%= @name.camelcase %>NewPage < Azu::Page
  def call(context : Azu::Context) : String
    @<%= @name.underscore %> = <%= @name.camelcase %>.new
    @errors = context.flash["errors"]?

    render "pages/<%= @name.underscore.pluralize %>/new.jinja"
  end
end
```

#### Edit Page (`edit_page.cr`)

```crystal
class <%= @name.camelcase %>EditPage < Azu::Page
  def call(context : Azu::Context) : String
    @<%= @name.underscore %> = <%= @name.camelcase %>.find(context.params["id"])

    unless @<%= @name.underscore %>
      context.response.status_code = 404
      return render "pages/404.jinja"
    end

    @errors = context.flash["errors"]?

    render "pages/<%= @name.underscore.pluralize %>/edit.jinja"
  end
end
```

## Attribute Types

### Supported Attribute Types

```bash
# String attributes
azu generate scaffold User --attributes "name:string,email:string,username:string"

# Text attributes
azu generate scaffold Post --attributes "title:string,content:text,excerpt:text"

# Numeric attributes
azu generate scaffold Product --attributes "name:string,price:decimal,quantity:integer,weight:float"

# Boolean attributes
azu generate scaffold Post --attributes "title:string,content:text,published:boolean,featured:boolean"

# Date/Time attributes
azu generate scaffold Event --attributes "name:string,start_date:date,end_date:date,created_at:datetime"

# Reference attributes (foreign keys)
azu generate scaffold Post --attributes "title:string,content:text,author_id:integer,category_id:integer"
```

### Attribute Options

```bash
# With constraints
azu generate scaffold User --attributes "name:string:required,email:string:required:unique,age:integer:min:18"

# With defaults
azu generate scaffold Post --attributes "title:string:required,content:text:required,published:boolean:default:false"
```

## Scaffold Patterns

### Basic CRUD Scaffold

```bash
azu generate scaffold User --attributes "name:string,email:string,age:integer"
```

This creates a complete CRUD interface for users with:

- User model with validations
- Database migration
- RESTful endpoints (index, show, create, update, destroy)
- Validation contracts
- Web pages (index, show, new, edit)
- HTML templates
- Test files

### Blog Post Scaffold

```bash
azu generate scaffold Post --attributes "title:string,content:text,author_id:integer,published:boolean,slug:string"
```

This creates a blog post system with:

- Post model with associations
- Migration with indexes
- Full CRUD endpoints
- Form validation
- Web interface
- SEO-friendly URLs

### E-commerce Product Scaffold

```bash
azu generate scaffold Product --attributes "name:string,description:text,price:decimal,sku:string,stock:integer,category_id:integer"
```

This creates a product management system with:

- Product model with inventory tracking
- Price and stock management
- Category associations
- SKU validation
- Complete admin interface

## Using Scaffolds

### Route Registration

Register scaffold routes in your application:

```crystal
class Application < Azu::Application
  # RESTful routes for the scaffolded resource
  resources :users do
    get "/", Users::IndexEndpoint
    get "/new", Users::NewPage
    post "/", Users::CreateEndpoint
    get "/:id", Users::ShowEndpoint
    get "/:id/edit", Users::EditPage
    put "/:id", Users::UpdateEndpoint
    delete "/:id", Users::DestroyEndpoint
  end
end
```

### Customizing Generated Code

After generating a scaffold, you can customize the generated files:

```crystal
# Add custom validations to the model
class User < CQL::Model
  table :users

  column :name, String
  column :email, String

  validates :name, presence: true, length: {minimum: 2}
  validates :email, presence: true, format: /^[^@]+@[^@]+\.[^@]+$/

  # Add custom methods
  def full_name
    "#{first_name} #{last_name}"
  end
end
```

### Adding Associations

```crystal
# Add associations to the model
class Post < CQL::Model
  table :posts

  column :title, String
  column :content, Text
  column :author_id, Int64

  belongs_to :author, User
  has_many :comments, Comment
end
```

## Best Practices

### 1. Plan Your Attributes

Think carefully about your resource attributes before scaffolding:

```bash
# Good: Well-planned attributes
azu generate scaffold User --attributes "first_name:string,last_name:string,email:string:unique,password_digest:string,role:string:default:user"

# Good: Include necessary associations
azu generate scaffold Post --attributes "title:string,content:text,author_id:integer,published:boolean,slug:string:unique"
```

### 2. Use Appropriate Data Types

```bash
# Good: Appropriate types for each attribute
azu generate scaffold Product --attributes "name:string,description:text,price:decimal,sku:string:unique,stock:integer,active:boolean"

# Avoid: Using string for everything
azu generate scaffold Product --attributes "name:string,description:string,price:string,sku:string,stock:string"
```

### 3. Include Validations

```bash
# Good: Include validation constraints
azu generate scaffold User --attributes "name:string:required,email:string:required:unique,age:integer:min:18:max:120"
```

### 4. Consider Performance

```bash
# Good: Include indexes for frequently queried fields
azu generate scaffold Post --attributes "title:string,content:text,author_id:integer:index,published:boolean:index,created_at:datetime:index"
```

## Testing Scaffolds

### Model Testing

```crystal
describe User do
  describe "validations" do
    it "is valid with correct attributes" do
      user = User.new(name: "John Doe", email: "john@example.com")
      user.valid?.should be_true
    end

    it "requires name" do
      user = User.new(email: "john@example.com")
      user.valid?.should be_false
      user.errors[:name].should contain("can't be blank")
    end
  end
end
```

### Endpoint Testing

```crystal
describe Users::IndexEndpoint do
  it "returns all users" do
    user = User.create(name: "John Doe", email: "john@example.com")

    get "/users"

    response.status_code.should eq(200)
    response.body.should contain("John Doe")
  end
end
```

### Page Testing

```crystal
describe UsersPage do
  it "displays users list" do
    user = User.create(name: "John Doe", email: "john@example.com")

    get "/users"

    response.status_code.should eq(200)
    response.body.should contain("John Doe")
    response.body.should contain("john@example.com")
  end
end
```

## Common Scaffold Patterns

### 1. User Management

```bash
azu generate scaffold User --attributes "first_name:string,last_name:string,email:string:unique,password_digest:string,role:string:default:user,active:boolean:default:true"
```

### 2. Content Management

```bash
azu generate scaffold Post --attributes "title:string,content:text,excerpt:text,author_id:integer,slug:string:unique,published:boolean:default:false,published_at:datetime"
```

### 3. E-commerce

```bash
azu generate scaffold Product --attributes "name:string,description:text,price:decimal,sku:string:unique,stock:integer,weight:float,category_id:integer,active:boolean:default:true"
```

### 4. Event Management

```bash
azu generate scaffold Event --attributes "title:string,description:text,start_date:date,end_date:date,location:string,capacity:integer,organizer_id:integer,status:string:default:draft"
```

## Related Commands

- `azu generate model` - Generate data models
- `azu generate endpoint` - Generate API endpoints
- `azu generate contract` - Generate validation contracts
- `azu generate page` - Generate web pages
- `azu generate migration` - Generate database migrations

## Templates

The scaffold generator supports different templates:

- `basic` - Basic CRUD scaffold template
- `api` - API-only scaffold template
- `web` - Web-focused scaffold template
- `admin` - Admin interface scaffold template

To use a specific template:

```bash
azu generate scaffold User --template api
```
