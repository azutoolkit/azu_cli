# Database Commands

Azu CLI provides database management commands that work with CQL ORM.

## Command Overview

| Command           | Description                        |
| ----------------- | ---------------------------------- |
| `azu db:create`   | Create the database                |
| `azu db:drop`     | Drop the database                  |
| `azu db:migrate`  | Run pending migrations             |
| `azu db:rollback` | Rollback migrations                |
| `azu db:reset`    | Drop, create, and migrate          |
| `azu db:setup`    | Create and migrate                 |
| `azu db:seed`     | Run seed data                      |
| `azu db:status`   | Show migration status              |

## Configuration

### Environment Variables

```bash
# Using DATABASE_URL (recommended)
export DATABASE_URL="postgresql://user:pass@localhost/myapp_dev"

# Or individual variables
export AZU_DB_HOST="localhost"
export AZU_DB_PORT="5432"
export AZU_DB_NAME="myapp_dev"
export AZU_DB_USER="username"
export AZU_DB_PASSWORD="password"
```

## azu db:create

Creates the database for the current environment.

```bash
azu db:create
azu db:create --database custom_name
azu db:create --force  # Drop existing and recreate
```

## azu db:drop

Drops the database for the current environment.

```bash
azu db:drop
azu db:drop --force  # Skip confirmation
```

## azu db:migrate

Runs pending migrations using CQL's Migrator. Automatically updates `src/db/schema.cr`.

```bash
azu db:migrate
azu db:migrate --steps 2      # Run only 2 migrations
azu db:migrate --verbose      # Show detailed output
```

### Migration File Format

```crystal
class CreateUsers < CQL::Migration(20240115103045)
  def up
    schema.table :users do
      primary :id, Int64
      text :name
      text :email
      boolean :active, default: "1"
      timestamps
    end
    schema.users.create!
  end

  def down
    schema.users.drop!
  end
end
```

### Column Types

| Method      | Crystal Type | Description       |
| ----------- | ------------ | ----------------- |
| `primary`   | Int64/UUID   | Primary key       |
| `text`      | String       | Text field        |
| `integer`   | Int32        | 32-bit integer    |
| `bigint`    | Int64        | 64-bit integer    |
| `boolean`   | Bool         | Boolean value     |
| `decimal`   | Float64      | Decimal number    |
| `timestamps`| Time         | created/updated_at|

## azu db:rollback

Rolls back migrations. Automatically updates the schema file.

```bash
azu db:rollback              # Rollback last migration
azu db:rollback --steps 3    # Rollback last 3 migrations
```

## azu db:reset

Drops, creates, and migrates the database.

```bash
azu db:reset
azu db:reset --seed   # Also run seeds
azu db:reset --force  # Skip confirmation
```

## azu db:setup

Creates the database (if needed) and runs migrations.

```bash
azu db:setup
azu db:setup --seed   # Also run seeds
```

## azu db:seed

Runs seed data from `src/db/seed.cr`.

```bash
azu db:seed
```

### Seed File Example

```crystal
# src/db/seed.cr
User.create!(name: "Admin", email: "admin@example.com")

10.times do |i|
  User.create!(name: "User #{i}", email: "user#{i}@example.com")
end
```

## azu db:status

Shows migration status.

```bash
azu db:status
```

Output:

```text
Migration Status:
  [✓] 20240115103045_create_users
  [✓] 20240116103045_create_posts
  [ ] 20240117103045_add_avatar_to_users
```

## azu generate migration

Creates a new migration file.

```bash
azu generate migration CreateUsers name:string email:string
azu generate migration AddAvatarToUsers avatar_url:string
```

### Add Column Migration

```crystal
class AddAvatarToUsers < CQL::Migration(20240116103045)
  def up
    schema.alter :users do
      add_column :avatar_url, String, null: true
    end
  end

  def down
    schema.alter :users do
      drop_column :avatar_url
    end
  end
end
```

### Add Index Migration

```crystal
class AddEmailIndexToUsers < CQL::Migration(20240117103045)
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

## Common Workflows

### Development

```bash
azu db:migrate              # Apply changes
azu db:rollback             # Undo if needed
azu db:reset --seed         # Fresh start
```

### Testing

```bash
azu db:setup                # Prepare test DB
crystal spec                # Run tests
```

### Production

```bash
azu db:migrate              # Apply migrations
azu db:status               # Verify status
```

## Troubleshooting

### Connection Issues

```bash
# Check database server
sudo systemctl status postgresql

# Test connection
psql -h localhost -U username -d myapp_dev

# Verify environment
echo $DATABASE_URL
```

### Permission Issues

```bash
sudo -u postgres createuser -s username
sudo -u postgres psql -c "GRANT ALL ON DATABASE myapp_dev TO username;"
```

### Migration Issues

```bash
azu db:status               # Check status
ls -la src/db/migrations/   # Verify files exist
```

---

**Next Steps:**

- [Migration Generator](../generators/migration.md) - Create migrations
- [Model Generator](../generators/model.md) - Create models
