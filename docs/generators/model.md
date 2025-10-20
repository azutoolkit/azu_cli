# Model Generator

The model generator creates CQL ORM models for your Azu application. Models represent database tables and provide an object-oriented interface for database operations.

## Overview

```bash
azu generate model <name> [field:type] [options]
```

## Basic Usage

### Generate a Simple Model

```bash
# Generate a basic model
azu generate model user

# Generate with fields
azu generate model user name:string email:string age:integer

# Generate with relationships
azu generate model post title:string content:text user:references
```

### Generate with Validations

```bash
# Generate model with common validations
azu generate model user name:string email:string --validations

# Generate with timestamps
azu generate model post title:string content:text --timestamps

# Generate with UUID primary key
azu generate model user name:string email:string --uuid
```

## Command Options

| Option             | Description                      | Default |
| ------------------ | -------------------------------- | ------- |
| `--validations`    | Add common validations           | false   |
| `--timestamps`     | Add created_at/updated_at fields | false   |
| `--uuid`           | Use UUID as primary key          | false   |
| `--skip-tests`     | Don't generate test files        | false   |
| `--skip-migration` | Don't generate migration file    | false   |
| `--force`          | Overwrite existing files         | false   |

## Field Types

| Type         | Crystal Type | Database Type | Description            |
| ------------ | ------------ | ------------- | ---------------------- |
| `string`     | `String`     | VARCHAR(255)  | Short text field       |
| `text`       | `String`     | TEXT          | Long text field        |
| `integer`    | `Int32`      | INTEGER       | 32-bit integer         |
| `bigint`     | `Int64`      | BIGINT        | 64-bit integer         |
| `float`      | `Float64`    | FLOAT         | Floating point number  |
| `decimal`    | `BigDecimal` | DECIMAL       | Precise decimal number |
| `boolean`    | `Bool`       | BOOLEAN       | True/false value       |
| `date`       | `Date`       | DATE          | Date only              |
| `time`       | `Time`       | TIMESTAMP     | Date and time          |
| `json`       | `JSON::Any`  | JSON/JSONB    | JSON data              |
| `uuid`       | `UUID`       | UUID          | UUID field             |
| `references` | `Int64`      | BIGINT        | Foreign key reference  |

## Generated Files

### Model File

```crystal
# src/models/user.cr
require "cql"

module User
  struct UserModel
    include CQL::ActiveRecord::Model(Int64)
    db_context AppDB, :users

    getter id : Int64?
    getter name : String
    getter email : String
    getter age : Int32?
    getter created_at : Time?
    getter updated_at : Time?

    validate :name, presence: true
    validate :email, presence: true, format: /\A[^@\s]+@[^@\s]+\z/
    validate :age, numericality: { greater_than: 0 }

    def initialize(@name : String, @email : String, @age : Int32? = nil)
    end

    def self.find_by_email(email : String)
      where(email: email).first
    end

    def full_name
      "#{name} (#{email})"
    end
  end
end
```

### Migration File

```crystal
# db/migrations/20231201000001_create_users.cr
class CreateUsers < CQL::Migration
  def up
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false, unique: true
      t.integer :age
      t.timestamps
    end

    add_index :users, :email
  end

  def down
    drop_table :users
  end
end
```

### Test File

```crystal
# spec/models/user_spec.cr
require "../spec_helper"

describe User do
  describe "validations" do
    it "is valid with valid attributes" do
      user = User.new(name: "John Doe", email: "john@example.com")
      user.valid?.should be_true
    end

    it "is invalid without name" do
      user = User.new(email: "john@example.com")
      user.valid?.should be_false
      user.errors[:name].should contain("can't be blank")
    end

    it "is invalid with invalid email" do
      user = User.new(name: "John Doe", email: "invalid-email")
      user.valid?.should be_false
      user.errors[:email].should contain("is invalid")
    end
  end

  describe ".find_by_email" do
    it "finds user by email" do
      user = User.create!(name: "John Doe", email: "john@example.com")
      found = User.find_by_email("john@example.com")
      found.should eq(user)
    end
  end
end
```

## Examples

### User Model

```bash
# Generate user model with validations
azu generate model user name:string email:string age:integer --validations --timestamps
```

**Generated Model:**

```crystal
# src/models/user.cr
require "cql"

module User
  struct UserModel
    include CQL::ActiveRecord::Model(Int64)
    db_context AppDB, :users

    getter id : Int64?
    getter name : String
    getter email : String
    getter age : Int32?
    getter created_at : Time?
    getter updated_at : Time?

    validate :name, presence: true
    validate :email, presence: true, format: /\A[^@\s]+@[^@\s]+\z/
    validate :age, numericality: { greater_than: 0 }

    def initialize(@name : String, @email : String, @age : Int32? = nil)
    end

    def self.find_by_email(email : String)
      where(email: email).first
    end

    def full_name
      "#{name} (#{email})"
    end
  end
end
```

