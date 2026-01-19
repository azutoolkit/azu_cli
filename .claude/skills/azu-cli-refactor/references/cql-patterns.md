# CQL Framework Patterns Reference

This document defines the **accurate** patterns that azu_cli must enforce when generating CQL database code.

## Schema Definition Pattern

CQL uses `CQL::Schema.define` with a block to define the database schema.

### Basic Schema

```crystal
require "cql"
require "sqlite3"  # or "pg" or "mysql"

# Define database schema with compile-time validation
BlogDB = CQL::Schema.define(
  :blog_database,
  adapter: CQL::Adapter::SQLite,
  uri: "sqlite3://db/blog.db"
) do
  table :users do
    primary :id, Int64
    text :username
    text :email
    text :first_name, null: true
    text :last_name, null: true
    boolean :active, default: "1"
    timestamps
  end

  table :posts do
    primary :id, Int64
    text :title
    text :content
    boolean :published, default: "0"
    bigint :user_id
    timestamps

    # Type-safe foreign key relationships
    foreign_key [:user_id], references: :users, references_columns: [:id]
  end

  table :comments do
    primary :id, Int64
    text :body
    bigint :user_id
    bigint :post_id
    timestamps

    foreign_key [:user_id], references: :users, references_columns: [:id]
    foreign_key [:post_id], references: :posts, references_columns: [:id]
  end
end

# Create tables
BlogDB.users.create!
BlogDB.posts.create!
BlogDB.comments.create!
```

### PostgreSQL Schema with Advanced Features

```crystal
AppDB = CQL::Schema.define(
  :app_database,
  adapter: CQL::Adapter::Postgres,
  uri: ENV["DATABASE_URL"]
) do
  table :products do
    primary :id, UUID                    # UUID primary keys
    text :name
    decimal :price, precision: 10, scale: 2
    text :metadata                       # Can store JSON
    timestamps

    # Optimized indexing
    index :name, unique: true
    index [:price, :created_at]          # Composite indexes
  end
end
```

### Column Types Reference

| Method | Crystal Type | Database Type | Options |
|--------|--------------|---------------|---------|
| `primary` | Int64/UUID | PRIMARY KEY | auto_increment |
| `text` | String | VARCHAR/TEXT | `null: Bool`, `default: String` |
| `integer` | Int32 | INTEGER | `null: Bool`, `default: Int` |
| `bigint` | Int64 | BIGINT | `null: Bool`, `default: Int` |
| `boolean` | Bool | BOOLEAN | `null: Bool`, `default: String` |
| `decimal` | Float64 | DECIMAL | `precision: Int`, `scale: Int` |
| `timestamps` | - | created_at, updated_at | - |

## Model Pattern

Models use `include CQL::ActiveRecord::Model(PrimaryKeyType)` with `db_context` macro.

### Basic Model

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :users

  getter id : Int64?
  getter username : String
  getter email : String
  getter first_name : String?
  getter last_name : String?
  getter? active : Bool = true
  getter created_at : Time?
  getter updated_at : Time?

  # Compile-time validated relationships
  has_many :posts, Post, foreign_key: :user_id
  has_many :comments, Comment, foreign_key: :user_id

  # Built-in validations
  validate :username, presence: true, size: 2..50
  validate :email, required: true, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  def initialize(@username : String, @email : String,
                 @first_name : String? = nil, @last_name : String? = nil)
  end

  def full_name
    if first_name && last_name
      "#{first_name} #{last_name}"
    else
      username
    end
  end
end
```

### Model with UUID Primary Key

```crystal
struct Product
  include CQL::ActiveRecord::Model(UUID)
  db_context AppDB, :products

  getter id : UUID?
  getter name : String
  getter price : Float64
  getter metadata : String?
  getter created_at : Time?
  getter updated_at : Time?

  validate :name, presence: true, size: 2..100
  validate :price, gt: 0.0, lt: 1_000_000.0

  def initialize(@name : String, @price : Float64, @metadata : String? = nil)
  end
end
```

### Model with Relationships

```crystal
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :posts

  getter id : Int64?
  getter title : String
  getter content : String
  getter? published : Bool = false
  getter user_id : Int64
  getter created_at : Time?
  getter updated_at : Time?

  # Relationships
  belongs_to :user, User, foreign_key: :user_id
  has_many :comments, Comment, foreign_key: :post_id
  many_to_many :tags, Tag, join_through: :post_tags

  # Validations
  validate :title, presence: true, size: 1..100
  validate :content, presence: true

  # Scopes - reusable query patterns
  scope :published, -> { where(published: true) }
  scope :recent, -> { where("created_at > ?", 1.week.ago).order(created_at: :desc) }
  scope :by_user, ->(user_id : Int64) { where(user_id: user_id) }

  def initialize(@title : String, @content : String, @user_id : Int64)
  end
end
```

## Relationship Patterns

### belongs_to

```crystal
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :posts

  belongs_to :user, User, foreign_key: :user_id
  belongs_to :category, Category, foreign_key: :category_id
end
```

### has_many

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :users

  has_many :posts, Post, foreign_key: :user_id
  has_many :comments, Comment, foreign_key: :user_id
end
```

### has_one

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :users

  has_one :profile, UserProfile, foreign_key: :user_id
end
```

### many_to_many

```crystal
struct Post
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :posts

  many_to_many :tags, Tag, join_through: :post_tags
end
```

## Validation Patterns

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :users

  # Presence validation
  validate :name, presence: true

  # Required (same as presence)
  validate :email, required: true

  # Size/length validation
  validate :username, size: 2..50

  # Format validation with regex
  validate :email, match: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  # Numeric validations
  validate :age, gt: 0, lt: 120
  validate :price, gte: 0.0, lte: 1_000_000.0

  # Inclusion validation
  validate :status, inclusion: {in: %w[active inactive pending]}

  # Custom validators
  use EmailValidator
  use UniqueRecordValidator
end
```

