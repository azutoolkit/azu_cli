require "teeplate"

module AzuCLI
  module Generate
    # Migration generator that creates CQL::Migration classes
    class Migration < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/migrations"
      OUTPUT_DIR = "./db/migrations"
      # Migration configuration properties
      property name : String
      property attributes : Hash(String, String)
      property timestamps : Bool
      property snake_case_name : String
      property timestamp : String
      property table_name : String
      property action_prefix : String
      property table_name_for_template : String

      def initialize(@name : String, @attributes : Hash(String, String), @timestamps : Bool = true)
        @snake_case_name = to_snake_case(@name)
        @timestamp = generate_timestamp
        @table_name = extract_table_name(@snake_case_name)
        @action_prefix = get_action_prefix
        @table_name_for_template = get_table_name_for_filename
      end

      # Extract clean table name from migration name
      private def extract_table_name(name : String) : String
        # Remove common prefixes to get the actual table name
        clean_name = name
          .gsub(/^create_/, "")
          .gsub(/^update_/, "")
          .gsub(/^delete_/, "")
          .gsub(/^drop_/, "")
          .gsub(/^add_.*_to_/, "")
          .gsub(/^remove_.*_from_/, "")
          .gsub(/^change_.*_in_/, "")

        # Ensure it's properly pluralized
        clean_name.singularize.pluralize
      end

      # Detect migration type based on name pattern
      def migration_type : String
        case @name.downcase
        when /^add_index_to_/
          "add_index"
        when /^remove_index_from_/
          "remove_index"
        when /^add_.*_to_/
          "add_columns"
        when /^remove_.*_from_/
          "remove_columns"
        when /^change_.*_in_/
          "change_columns"
        when /^create_/
          "create_table"
        when /^update_/
          "update_table"
        when /^delete_/
          "delete_table"
        when /^drop_/
          "drop_table"
        else
          "create_table" # Default fallback
        end
      end

      # Extract table name from migration name for add/remove operations
      def target_table_name : String
        case migration_type
        when "add_columns", "remove_columns", "change_columns"
          # Extract table name from "AddXToY" or "add_x_to_y"
          parts = @name.downcase.split(/_/)
          if parts.size >= 3 && parts[-2] == "to"
            parts.last
          else
            @table_name
          end
        when "add_index", "remove_index"
          # Extract table name from "AddIndexToX" or "add_index_to_x"
          parts = @name.downcase.split(/_/)
          if parts.size >= 4 && parts[-2] == "to"
            parts.last
          else
            @table_name
          end
        else
          @table_name
        end
      end

      # Extract column names from migration name
      def column_names : Array(String)
        case migration_type
        when "add_columns", "remove_columns", "change_columns"
          # Extract column names from "AddXToY" or "add_x_to_y"
          parts = @name.downcase.split(/_/)
          if parts.size >= 3 && parts[-2] == "to"
            # For "add_name_and_email_to_users", extract ["name", "email"]
            parts[1..-3].reject { |p| p == "and" }
          else
            @attributes.keys
          end
        else
          @attributes.keys
        end
      end

      # Convert name to snake_case for file naming
      def snake_case_name : String
        # Convert to snake_case first, then singularize to avoid singularize lowercasing issues
        to_snake_case(@name).singularize
      end

      # Convert a string to snake_case
      private def to_snake_case(str : String) : String
        str.gsub(/([A-Z\d]+)([A-Z][a-z])/) { "#{$1}_#{$2}" }
          .gsub(/([a-z\d])([A-Z])/) { "#{$1}_#{$2}" }
          .tr("-", "_")
          .downcase
      end

      # Generate timestamp for migration filename
      private def generate_timestamp : String
        Time.utc.to_s("%Y%m%d%H%M%S")
      end

      # Get Crystal type for attribute
      def crystal_type(attr_type : String) : String
        case attr_type.downcase
        when "string", "text"
          "String"
        when "int32", "integer"
          "Int32"
        when "int64"
          "Int64"
        when "float32"
          "Float32"
        when "float64", "float"
          "Float64"
        when "bool", "boolean"
          "Bool"
        when "time", "datetime"
          "Time"
        when "date"
          "Date"
        when "email"
          "String"
        when "url"
          "String"
        when "json"
          "JSON::Any"
        when "uuid"
          "UUID"
        when "references", "belongs_to"
          "Int64"
        else
          "String"
        end
      end

      # Get migration field type for CQL migrations
      def migration_field_type(attr_type : String) : String
        case attr_type.downcase
        when "string", "text"
          "string"
        when "int32", "integer"
          "integer"
        when "int64"
          "bigint"
        when "float32"
          "float"
        when "float64", "float"
          "decimal"
        when "bool", "boolean"
          "boolean"
        when "time", "datetime"
          "timestamp"
        when "date"
          "date"
        when "email"
          "string"
        when "url"
          "string"
        when "json"
          "json"
        when "uuid"
          "uuid"
        else
          "string"
        end
      end

      # Get migration field options
      def migration_field_options(attr_type : String, field : String) : String
        options = [] of String

        case attr_type.downcase
        when "string", "text"
          options << "null: false" unless field.includes?("description") || field.includes?("notes")
        when "int32", "int64", "integer"
          options << "null: false" unless field.includes?("count") || field.includes?("age")
        when "email"
          options << "null: false"
          options << "unique: true"
        when "bool", "boolean"
          options << "default: false"
        when "time", "datetime"
          options << "default: -> { \"CURRENT_TIMESTAMP\" }"
        end

        options.empty? ? "" : ", #{options.join(", ")}"
      end

      # Check if field should have an index
      def should_add_index?(attr_type : String, field : String) : Bool
        case attr_type.downcase
        when "email"
          true
        when "string", "text"
          field.includes?("name") || field.includes?("title") || field.includes?("slug")
        when "int32", "int64", "integer"
          field.includes?("user_id") || field.includes?("category_id")
        when "bool", "boolean"
          field.includes?("published") || field.includes?("active")
        else
          false
        end
      end

      # Get index options
      def index_options(attr_type : String, field : String) : String
        case attr_type.downcase
        when "email"
          ", unique: true"
        when "string", "text"
          if field.includes?("slug")
            ", unique: true"
          else
            ""
          end
        else
          ""
        end
      end

      # Get migration filename
      def migration_filename : String
        action_prefix = get_action_prefix
        table_name = get_table_name_for_filename
        "#{@timestamp}_#{action_prefix}_#{table_name}.cr"
      end

      # Get action prefix for filename based on migration type
      private def get_action_prefix : String
        case migration_type
        when "create_table"
          "create"
        when "update_table"
          "update"
        when "delete_table", "drop_table"
          "delete"
        when "add_columns"
          "add"
        when "remove_columns"
          "remove"
        when "change_columns"
          "change"
        when "add_index"
          "add_index"
        when "remove_index"
          "remove_index"
        else
          "create"
        end
      end

      # Get table name for filename
      private def get_table_name_for_filename : String
        case migration_type
        when "add_columns", "remove_columns", "change_columns", "add_index", "remove_index"
          target_table_name
        else
          @table_name
        end
      end

      # Get migration class name
      def migration_class_name : String
        action_prefix = get_action_prefix.camelcase
        table_name = get_table_name_for_filename.camelcase
        "#{action_prefix}#{table_name}"
      end
    end
  end
end
