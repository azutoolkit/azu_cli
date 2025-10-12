# Migration Generator

The Migration Generator creates CQL-based database migration files that use type-safe Schema DSL for defining schema changes.

## Usage

```bash
azu generate migration MIGRATION_NAME [attributes] [OPTIONS]
```

## Description

Migrations in Azu applications use CQL's powerful migration system to version control database schema changes. They provide:

- **Type-Safe Migrations**: Crystal classes with compile-time type checking
- **Automatic Schema Sync**: Schema file automatically updates after migrations
- **CQL Schema DSL**: Expressive syntax for defining tables, columns, and indexes
- **Version Tracking**: Int64 timestamp-based version numbers
- **Rollback Support**: Reversible migrations with `up` and `down` methods

Migrations inherit from `CQL::Migration(VERSION)` and use CQL's Schema DSL for all database operations.

## Options

- `MIGRATION_NAME` - Name of the migration to generate (required)
- `attributes` - Column definitions in `name:type` format (optional)
- `--timestamps` - Add timestamps (default: true)
- `-f, --force` - Overwrite existing files
- `-h, --help` - Show help message

## Examples

### Generate a migration with attributes

```bash
azu generate migration CreateUsers name:string email:string age:int32
```

This creates:

- `src/db/migrations/20240115103045_create_users.cr` - The migration file

### Generate a simple migration

```bash
azu generate migration AddIndexToUsers
```

### Generate migration with foreign keys

```bash
azu generate migration CreatePosts title:string content:text user_id:references
```

### Generate migration with various types

```bash
azu generate migration CreateProducts name:string price:float64 active:bool published_at:datetime
```

## Generated Files

### Migration File (`src/db/migrations/TIMESTAMP_create_table_name.cr`)

The generator creates a properly formatted CQL migration using the Schema DSL:

```crystal
require "cql"

# Migration to create users table
# Generated at 2024-01-15 10:30:45 UTC
class CreateUsers < CQL::Migration(20240115103045_i64)
  def up
    # Create users table
    schema.table :users do
      primary :id, Int64
      column :name, String
      column :email, String
      column :age, Int32
      timestamps
    end

    # Create the table in the database
    schema.users.create!

    # Add indexes (automatically generated for email fields, etc.)
    schema.alter :users do
      create_index :email_idx, [:email], unique: true
    end
  end

  def down
    # Drop users table
    schema.users.drop!
  end
end
```

## Migration Patterns

### Create Table Migration

```crystal
class CreateUsers < CQL::Migration(20240115103045_i64)
  def up
    schema.table :users do
      primary :id, Int64
      column :name, String
      column :email, String
      column :password_digest, String
      column :active, Bool, default: false
      timestamps
    end

    schema.users.create!

    # Add unique index for email
    schema.alter :users do
      create_index :email_idx, [:email], unique: true
    end
  end

  def down
    schema.users.drop!
  end
end
```

### Add Column Migration

```crystal
class AddEmailToUsers < CQL::Migration(20240115104530_i64)
  def up
    schema.alter :users do
      add_column :email, String
    end

    # Add index for the new column
    schema.alter :users do
      create_index :email_idx, [:email], unique: true
    end
  end

  def down
    schema.alter :users do
      drop_index :email_idx
      drop_column :email
    end
  end
end
```

### Create Index Migration

```crystal
class AddIndexesToUsers < CQL::Migration(20240115105020_i64)
  def up
    schema.alter :users do
      create_index :email_idx, [:email], unique: true
      create_index :created_at_idx, [:created_at]
      create_index :name_email_idx, [:name, :email]
    end
  end

  def down
    schema.alter :users do
      drop_index :name_email_idx
      drop_index :created_at_idx
      drop_index :email_idx
    end
  end
end
```

### Create Table with Foreign Key

```crystal
class CreatePosts < CQL::Migration(20240115110000_i64)
  def up
    schema.table :posts do
      primary :id, Int64
      column :title, String
      column :content, String
      column :user_id, Int64
      column :published, Bool, default: false
      timestamps

      # Foreign key constraint
      foreign_key [:user_id], references: :users, references_columns: [:id]
    end

    schema.posts.create!

    # Add indexes
    schema.alter :posts do
      create_index :user_id_idx, [:user_id]
      create_index :published_idx, [:published]
    end
  end

  def down
    schema.posts.drop!
  end
end
```

### Create Join Table Migration

```crystal
class CreateUsersPostsJoin < CQL::Migration(20240115111530_i64)
  def up
    schema.table :users_posts do
      column :user_id, Int64
      column :post_id, Int64
      timestamps

      foreign_key [:user_id], references: :users, references_columns: [:id]
      foreign_key [:post_id], references: :posts, references_columns: [:id]
    end

    schema.users_posts.create!

    schema.alter :users_posts do
      create_index :user_id_idx, [:user_id]
      create_index :post_id_idx, [:post_id]
      create_index :user_post_idx, [:user_id, :post_id], unique: true
    end
  end

  def down
    schema.users_posts.drop!
  end
end
```

