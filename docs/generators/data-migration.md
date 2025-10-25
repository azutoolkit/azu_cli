# Data Migration Generator

Generate CQL data migrations for transforming and populating data independently from schema migrations.

## Synopsis

```bash
azu generate data_migration <name>
```

## Description

Data migrations are specialized scripts for transforming existing data, seeding databases, or performing one-time data operations. Unlike schema migrations that modify database structure, data migrations work with the data itself—updating records, migrating data between tables, importing external data, or performing complex transformations.

## Key Differences: Schema vs. Data Migrations

| Aspect            | Schema Migration           | Data Migration              |
| ----------------- | -------------------------- | --------------------------- |
| **Purpose**       | Modify database structure  | Transform existing data     |
| **Examples**      | Add columns, create tables | Update records, import data |
| **Reversibility** | Usually reversible         | Often irreversible          |
| **When to Run**   | On deploy                  | On-demand or scheduled      |
| **Dependencies**  | Database schema            | Application models          |
| **Location**      | `db/migrations/`           | `db/data_migrations/`       |

## Usage

### Basic Usage

Generate a data migration:

```bash
azu generate data_migration migrate_user_roles
```

This creates:

```
src/db/data_migrations/20240101120000_data_migrate_user_roles.cr
```

### Common Scenarios

#### Backfill New Column

```bash
azu generate data_migration backfill_user_slugs
```

#### Migrate Data Between Tables

```bash
azu generate data_migration migrate_posts_to_articles
```

#### Import External Data

```bash
azu generate data_migration import_legacy_users
```

#### Transform Existing Data

```bash
azu generate data_migration normalize_email_addresses
```

#### Archive Old Data

```bash
azu generate data_migration archive_old_orders
```

## Generated File Structure

### File Location

```
src/db/data_migrations/
└── 20240101120000_data_migrate_user_roles.cr
```

### File Content

```crystal
# Data migration: Migrate User Roles
# Created: 2024-01-01 12:00:00 UTC
#
# Purpose: [Describe what this data migration does]
#
# Usage:
#   crystal run src/db/data_migrations/20240101120000_data_migrate_user_roles.cr

require "../../src/models/**"
require "cql"

module DataMigrations
  class MigrateUserRoles
    # Perform the data migration
    def self.up
      puts "Starting data migration: MigrateUserRoles"

      # Your data migration logic here
      # Example:
      # User.all.each do |user|
      #   # Transform or update user data
      # end

      puts "Data migration completed successfully"
    end

    # Rollback the data migration (if possible)
    def self.down
      puts "Rolling back data migration: MigrateUserRoles"

      # Rollback logic here (if applicable)
      # Note: Many data migrations cannot be reversed

      puts "Data migration rolled back successfully"
    end

    # Helper method to run migration
    def self.run
      up
    end
  end
end

# Run the migration
DataMigrations::MigrateUserRoles.run
```

## Common Data Migration Patterns

### 1. Backfill Column Values

When you add a new column and need to populate it with calculated or default values:

```crystal
# src/db/data_migrations/20240101120000_data_backfill_user_slugs.cr
require "../../src/models/**"

module DataMigrations
  class BackfillUserSlugs
    def self.up
      puts "Backfilling user slugs..."

      count = 0
      User.where("slug IS NULL OR slug = ''").each do |user|
        slug = generate_slug(user.name, user.id)
        user.update(slug: slug)
        count += 1

        print "." if count % 100 == 0
      end

      puts "\nBackfilled #{count} user slugs"
    end

    private def self.generate_slug(name : String, id : Int64) : String
      base_slug = name.downcase.gsub(/[^a-z0-9]+/, "-")
      "#{base_slug}-#{id}"
    end

    def self.run
      up
    end
  end
end

DataMigrations::BackfillUserSlugs.run
```

### 2. Migrate Data Between Tables

When restructuring your schema and moving data:

