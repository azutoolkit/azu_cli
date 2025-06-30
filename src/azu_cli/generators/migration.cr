require "./base"

module AzuCLI::Generator
  # Migration generator for creating CQL database migration files
  class Migration < Base
    getter attributes : Array(String)

    def initialize(name : String, project_name : String, @attributes = [] of String, force = false, skip_tests = false)
      super(name, project_name, force, skip_tests)
    end

    def generate!
      validate_name!

      # Create migrations directory if it doesn't exist
      migrations_dir = File.join(".", "src", "db", "migrations")
      ensure_directory(migrations_dir)

      # Generate timestamp-based filename
      timestamp = Time.utc.to_s("%Y%m%d%H%M%S")
      filename = "#{timestamp}_#{snake_case_name}.cr"
      file_path = File.join(migrations_dir, filename)

      # Generate migration content
      migration_content = render_migration_template(timestamp.to_i64)

      # Write migration file
      if write_file(file_path, migration_content, "migration")
        puts "    📝 Edit the migration to define your schema changes".colorize(:blue)
        puts "    🔄 Run 'azu db:migrate' to apply this migration".colorize(:blue)
      end
    end

    private def render_migration_template(version : Int64) : String
      # Detect migration type from name to provide appropriate examples
      migration_type = detect_migration_type(name)

      <<-CRYSTAL
      require "cql"

      # #{class_name} Migration
      # Generated at: #{Time.utc}
      class #{class_name} < CQL::Migration(#{version})
        def up
          #{render_up_examples(migration_type)}
        end

        def down
          #{render_down_examples(migration_type)}
        end
      end
      CRYSTAL
    end

    private def detect_migration_type(name : String) : String
      lower_name = name.downcase

      case
      when lower_name.includes?("create") && lower_name.includes?("table")
        "create_table"
      when lower_name.includes?("add") && lower_name.includes?("_to_")
        "add_column"
      when lower_name.includes?("remove") && lower_name.includes?("_from_")
        "remove_column"
      when lower_name.includes?("add") && (lower_name.includes?("column") || lower_name.includes?("field"))
        "add_column"
      when lower_name.includes?("remove") && (lower_name.includes?("column") || lower_name.includes?("field"))
        "remove_column"
      when lower_name.includes?("drop") && lower_name.includes?("table")
        "drop_table"
      when lower_name.includes?("index")
        "index"
      when lower_name.includes?("foreign_key") || lower_name.includes?("reference")
        "foreign_key"
      when lower_name.includes?("rename")
        "rename_column"
      else
        "general"
      end
    end

    private def render_up_examples(migration_type : String) : String
      case migration_type
      when "create_table"
        table_name = extract_table_name || "your_table"
        <<-CRYSTAL
        # Create a new table
          schema.table :#{table_name} do
            primary :id, Int32
            column :name, String
            column :email, String
            column :active, Bool, default: true
            timestamps
          end
          schema.#{table_name}.create!
        CRYSTAL
      when "add_column"
        table_name = extract_table_name || "your_table"
        column_info = extract_column_info
        <<-CRYSTAL
        # Add a new column
          schema.alter :#{table_name} do
            add_column :#{column_info["name"]}, #{column_info["type"]}, #{column_info["options"]}
          end
        CRYSTAL
      when "remove_column"
        table_name = extract_table_name || "your_table"
        column_name = extract_column_name || "your_column"
        <<-CRYSTAL
        # Remove a column
          schema.alter :#{table_name} do
            drop_column :#{column_name}
          end
        CRYSTAL
      when "drop_table"
        table_name = extract_table_name || "your_table"
        <<-CRYSTAL
        # Drop a table
          schema.#{table_name}.drop!
        CRYSTAL
      when "rename_column"
        table_name = extract_table_name || "your_table"
        <<-CRYSTAL
        # Rename a column
          schema.alter :#{table_name} do
            rename_column :old_name, :new_name
          end
        CRYSTAL
      when "index"
        <<-CRYSTAL
        # Add an index
          schema.add_index :your_table, :column_name, unique: false
          # schema.add_index :users, [:email], unique: true
        CRYSTAL
      when "foreign_key"
        <<-CRYSTAL
        # Add a foreign key
          schema.add_foreign_key :child_table, [:parent_id], :parent_table, [:id]
          # Example: schema.add_foreign_key :posts, [:user_id], :users, [:id]
        CRYSTAL
      else
        <<-CRYSTAL
        # Define your schema changes here
          # Examples:
          #
          # Create table:
          # schema.table :users do
          #   primary :id, Int32
          #   column :name, String
          #   column :email, String, null: false
          #   column :age, Int32, null: true
          #   column :active, Bool, default: true
          #   timestamps
          # end
          # schema.users.create!
          #
          # Add column:
          # schema.alter :users do
          #   add_column :phone, String, null: true
          # end
          #
          # Add index:
          # schema.add_index :users, :email, unique: true
          #
          # Add foreign key:
          # schema.add_foreign_key :posts, [:user_id], :users, [:id]
        CRYSTAL
      end
    end

    private def render_down_examples(migration_type : String) : String
      case migration_type
      when "create_table"
        table_name = extract_table_name || "your_table"
        <<-CRYSTAL
        # Drop the table
          schema.#{table_name}.drop!
        CRYSTAL
      when "add_column"
        table_name = extract_table_name || "your_table"
        column_name = extract_column_name || "your_column"
        <<-CRYSTAL
        # Remove the added column
          schema.alter :#{table_name} do
            drop_column :#{column_name}
          end
        CRYSTAL
      when "remove_column"
        table_name = extract_table_name || "your_table"
        column_info = extract_column_info
        <<-CRYSTAL
        # Re-add the removed column
          schema.alter :#{table_name} do
            add_column :#{column_info["name"]}, #{column_info["type"]}, #{column_info["options"]}
          end
        CRYSTAL
      when "drop_table"
        table_name = extract_table_name || "your_table"
        <<-CRYSTAL
        # Recreate the table (you'll need to define the structure)
          schema.table :#{table_name} do
            primary :id, Int32
            # Add your columns here
            timestamps
          end
          schema.#{table_name}.create!
        CRYSTAL
      when "rename_column"
        table_name = extract_table_name || "your_table"
        <<-CRYSTAL
        # Rename back to original name
          schema.alter :#{table_name} do
            rename_column :new_name, :old_name
          end
        CRYSTAL
      when "index"
        <<-CRYSTAL
        # Remove the index
          schema.drop_index :your_table, :column_name
        CRYSTAL
      when "foreign_key"
        <<-CRYSTAL
        # Remove the foreign key
          schema.drop_foreign_key :child_table, [:parent_id]
        CRYSTAL
      else
        <<-CRYSTAL
        # Define how to rollback the changes
          # Examples:
          #
          # Drop table:
          # schema.your_table.drop!
          #
          # Remove column:
          # schema.alter :users do
          #   drop_column :phone
          # end
          #
          # Remove index:
          # schema.drop_index :users, :email
          #
          # Remove foreign key:
          # schema.drop_foreign_key :posts, [:user_id]
        CRYSTAL
      end
    end

    private def extract_table_name : String?
      # Try to extract table name from migration name
      # Examples: "create_users_table" -> "users", "add_email_to_users" -> "users"
      lower_name = name.downcase

      # Pattern: create_*_table
      if match = lower_name.match(/create_(.+)_table/)
        return match[1]
      end

      # Pattern: add_*_to_* or remove_*_from_*
      if match = lower_name.match(/(?:add|remove)_.+_(?:to|from)_(.+)/)
        return match[1]
      end

      # Pattern: drop_*_table
      if match = lower_name.match(/drop_(.+)_table/)
        return match[1]
      end

      # Try to find table name from attributes if provided
      if attributes.any? && attributes.first.includes?(":")
        # If first attribute looks like "table:users", extract the table name
        if match = attributes.first.match(/table:(.+)/)
          return match[1]
        end
      end

      nil
    end

    private def extract_column_name : String?
      # Try to extract column name from migration name
      lower_name = name.downcase

      # Pattern: add_*_to_* -> extract the column name
      if match = lower_name.match(/add_(.+)_to_.+/)
        return match[1]
      end

      # Pattern: remove_*_from_* -> extract the column name
      if match = lower_name.match(/remove_(.+)_from_.+/)
        return match[1]
      end

      # Check attributes for column definition
      attributes.each do |attr|
        if attr.includes?(":")
          parts = attr.split(":")
          return parts[0] if parts.size >= 2
        end
      end

      nil
    end

    private def extract_column_info : Hash(String, String)
      column_name = extract_column_name || "new_column"

      # Try to extract type from attributes
      column_type = "String"
      column_options = "null: true"

      attributes.each do |attr|
        if attr.includes?(":")
          parts = attr.split(":")
          if parts.size >= 2
            column_name = parts[0]
            raw_type = parts[1]

            # Map common type aliases to CQL types based on CQL documentation
            column_type = case raw_type.downcase
                          when "string", "text"
                            "String"
                          when "integer", "int"
                            "Int32"
                          when "bigint", "big_integer", "long"
                            "Int64"
                          when "float", "decimal", "number"
                            "Float64"
                          when "boolean", "bool"
                            "Bool"
                          when "datetime", "timestamp"
                            "Time"
                          when "date"
                            "Time"
                          when "json"
                            "JSON::Any"
                          when "uuid"
                            "UUID"
                          when "binary", "blob"
                            "Bytes"
                          when "real"
                            "Float32"
                          when "smallint", "short"
                            "Int16"
                          when "tinyint", "byte"
                            "Int8"
                          else
                            "String"
                          end

            # Set appropriate options based on type
            column_options = case raw_type.downcase
                             when "string", "text"
                               "null: true"
                             when "boolean", "bool"
                               "default: false"
                             when "integer", "int", "bigint", "float", "decimal"
                               "null: true"
                             else
                               "null: true"
                             end
          end
        end
      end

      {
        "name"    => column_name,
        "type"    => column_type,
        "options" => column_options,
      }
    end
  end
end
