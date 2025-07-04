require "teeplate"

module AzuCLI
  module Generate
    # Migration generator that creates CQL::Migration classes
    class Migration < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/migrations"

      # Migration configuration properties
      property name : String
      property attributes : Hash(String, String)
      property timestamps : Bool
      property snake_case_name : String
      property timestamp : String

      def initialize(@name : String, @attributes : Hash(String, String), @timestamps : Bool = true)
        @snake_case_name = @name.underscore
        @timestamp = generate_timestamp
      end

      # Convert name to snake_case for file naming
      def snake_case_name : String
        @name.underscore
      end

      # Convert name to plural form for table naming
      def table_name : String
        snake_case_name.pluralize
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
        "#{@timestamp}_create_#{table_name}.cr"
      end

      # Get migration class name
      def migration_class_name : String
        "Create#{@name.pluralize}"
      end
    end
  end
end