```crystal
# src/db/data_migrations/20240101120000_data_migrate_posts_to_articles.cr
require "../../src/models/**"

module DataMigrations
  class MigratePostsToArticles
    def self.up
      puts "Migrating posts to articles..."

      migrated = 0
      skipped = 0

      Post.all.each do |post|
        # Check if already migrated
        if Article.exists?(legacy_post_id: post.id)
          skipped += 1
          next
        end

        # Create article from post
        article = Article.create!(
          title: post.title,
          content: post.body,
          author_id: post.user_id,
          published_at: post.created_at,
          status: map_status(post.status),
          legacy_post_id: post.id
        )

        # Migrate comments
        migrate_comments(post, article)

        # Migrate tags
        migrate_tags(post, article)

        migrated += 1
        print "." if migrated % 50 == 0
      end

      puts "\nMigrated: #{migrated}, Skipped: #{skipped}"
    end

    private def self.map_status(old_status : String) : String
      case old_status
      when "published" then "live"
      when "draft" then "draft"
      when "archived" then "archived"
      else "draft"
      end
    end

    private def self.migrate_comments(post : Post, article : Article)
      post.comments.each do |comment|
        Comment.create!(
          article_id: article.id,
          user_id: comment.user_id,
          content: comment.body,
          created_at: comment.created_at
        )
      end
    end

    private def self.migrate_tags(post : Post, article : Article)
      post.tags.each do |tag|
        article.add_tag(tag)
      end
    end

    def self.run
      up
    end
  end
end

DataMigrations::MigratePostsToArticles.run
```

### 3. Import External Data

When importing data from CSV, JSON, or external APIs:

```crystal
# src/db/data_migrations/20240101120000_data_import_legacy_users.cr
require "../../src/models/**"
require "csv"

module DataMigrations
  class ImportLegacyUsers
    def self.up
      puts "Importing legacy users..."

      csv_path = "db/data/legacy_users.csv"
      unless File.exists?(csv_path)
        puts "Error: #{csv_path} not found"
        return
      end

      imported = 0
      failed = 0

      CSV.each_row(File.read(csv_path), headers: true) do |row|
        begin
          user = User.create!(
            email: row["email"].downcase.strip,
            name: row["full_name"],
            password_hash: row["password_hash"],
            created_at: Time.parse(row["created_at"], "%Y-%m-%d %H:%M:%S"),
            legacy_id: row["id"].to_i,
            confirmed_at: Time.utc  # Auto-confirm imported users
          )

          # Import associated data
          import_user_profile(user, row)
          import_user_preferences(user, row)

          imported += 1
          print "." if imported % 100 == 0
        rescue ex
          puts "\nFailed to import user #{row["email"]}: #{ex.message}"
          failed += 1
        end
      end

      puts "\nImported: #{imported}, Failed: #{failed}"
    end

    private def self.import_user_profile(user : User, row : CSV::Row)
      UserProfile.create!(
        user_id: user.id,
        bio: row["bio"]?,
        location: row["location"]?,
        website: row["website"]?
      )
    end

    private def self.import_user_preferences(user : User, row : CSV::Row)
      UserPreferences.create!(
        user_id: user.id,
        email_notifications: row["email_notifications"] == "1",
        theme: row["theme"] || "light"
      )
    end

    def self.run
      up
    end
  end
end

DataMigrations::ImportLegacyUsers.run
```

### 4. Transform and Clean Data

When fixing data inconsistencies or normalizing values:

```crystal
# src/db/data_migrations/20240101120000_data_normalize_email_addresses.cr
require "../../src/models/**"

module DataMigrations
  class NormalizeEmailAddresses
    def self.up
      puts "Normalizing email addresses..."

      normalized = 0
      duplicates = 0

      User.all.each do |user|
        original_email = user.email
        normalized_email = normalize_email(original_email)

        if normalized_email != original_email
          # Check for duplicates
          if User.exists?(email: normalized_email) && user.email != normalized_email
            puts "\nDuplicate email detected: #{normalized_email}"
            handle_duplicate(user)
            duplicates += 1
          else
            user.update(email: normalized_email)
            normalized += 1
          end
        end

        print "." if (normalized + duplicates) % 100 == 0
      end

      puts "\nNormalized: #{normalized}, Duplicates: #{duplicates}"
    end

    private def self.normalize_email(email : String) : String
      email.downcase.strip
    end

    private def self.handle_duplicate(user : User)
      # Append user ID to make email unique
      unique_email = "#{user.email.split("@").first}_#{user.id}@#{user.email.split("@").last}"
      user.update(email: unique_email)
      puts "  Renamed to: #{unique_email}"
    end

    def self.run
      up
    end
  end
end

DataMigrations::NormalizeEmailAddresses.run
```