## Migration Pattern

Migrations use `CQL::Migration(timestamp)` with `up` and `down` methods.

### Create Table Migration

```crystal
class CreateUsersTable < CQL::Migration(20240101120000)
  def up
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
```

### Add Column Migration

```crystal
class AddAvatarToUsers < CQL::Migration(20240102120000)
  def up
    schema.alter :users do
      add_column :avatar_url, String, null: true
      add_column :bio, String, null: true
    end
  end

  def down
    schema.alter :users do
      drop_column :avatar_url
      drop_column :bio
    end
  end
end
```

### Add Index Migration

```crystal
class AddEmailIndexToUsers < CQL::Migration(20240103120000)
  def up
    schema.alter :users do
      create_index :idx_users_email, [:email], unique: true
    end
  end

  def down
    schema.alter :users do
      drop_index :idx_users_email
    end
  end
end
```

### Add Foreign Key Migration

```crystal
class AddOrganizationToUsers < CQL::Migration(20240104120000)
  def up
    schema.alter :users do
      add_column :organization_id, Int64, null: true
    end
    
    # Add foreign key constraint
    schema.alter :users do
      add_foreign_key [:organization_id], references: :organizations, references_columns: [:id]
    end
  end

  def down
    schema.alter :users do
      drop_column :organization_id
    end
  end
end
```

### Running Migrations

```crystal
migrator = CQL::Migrator.new(BlogDB)
migrator.up           # Apply all pending migrations
migrator.down(1)      # Rollback last migration
migrator.status       # Check migration status
```

## Query Building Patterns

### Basic CRUD Operations

```crystal
# Create
user = User.new("alice", "alice@example.com")
user.save  # Returns true/false
# OR
user = User.create!(username: "alice", email: "alice@example.com")  # Raises on failure

# Read
user = User.find(1.to_i64)           # Find by ID
user = User.find_by(email: "alice@example.com")  # Find by attribute
users = User.all                      # Get all records
users = User.where(active: true).all  # Filtered query

# Update
user.username = "alice_updated"
user.save!

# Delete
user.destroy!
```

### Advanced Queries

```crystal
# Chainable where clauses
users = User.where(active: true)
           .where("created_at > ?", 1.week.ago)
           .all

# Ordering
posts = Post.order(created_at: :desc).all
posts = Post.order(:title, :created_at).all

# Limiting
posts = Post.limit(10).offset(20).all

# Counting
count = User.where(active: true).count

# Existence check
exists = User.where(email: "test@example.com").exists?

# Joins
posts = Post.joins(:user)
           .where(users: {active: true})
           .all

# Eager loading (prevents N+1)
users = User.preload(:posts).where(active: true).all

# Using scopes
trending = Post.published.recent.popular.limit(10).all
```

### Transaction Support

```crystal
# Simple transaction
User.transaction do |tx|
  user = User.create!(username: "john", email: "john@example.com")
  user.posts.create!(title: "First Post", content: "Hello!")
  # Automatic rollback on exception
end

# Nested transactions with savepoints
User.transaction do |outer_tx|
  user = User.create!(username: "alice", email: "alice@example.com")

  User.transaction(outer_tx) do |inner_tx|
    risky_operation()
  rescue
    inner_tx.rollback  # Only inner transaction rolls back
  end
end
```

## Callbacks Pattern

```crystal
struct User
  include CQL::ActiveRecord::Model(Int64)
  db_context BlogDB, :users

  # Before callbacks
  before_validation :normalize_email
  before_save :set_defaults
  before_create :generate_token
  before_update :track_changes
  before_destroy :cleanup_associations

  # After callbacks
  after_validation :log_validation_result
  after_save :update_cache
  after_create :send_welcome_email
  after_update :notify_changes
  after_destroy :remove_from_search_index

  private def normalize_email
    self.email = email.downcase.strip
  end

  private def set_defaults
    self.active = true if active.nil?
  end

  private def send_welcome_email
    SendWelcomeEmailJob.perform_async(id)
  end
end
```

## Migration Naming Convention

Format: `YYYYMMDDHHMMSS_description.cr`

| Action | Naming Pattern | Example |
|--------|----------------|---------|
| Create table | `create_<table>` | `20240115100000_create_users.cr` |
| Add column | `add_<column>_to_<table>` | `20240116100000_add_avatar_to_users.cr` |
| Remove column | `remove_<column>_from_<table>` | `20240117100000_remove_avatar_from_users.cr` |
| Add index | `add_index_to_<table>_<columns>` | `20240118100000_add_index_to_users_email.cr` |
| Add foreign key | `add_<table>_to_<other>` | `20240119100000_add_organization_to_users.cr` |

## File Organization

```
src/
├── schemas/
│   └── blog_db.cr           # CQL::Schema.define
├── models/
│   ├── user.cr
│   ├── post.cr
│   └── comment.cr
db/
└── migrations/
    ├── 20240115100000_create_users.cr
    ├── 20240115100001_create_posts.cr
    ├── 20240115100002_create_comments.cr
    └── 20240116100000_add_avatar_to_users.cr
```

## Naming Conventions

| Component | Convention | Example |
|-----------|------------|---------|
| Schema | PascalCase + DB | `BlogDB`, `AppDB` |
| Table | snake_case plural | `users`, `blog_posts` |
| Column | snake_case | `user_id`, `created_at` |
| Model | PascalCase singular | `User`, `BlogPost` |
| Migration | Timestamp + Description | `20240115_create_users` |
| Foreign Key | model_id | `user_id`, `post_id` |
| Index | idx_table_columns | `idx_users_email` |
