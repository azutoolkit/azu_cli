# Model Generator

The model generator creates CQL ORM models for your Azu application. Models represent database tables and provide an object-oriented interface for database operations.

## Overview

```bash
azu generate model <name> [field:type] [options]
```

## Basic Usage

```bash
# Generate a basic model
azu generate model user

# Generate with fields
azu generate model user name:string email:string age:int32

# Generate with relationships
azu generate model post title:string content:text user_id:references
```

## Command Options

| Option             | Description                      | Default |
| ------------------ | -------------------------------- | ------- |
| `--timestamps`     | Add created_at/updated_at fields | true    |
| `--uuid`           | Use UUID as primary key          | false   |
| `--skip-migration` | Don't generate migration file    | false   |
| `--force`          | Overwrite existing files         | false   |

## Field Types

| Type         | Crystal Type | Database Type | Description            |
| ------------ | ------------ | ------------- | ---------------------- |
| `string`     | `String`     | VARCHAR/TEXT  | Short text field       |
| `text`       | `String`     | TEXT          | Long text field        |
| `int32`      | `Int32`      | INTEGER       | 32-bit integer         |
| `int64`      | `Int64`      | BIGINT        | 64-bit integer         |
| `float64`    | `Float64`    | DECIMAL       | Floating point number  |
| `bool`       | `Bool`       | BOOLEAN       | True/false value       |
| `date`       | `Date`       | DATE          | Date only              |
| `time`       | `Time`       | TIMESTAMP     | Date and time          |
| `json`       | `JSON::Any`  | JSON/JSONB    | JSON data              |
| `uuid`       | `UUID`       | UUID          | UUID field             |
| `references` | `Int64`      | BIGINT        | Foreign key reference  |

## Generated Files

### Model File

```crystal
# src/models/user.cr
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users

  getter id : Int64?
  getter name : String
  getter email : String
  getter age : Int32?
  getter created_at : Time?
  getter updated_at : Time?

  # Validations
  validate :name, presence: true, size: 2..100
  validate :email, presence: true

  def initialize(@name : String, @email : String, @age : Int32? = nil)
  end
end
```

### Migration File

```crystal
# src/db/migrations/20240115103045_create_users.cr
class CreateUsers < CQL::Migration(20240115103045)
  def up
    schema.table :users do
      primary :id, Int64
      text :name
      text :email
      integer :age, null: true
      timestamps
    end
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
```

## Examples

### User Model

```bash
azu generate model user name:string email:string age:int32
```

**Generated Model:**

```crystal
# src/models/user.cr
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users

  getter id : Int64?
  getter name : String
  getter email : String
  getter age : Int32?
  getter created_at : Time?
  getter updated_at : Time?

  validate :name, presence: true, size: 2..100
  validate :email, presence: true

  def initialize(@name : String, @email : String, @age : Int32? = nil)
  end
end
```

### Post Model with Relationships

```bash
azu generate model post title:string content:text user_id:references
```

**Generated Model:**

```crystal
# src/models/post.cr
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :posts

  getter id : Int64?
  getter title : String
  getter content : String
  getter user_id : Int64
  getter created_at : Time?
  getter updated_at : Time?

  belongs_to :user, User, foreign_key: :user_id
  has_many :comments, Comment, foreign_key: :post_id

  validate :title, presence: true, size: 1..100
  validate :content, presence: true

  scope :published, -> { where(published: true) }

  def initialize(@title : String, @content : String, @user_id : Int64)
  end
end
```

### Category Model with UUID

```bash
azu generate model category name:string description:text --uuid
```

**Generated Model:**

```crystal
# src/models/category.cr
struct Category
  include CQL::ActiveRecord::Model(UUID)
  db_context AppDB, :categories

  getter id : UUID?
  getter name : String
  getter description : String?
  getter created_at : Time?
  getter updated_at : Time?

  validate :name, presence: true, size: 2..100

  def initialize(@name : String, @description : String? = nil)
  end
end
```

## Relationships

### belongs_to

```crystal
# src/models/comment.cr
struct Comment
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :comments

  getter id : Int64?
  getter content : String
  getter post_id : Int64
  getter user_id : Int64
  getter created_at : Time?
  getter updated_at : Time?

  belongs_to :post, Post, foreign_key: :post_id
  belongs_to :user, User, foreign_key: :user_id

  validate :content, presence: true

  def initialize(@content : String, @post_id : Int64, @user_id : Int64)
  end
end
```

### has_many

```crystal
# src/models/user.cr
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users

  has_many :posts, Post, foreign_key: :user_id
  has_many :comments, Comment, foreign_key: :user_id
end
```

### has_one

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users

  has_one :profile, UserProfile, foreign_key: :user_id
end
```

### many_to_many

```crystal
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :posts

  many_to_many :tags, Tag, join_through: :post_tags
end
```

## Validations

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :users

  # Presence validation
  validate :name, presence: true

  # Size/length validation
  validate :username, size: 2..50

  # Format validation with regex
  validate :email, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  # Numeric validations
  validate :age, gt: 0, lt: 120
  validate :price, gte: 0.0, lte: 1_000_000.0

  # Inclusion validation
  validate :status, inclusion: {in: %w[active inactive pending]}
end
```

## Scopes

```crystal
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context AppDB, :posts

  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id : Int64) { where(user_id: user_id) }
end
```

## Query Examples

```crystal
# Create
user = User.new("alice", "alice@example.com")
user.save

# Find
user = User.find(1_i64)
user = User.find_by(email: "alice@example.com")

# Query
users = User.where(active: true).all
posts = Post.published.recent.limit(10).all

# Update
user.username = "alice_updated"
user.save!

# Delete
user.destroy!
```

---

**Next Steps:**

- [Migration Generator](migration.md) - Create database migrations
- [Endpoint Generator](endpoint.md) - Create HTTP endpoints