### Post Model with Relationships

```bash
# Generate post model with user relationship
azu generate model post title:string content:text user:references --timestamps
```

**Generated Model:**

```crystal
# src/models/post.cr
require "cql"

class Post
  include CQL::Model(Int63)
  db_context AppDB, :posts

  column id : Int64, primary: true, auto: true
  column title : String
  column content : String
  column user_id : Int64
  column created_at : Time
  column updated_at : Time

  belongs_to :user, User
  has_many :comments, Comment

  validates :title, presence: true
  validates :content, presence: true
  validates :user_id, presence: true

  def self.published
    where(published: true)
  end

  def published?
    published == true
  end
end
```

### Category Model with UUID

```bash
# Generate category model with UUID primary key
azu generate model category name:string description:text --uuid
```

**Generated Model:**

```crystal
# src/models/category.cr
require "cql"

class Category
  include CQL::Model(UUID)
  db_context AppDB, :categories

  column id : UUID, primary: true, auto: true
  column name : String
  column description : String

  validates :name, presence: true, uniqueness: true

  def self.find_by_name(name : String)
    where(name: name).first
  end
end
```

## Relationships

### Belongs To

```bash
# Generate model with belongs_to relationship
azu generate model comment content:text post:references user:references
```

```crystal
# src/models/comment.cr
class Comment
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, :comments

  column id : Int64, primary: true, auto: true
  column content : String
  column post_id : Int64
  column user_id : Int64

  belongs_to :post, Post
  belongs_to :user, User

  validates :content, presence: true
  validates :post_id, presence: true
  validates :user_id, presence: true
end
```

### Has Many

```crystal
# src/models/post.cr
class Post
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, :posts
  # ... other code ...

  has_many :comments, Comment
  has_many :tags, through: :post_tags

  def comment_count
    comments.count
  end
end
```

### Many to Many

```bash
# Generate join table model
azu generate model post_tag post:references tag:references
```

```crystal
# src/models/post_tag.cr
class PostTag
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, :post_tags

  column id : Int64, primary: true, auto: true
  column post_id : Int64
  column tag_id : Int64

  belongs_to :post, Post
  belongs_to :tag, Tag

  validates :post_id, presence: true
  validates :tag_id, presence: true
end
```

## Validations

### Common Validations

```bash
# Generate with validations
azu generate model user name:string email:string --validations
```

**Generated Validations:**

```crystal
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, :users
  # ... columns ...

  validates :name, presence: true
  validates :email, presence: true, format: /\A[^@\s]+@[^@\s]+\z/
  validates :age, numericality: { greater_than: 0 }, allow_nil: true
end
```

### Custom Validations

```crystal
# src/models/user.cr
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, :users
  # ... columns and basic validations ...

  validate :email_domain

  private def email_domain
    return unless email.present?

    domain = email.split("@").last
    unless ["example.com", "company.com"].includes?(domain)
      errors.add(:email, "must be from allowed domain")
    end
  end
end
```

## Scopes and Class Methods

### Generated Scopes

```crystal
# src/models/user.cr
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, users
  # ... columns and validations ...

  # Generated scopes
  scope :active, -> { where(active: true) }
  scope :admins, -> { where(role: "admin") }
  scope :recent, -> { order(created_at: :desc) }

  # Custom scopes
  def self.find_by_email(email : String)
    where(email: email).first
  end

  def self.search(query : String)
    where("name ILIKE ? OR email ILIKE ?", "%#{query}%", "%#{query}%")
  end
end
```

### Instance Methods

```crystal
# src/models/user.cr
class User
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, :users
  # ... columns and validations ...

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def admin?
    role == "admin"
  end

  def active?
    active == true
  end

  def posts_count
    posts.count
  end
end
```

## Advanced Usage

### Polymorphic Associations

```bash
# Generate polymorphic model
azu generate model like user:references likeable:references{polymorphic}
```

```crystal
# src/models/like.cr
class Like
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, :likes

  column id : Int64, primary: true, auto: true
  column user_id : Int64
  column likeable_id : Int64
  column likeable_type : String

  belongs_to :user, User
  belongs_to :likeable, polymorphic: true

  validates :user_id, presence: true
  validates :likeable_id, presence: true
  validates :likeable_type, presence: true
end
```

### STI (Single Table Inheritance)

```bash
# Generate base model
azu generate model vehicle type:string make:string model:string
```