### 5. Archive Old Data

When moving old records to archive tables:

```crystal
# src/db/data_migrations/20240101120000_data_archive_old_orders.cr
require "../../src/models/**"

module DataMigrations
  class ArchiveOldOrders
    # Archive orders older than 2 years
    ARCHIVE_THRESHOLD = 2.years.ago

    def self.up
      puts "Archiving old orders..."
      puts "Archiving orders before: #{ARCHIVE_THRESHOLD}"

      archived = 0

      Order.where("created_at < ?", ARCHIVE_THRESHOLD).each do |order|
        # Create archive record
        ArchivedOrder.create!(
          original_id: order.id,
          customer_id: order.customer_id,
          total: order.total,
          status: order.status,
          items: order.items.to_json,
          created_at: order.created_at,
          archived_at: Time.utc
        )

        # Delete original order
        order.delete

        archived += 1
        print "." if archived % 100 == 0
      end

      puts "\nArchived #{archived} orders"
    end

    def self.down
      puts "Restoring archived orders..."

      restored = 0

      ArchivedOrder.where("archived_at > ?", ARCHIVE_THRESHOLD).each do |archived|
        # Restore original order
        Order.create!(
          id: archived.original_id,
          customer_id: archived.customer_id,
          total: archived.total,
          status: archived.status,
          created_at: archived.created_at
        )

        # Restore order items from JSON
        restore_order_items(archived)

        # Delete archive record
        archived.delete

        restored += 1
      end

      puts "Restored #{restored} orders"
    end

    private def self.restore_order_items(archived : ArchivedOrder)
      items = JSON.parse(archived.items)
      items.as_a.each do |item|
        OrderItem.create!(
          order_id: archived.original_id,
          product_id: item["product_id"].as_i64,
          quantity: item["quantity"].as_i,
          price: item["price"].as_f
        )
      end
    end

    def self.run
      up
    end
  end
end

DataMigrations::ArchiveOldOrders.run
```

## Running Data Migrations

### Manual Execution

Run a specific data migration:

```bash
crystal run src/db/data_migrations/20240101120000_data_migrate_user_roles.cr
```

### With Database Connection

Ensure database is configured:

```bash
DATABASE_URL="postgresql://user:pass@localhost/db" \
crystal run src/db/data_migrations/20240101120000_data_migrate_user_roles.cr
```

### In Production

```bash
# Set production environment
CRYSTAL_ENV=production \
DATABASE_URL="$PRODUCTION_DATABASE_URL" \
crystal run src/db/data_migrations/20240101120000_data_migrate_user_roles.cr
```

### As Part of Deployment

Add to deployment script:

```bash
#!/bin/bash
# deploy.sh

# Run schema migrations
azu db:migrate

# Run specific data migrations
crystal run src/db/data_migrations/20240101120000_data_backfill_slugs.cr
crystal run src/db/data_migrations/20240102140000_data_normalize_emails.cr

# Restart application
systemctl restart myapp
```

## Best Practices

### 1. Make Migrations Idempotent

Data migrations should be safe to run multiple times:

```crystal
def self.up
  User.where("slug IS NULL").each do |user|
    # Only update if slug is missing
    user.update(slug: generate_slug(user))
  end
end
```

### 2. Use Transactions

Wrap operations in transactions when possible:

```crystal
def self.up
  CQL::DB.transaction do
    # All operations
    # Will rollback if any fails
  end
end
```

### 3. Batch Processing

Process large datasets in batches:

```crystal
def self.up
  BATCH_SIZE = 1000
  offset = 0

  loop do
    batch = User.limit(BATCH_SIZE).offset(offset).to_a
    break if batch.empty?

    batch.each do |user|
      process_user(user)
    end

    offset += BATCH_SIZE
    puts "Processed #{offset} users..."
  end
end
```

### 4. Progress Reporting

Provide feedback for long-running migrations:

```crystal
def self.up
  total = User.count
  processed = 0

  User.all.each do |user|
    process_user(user)
    processed += 1

    if processed % 100 == 0
      percentage = (processed.to_f / total * 100).round(2)
      puts "Progress: #{processed}/#{total} (#{percentage}%)"
    end
  end
end
```