## Column Types

### Supported Column Types (CQL Schema DSL)

The generator supports the following attribute type mappings:

| Generator Type     | Crystal Type | Usage                                    |
| ------------------ | ------------ | ---------------------------------------- |
| `string`, `text`   | `String`     | Text data                                |
| `int32`, `integer` | `Int32`      | 32-bit integers                          |
| `int64`            | `Int64`      | 64-bit integers (default for primary)    |
| `float32`          | `Float32`    | 32-bit floating point                    |
| `float64`, `float` | `Float64`    | 64-bit floating point                    |
| `bool`, `boolean`  | `Bool`       | Boolean values (true/false)              |
| `datetime`, `time` | `Time`       | Date and time                            |
| `date`             | `Date`       | Date only                                |
| `email`            | `String`     | Email (with unique index auto-generated) |
| `url`              | `String`     | URL string                               |
| `json`             | `JSON::Any`  | JSON data                                |
| `uuid`             | `UUID`       | UUID values                              |
| `references`       | `Int64`      | Foreign key reference                    |

### CQL Schema DSL Syntax

```crystal
schema.table :users do
  # Primary key (Int64 by default)
  primary :id, Int64

  # String columns
  column :name, String
  column :email, String

  # Numeric columns
  column :age, Int32
  column :user_id, Int64
  column :price, Float64

  # Boolean columns (with default)
  column :active, Bool, default: false
  column :verified, Bool, default: false

  # Time columns
  timestamps  # Adds created_at and updated_at

  # Foreign keys (defined inline)
  foreign_key [:user_id], references: :users, references_columns: [:id]
end
```

### Adding Indexes

Indexes are added using `schema.alter`:

```crystal
schema.alter :users do
  # Single column index
  create_index :email_idx, [:email]

  # Unique index
  create_index :email_idx, [:email], unique: true

  # Composite index
  create_index :name_email_idx, [:name, :email]

  # Drop index
  drop_index :email_idx
end
```

## Index Types

### Single Column Indexes

```crystal
# Basic index
add_index :users, :email

# Unique index
add_index :users, :email, unique: true

# Named index
add_index :users, :email, name: "idx_users_email"
```

### Multi-Column Indexes

```crystal
# Composite index
add_index :users, [:first_name, :last_name]

# Unique composite index
add_index :users, [:email, :domain], unique: true

# Named composite index
add_index :users, [:status, :created_at], name: "idx_users_status_created"
```

### Partial Indexes

```crystal
# Partial index (PostgreSQL)
add_index :users, :email, where: "active = true"

# Partial unique index
add_index :users, :email, unique: true, where: "deleted_at IS NULL"
```

## Running Migrations

### Run All Migrations

```bash
azu db:migrate
# Running migrations...
# ✓ All migrations completed successfully
# ✓ Schema file updated: src/db/schema.cr
```

### Run Specific Number of Migrations

```bash
azu db:migrate --steps 2
```

### Migrate to Specific Version

```bash
azu db:migrate --version 20240115103045
```

### Rollback Migrations

```bash
# Rollback last migration
azu db:rollback

# Rollback multiple migrations
azu db:rollback --steps 3

# Rollback to specific version
azu db:rollback --version 20240115103045
```

### View Verbose Output

```bash
azu db:migrate --verbose
# Shows detailed migration information
```

### How Migrations Run

When you execute `azu db:migrate`, the CLI:

1. Creates a temporary Crystal script
2. Loads `src/db/schema.cr` and all migration files from `src/db/migrations/*.cr`
3. Initializes CQL's `Migrator` with auto-sync enabled
4. Runs pending migrations using `migrator.up`
5. Automatically updates `src/db/schema.cr` to reflect current database state
6. Cleans up temporary files

The schema file (`src/db/schema.cr`) is always kept in sync with your database!

## Best Practices

### 1. Use Descriptive Names

```crystal
# Good: Clear and descriptive
class CreateUsersTable < CQL::Migration
class AddEmailColumnToUsers < CQL::Migration
class AddIndexToUsersEmail < CQL::Migration

# Avoid: Vague names
class Migration1 < CQL::Migration
class UpdateTable < CQL::Migration
```

### 2. Keep Migrations Focused

Each migration should make one logical change:

```crystal
# Good: Single purpose
class AddEmailToUsers < CQL::Migration
  def up
    add_column :users, :email, :string
  end
end

# Good: Separate migration for index
class AddEmailIndexToUsers < CQL::Migration
  def up
    add_index :users, :email
  end
end
```

### 3. Always Provide Rollback Logic

```crystal
class CreateUsers < CQL::Migration
  def up
    create_table :users do |t|
      t.string :name
      t.string :email
      t.timestamps
    end
  end

  def down
    drop_table :users
  end
end
```

### 4. Use Data Types Appropriately

```crystal
# Good: Appropriate data types
create_table :users do |t|
  t.string :name, null: false, limit: 100
  t.string :email, null: false, unique: true
  t.text :bio, null: true
  t.integer :age, null: true
  t.decimal :balance, precision: 10, scale: 2, default: 0
  t.boolean :active, default: true
  t.timestamps
end
```

