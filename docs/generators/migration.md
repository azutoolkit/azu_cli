# Migration Generator

The Migration Generator creates database migration files that define schema changes for your Azu application's database.

## Usage

```bash
azu generate migration MIGRATION_NAME [OPTIONS]
```

## Description

Migrations in Azu applications provide a way to version control your database schema changes. They allow you to define, modify, and rollback database structure changes in a systematic way. Migrations are essential for maintaining database consistency across different environments and team members.

## Options

- `MIGRATION_NAME` - Name of the migration to generate (required)
- `-d, --description DESCRIPTION` - Description of the migration
- `-t, --template TEMPLATE` - Template to use (default: basic)
- `-f, --force` - Overwrite existing files
- `-h, --help` - Show help message

## Examples

### Generate a basic migration

```bash
azu generate migration CreateUsers
```

This creates:

- `src/db/migrations/TIMESTAMP_create_users.cr` - The migration file

### Generate a migration with description

```bash
azu generate migration AddEmailToUsers --description "Add email column to users table"
```

### Generate specific migration types

```bash
azu generate migration CreatePosts --template table
azu generate migration AddIndexToUsers --template index
```

## Generated Files

### Migration File (`src/db/migrations/TIMESTAMP_MIGRATION_NAME.cr`)

```crystal
# <%= @description || @name.underscore.humanize %> migration
class <%= @name.underscore.camelcase %> < CQL::Migration
  def up
    # Add your migration logic here
    # Example:
    # create_table :users do |t|
    #   t.string :name
    #   t.string :email
    #   t.timestamps
    # end
  end

  def down
    # Add your rollback logic here
    # Example:
    # drop_table :users
  end
end
```

## Migration Patterns

### Create Table Migration

```crystal
class CreateUsers < CQL::Migration
  def up
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false, unique: true
      t.string :password_digest, null: false
      t.boolean :active, default: true
      t.timestamps
    end
  end

  def down
    drop_table :users
  end
end
```

### Add Column Migration

```crystal
class AddEmailToUsers < CQL::Migration
  def up
    add_column :users, :email, :string, null: false, unique: true
    add_index :users, :email
  end

  def down
    remove_index :users, :email
    remove_column :users, :email
  end
end
```

### Create Index Migration

```crystal
class AddIndexToUsers < CQL::Migration
  def up
    add_index :users, :email, unique: true
    add_index :users, :created_at
    add_index :users, [:name, :email]
  end

  def down
    remove_index :users, [:name, :email]
    remove_index :users, :created_at
    remove_index :users, :email
  end
end
```

### Modify Column Migration

```crystal
class ModifyUserEmail < CQL::Migration
  def up
    change_column :users, :email, :string, null: false, limit: 255
  end

  def down
    change_column :users, :email, :string, null: true, limit: nil
  end
end
```

### Create Join Table Migration

```crystal
class CreateUsersPosts < CQL::Migration
  def up
    create_table :users_posts, id: false do |t|
      t.integer :user_id, null: false
      t.integer :post_id, null: false
      t.timestamps
    end

    add_index :users_posts, :user_id
    add_index :users_posts, :post_id
    add_index :users_posts, [:user_id, :post_id], unique: true
  end

  def down
    drop_table :users_posts
  end
end
```

## Column Types

### Supported Column Types

```crystal
# String columns
t.string :name, null: false, limit: 255
t.text :description, null: true

# Numeric columns
t.integer :age, null: true
t.bigint :user_id, null: false
t.float :price, null: false
t.decimal :amount, precision: 10, scale: 2

# Boolean columns
t.boolean :active, default: true
t.boolean :verified, null: false

# Date/Time columns
t.datetime :created_at, null: false
t.date :birth_date, null: true
t.time :start_time, null: true

# Binary columns
t.binary :avatar, null: true
t.blob :document, null: true

# JSON columns
t.json :metadata, null: true
t.jsonb :settings, null: true
```

### Column Options

```crystal
create_table :users do |t|
  # Basic options
  t.string :name, null: false
  t.string :email, unique: true
  t.string :code, limit: 10

  # Default values
  t.boolean :active, default: true
  t.integer :count, default: 0
  t.string :status, default: "pending"

  # Indexes
  t.string :username, index: true
  t.string :email, unique: true

  # Timestamps
  t.timestamps
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
```

### Run Specific Migration

```bash
azu db:migrate VERSION=20240115000000
```

### Rollback Migrations

```bash
azu db:rollback
```

### Rollback Specific Migration

```bash
azu db:rollback VERSION=20240115000000
```

### Check Migration Status

```bash
azu db:migrate:status
```

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
- `azu db:reset` - Reset the database
- `azu generate model` - Generate data models

## Templates

The migration generator supports different templates:

- `basic` - Simple migration with basic structure
- `table` - Table creation migration template
- `add_column` - Add column migration template
- `add_index` - Add index migration template
- `foreign_key` - Foreign key migration template

To use a specific template:

```bash
azu generate migration CreatePosts --template table
```