```crystal
# src/models/vehicle.cr
class Vehicle < CQL::Model
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, :vehicles

  column id : Int64, primary: true, auto: true
  column type : String
  column make : String
  column model : String

  validates :type, presence: true
  validates :make, presence: true
  validates :model, presence: true
end

# src/models/car.cr
class Car < Vehicle
  def self.create!(attributes)
    super(attributes.merge(type: "Car"))
  end
end

# src/models/motorcycle.cr
class Motorcycle < Vehicle
  def self.create!(attributes)
    super(attributes.merge(type: "Motorcycle"))
  end
end
```

### Custom Field Types

```bash
# Generate model with custom types
azu generate model product name:string price:decimal metadata:json
```

```crystal
# src/models/product.cr
class Product
  include CQL::ActiveRecord::Model(Int32)
  db_context AppDB, :products

  column id : Int64, primary: true, auto: true
  column name : String
  column price : BigDecimal
  column metadata : JSON::Any

  validates :name, presence: true
  validates :price, numericality: { greater_than: 0 }

  def metadata_hash
    metadata.as_h
  end

  def set_metadata(key : String, value : String)
    current = metadata.as_h
    current[key] = value
    self.metadata = JSON::Any.new(current)
  end
end
```

## Testing

### Model Tests

```crystal
# spec/models/user_spec.cr
require "../spec_helper"

describe User do
  describe "validations" do
    it "is valid with valid attributes" do
      user = User.new(name: "John Doe", email: "john@example.com")
      user.valid?.should be_true
    end

    it "is invalid without name" do
      user = User.new(email: "john@example.com")
      user.valid?.should be_false
      user.errors[:name].should contain("can't be blank")
    end

    it "is invalid with invalid email" do
      user = User.new(name: "John Doe", email: "invalid-email")
      user.valid?.should be_false
      user.errors[:email].should contain("is invalid")
    end
  end

  describe "associations" do
    it "has many posts" do
      user = User.create!(name: "John", email: "john@example.com")
      post = Post.create!(title: "Test", content: "Content", user: user)

      user.posts.should contain(post)
    end
  end

  describe "scopes" do
    it "finds active users" do
      active_user = User.create!(name: "Active", email: "active@example.com", active: true)
      inactive_user = User.create!(name: "Inactive", email: "inactive@example.com", active: false)

      User.active.should contain(active_user)
      User.active.should_not contain(inactive_user)
    end
  end

  describe "instance methods" do
    it "returns full name" do
      user = User.new(first_name: "John", last_name: "Doe")
      user.full_name.should eq("John Doe")
    end
  end
end
```

## Best Practices

### 1. Naming Conventions

```bash
# Use singular names for models
azu generate model user        # Good
azu generate model users       # Avoid

# Use descriptive field names
azu generate model post title:string content:text  # Good
azu generate model post t:string c:text            # Avoid
```

### 2. Field Types

```bash
# Use appropriate field types
azu generate model user email:string age:integer  # Good
azu generate model user email:string age:string   # Avoid

# Use references for relationships
azu generate model post user:references  # Good
azu generate model post user_id:integer  # Avoid
```

### 3. Validations

```bash
# Always add validations for important fields
azu generate model user name:string email:string --validations

# Add custom validations when needed
# See custom validation examples above
```

### 4. Relationships

```crystal
# Use proper relationship definitions
belongs_to :user, User
has_many :posts, Post
has_many :tags, through: :post_tags

# Add dependent options when needed
has_many :posts, Post, dependent: :destroy
```

### 5. Performance

```crystal
# Use includes to avoid N+1 queries
User.includes(:posts).all

# Use scopes for common queries
User.active.recent.limit(10)

# Use counter_cache for counts
belongs_to :user, User, counter_cache: :posts_count
```

## Troubleshooting

### Migration Issues

```bash
# Check migration file
cat db/migrations/*_create_users.cr

# Run migration
azu db:migrate

# If migration fails, check syntax
crystal build db/migrations/*_create_users.cr
```

### Model Issues

```bash
# Check model file
cat src/models/user.cr

# Test model compilation
crystal build src/models/user.cr

# Check for syntax errors
crystal tool format src/models/user.cr
```

### Validation Issues

```crystal
# Debug validations
user = User.new
user.valid?
puts user.errors.full_messages
```

---

The model generator creates CQL ORM models with proper validations, relationships, and database migrations for your Azu application.

**Next Steps:**

- [Migration Generator](migration.md) - Create database migrations
- [Endpoint Generator](endpoint.md) - Create HTTP endpoints
- [Service Generator](service.md) - Create business logic services