### 5. Add Indexes for Performance

```crystal
# Add indexes for frequently queried columns
add_index :users, :email, unique: true
add_index :posts, :user_id
add_index :posts, :created_at
add_index :posts, [:user_id, :created_at]
```

## Testing Migrations

### Unit Testing

```crystal
describe CreateUsers do
  describe "#up" do
    it "creates users table" do
      migration = CreateUsers.new

      migration.up

      # Verify table exists
      table_exists?(:users).should be_true
    end

    it "creates required columns" do
      migration = CreateUsers.new

      migration.up

      # Verify columns exist
      column_exists?(:users, :name).should be_true
      column_exists?(:users, :email).should be_true
    end
  end

  describe "#down" do
    it "drops users table" do
      migration = CreateUsers.new

      migration.up
      migration.down

      table_exists?(:users).should be_false
    end
  end
end
```

### Integration Testing

```crystal
describe "Migration integration" do
  it "runs migrations successfully" do
    # Run migrations
    system("azu db:migrate")

    # Verify database state
    # Check tables, columns, indexes, etc.
  end

  it "rolls back migrations successfully" do
    # Run migrations
    system("azu db:migrate")

    # Rollback
    system("azu db:rollback")

    # Verify rollback
  end
end
```

## Common Migration Patterns

### 1. Table Creation

```crystal
class CreatePosts < CQL::Migration
  def up
    create_table :posts do |t|
      t.string :title, null: false
      t.text :content, null: false
      t.string :slug, null: false, unique: true
      t.integer :user_id, null: false
      t.boolean :published, default: false
      t.datetime :published_at, null: true
      t.timestamps
    end

    add_index :posts, :user_id
    add_index :posts, :slug, unique: true
    add_index :posts, :published
  end

  def down
    drop_table :posts
  end
end
```

### 2. Adding Foreign Keys

```crystal
class AddForeignKeyToPosts < CQL::Migration
  def up
    add_foreign_key :posts, :users, column: :user_id
  end

  def down
    remove_foreign_key :posts, :users
  end
end
```

### 3. Data Migration

```crystal
class MigrateUserData < CQL::Migration
  def up
    # Add new column
    add_column :users, :full_name, :string

    # Migrate data
    execute "UPDATE users SET full_name = CONCAT(first_name, ' ', last_name)"

    # Remove old columns
    remove_column :users, :first_name
    remove_column :users, :last_name
  end

  def down
    # Add old columns back
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string

    # Restore data (simplified)
    execute "UPDATE users SET first_name = SPLIT_PART(full_name, ' ', 1), last_name = SPLIT_PART(full_name, ' ', 2)"

    # Remove new column
    remove_column :users, :full_name
  end
end
```

### 4. Schema Changes

```crystal
class ModifyUserSchema < CQL::Migration
  def up
    # Change column type
    change_column :users, :age, :integer, null: true

    # Add new column with default
    add_column :users, :status, :string, default: "active"

    # Add index
    add_index :users, :status
  end

  def down
    remove_index :users, :status
    remove_column :users, :status
    change_column :users, :age, :string, null: false
  end
end
```

## Related Commands

- `azu db:migrate` - Run database migrations
- `azu db:rollback` - Rollback database migrations
- `azu db:create` - Create the database
- `azu db:drop` - Drop the database
- `azu db:reset` - Reset the database
- `azu db:setup` - Setup database (create and migrate)
- `azu generate model` - Generate CQL data models
- `azu generate scaffold` - Generate full CRUD scaffold

## Key Differences from Other ORMs

### CQL vs ActiveRecord/Eloquent

**Traditional ORMs:**

```ruby
# ActiveRecord style
class CreateUsers < ActiveRecord::Migration
  def change
    create_table :users do |t|
      t.string :name
      t.string :email
      t.timestamps
    end
  end
end
```

**CQL Migrations:**

```crystal
# CQL Schema DSL style
class CreateUsers < CQL::Migration(20240115103045_i64)
  def up
    schema.table :users do
      primary :id, Int64
      column :name, String
      column :email, String
      timestamps
    end
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
```

**Key Benefits:**

- ✅ Type-safe at compile time
- ✅ Automatic schema file synchronization
- ✅ Int64 timestamp versions (no collisions)
- ✅ Crystal's performance benefits
- ✅ Explicit `up`/`down` methods (no magic `change`)

## Additional Resources

- **Migration System Guide**: [../../MIGRATION_FIXES_SUMMARY.md](../../MIGRATION_FIXES_SUMMARY.md)
- **CQL Documentation**: [../integration/cql-orm.md](../integration/cql-orm.md)
- **Database Commands**: [../commands/database.md](../commands/database.md)
- **CQL GitHub**: https://github.com/azutoolkit/cql
- **CQL Examples**: https://github.com/azutoolkit/cql/tree/master/examples/migrations