### 5. Error Handling

Handle errors gracefully:

```crystal
def self.up
  failed = [] of Int64

  User.all.each do |user|
    begin
      process_user(user)
    rescue ex
      puts "Failed to process user #{user.id}: #{ex.message}"
      failed << user.id
    end
  end

  if failed.any?
    puts "\nFailed user IDs: #{failed.join(", ")}"
    puts "Total failures: #{failed.size}"
  end
end
```

### 6. Verification

Verify results after migration:

```crystal
def self.up
  # Perform migration
  User.where("slug IS NULL").each do |user|
    user.update(slug: generate_slug(user))
  end

  # Verify
  remaining = User.where("slug IS NULL OR slug = ''").count
  if remaining > 0
    puts "Warning: #{remaining} users still have no slug"
  else
    puts "✓ All users have slugs"
  end
end
```

## Testing Data Migrations

Create tests for data migrations:

```crystal
# spec/data_migrations/backfill_user_slugs_spec.cr
require "../spec_helper"

describe DataMigrations::BackfillUserSlugs do
  describe ".up" do
    it "generates slugs for users without slugs" do
      user1 = create_user(name: "John Doe", slug: nil)
      user2 = create_user(name: "Jane Smith", slug: nil)
      user3 = create_user(name: "Bob Wilson", slug: "existing-slug")

      DataMigrations::BackfillUserSlugs.up

      user1.reload.slug.should_not be_nil
      user2.reload.slug.should_not be_nil
      user3.reload.slug.should eq("existing-slug")
    end

    it "generates unique slugs" do
      user1 = create_user(name: "Test User", slug: nil)
      user2 = create_user(name: "Test User", slug: nil)

      DataMigrations::BackfillUserSlugs.up

      user1.reload.slug.should_not eq(user2.reload.slug)
    end
  end
end
```

## Tracking Data Migrations

### Migration Log

Create a table to track data migrations:

```sql
CREATE TABLE data_migrations (
  id BIGSERIAL PRIMARY KEY,
  version VARCHAR(255) NOT NULL UNIQUE,
  name VARCHAR(255) NOT NULL,
  executed_at TIMESTAMP NOT NULL DEFAULT NOW()
);
```

### Record Execution

```crystal
def self.up
  # Check if already run
  if executed?
    puts "Migration already executed, skipping..."
    return
  end

  # Perform migration
  # ...

  # Record execution
  record_execution
end

private def self.executed? : Bool
  CQL::DB.scalar("SELECT COUNT(*) FROM data_migrations WHERE version = ?", version).as(Int64) > 0
end

private def self.record_execution
  CQL::DB.exec(
    "INSERT INTO data_migrations (version, name) VALUES (?, ?)",
    version,
    name
  )
end

private def self.version : String
  "20240101120000"
end

private def self.name : String
  "BackfillUserSlugs"
end
```

## Troubleshooting

### Migration Fails Midway

**Problem**: Large migration fails after processing many records

**Solutions**:

- Implement checkpoints
- Use batching with offset tracking
- Make migrations resumable

```crystal
def self.up
  last_processed_id = get_last_checkpoint || 0

  User.where("id > ?", last_processed_id).each do |user|
    process_user(user)
    save_checkpoint(user.id)
  end
end
```

### Out of Memory

**Problem**: Processing too many records at once

**Solutions**:

- Use `find_each` or batching
- Process in smaller chunks
- Clear object caches

```crystal
# Bad
users = User.all # Loads all into memory

# Good
User.find_each(batch_size: 100) do |user|
  process_user(user)
end
```

### Slow Performance

**Problem**: Migration takes too long

**Solutions**:

- Add database indexes
- Use bulk operations
- Optimize queries
- Process in parallel (if safe)

```crystal
# Bulk update instead of individual saves
User.where(active: true).update_all(status: "active")
```

## Related Documentation

- [Migration Generator](migration.md)
- [Database Commands](../commands/database.md)
- [CQL ORM Documentation](https://github.com/azutoolkit/cql)

## See Also

- [`azu generate migration`](migration.md) - Schema migrations
- [`azu db:migrate`](../commands/database.md) - Run schema migrations
- [Data Migration Patterns](../guides/data-migrations.md)
