require "teeplate"

module AzuCLI
  module Generate
    # Model generator that creates CQL::Model classes
    class Model < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/models"
      OUTPUT_DIR = "./src/models"

      # Model configuration properties
      property name : String
      property attributes : Hash(String, String)
      property timestamps : Bool
      property database : String
      property id_type : String
      property validations : Hash(String, Array(String))
      property snake_case_name : String
      property associations : Hash(String, String)
      property scopes : Array(String)
      property generate_migration : Bool = true

      def initialize(@name : String, @attributes : Hash(String, String), @timestamps : Bool = true,
                     @database : String = "BlogDB", @id_type : String = "UUID", @generate_migration : Bool = true)
        @snake_case_name = @name.underscore
        @validations = extract_validations(@attributes)
        @associations = extract_associations(@attributes)
        @scopes = generate_scopes(@attributes)
      end

      # Convert name to snake_case for file naming
      def snake_case_name : String
        @name.underscore
      end

      # Convert name to plural form for table naming
      def table_name : String
        snake_case_name.pluralize
      end

      # Get the module name from the database context
      def module_name : String
        @database
      end

      # Extract validations from attributes
      private def extract_validations(attributes : Hash(String, String)) : Hash(String, Array(String))
        validations = {} of String => Array(String)

        attributes.each do |field, type|
          field_validations = [] of String

          # Add presence validation for required fields
          case type.downcase
          when "string", "text"
            field_validations << "presence: true"
            field_validations << "length: {min: 2, max: 100}"
          when "int32", "int64", "integer"
            field_validations << "numericality: {greater_than: 0}"
          when "float32", "float64", "float"
            field_validations << "numericality: {greater_than: 0.0}"
          when "email"
            field_validations << "presence: true"
            field_validations << "format: /\\A[^@\\s]+@[^@\\s]+\\z/"
          when "url"
            field_validations << "format: /^https?:\\/\\/.+/"
          end

          validations[field] = field_validations unless field_validations.empty?
        end

        validations
      end

      # Extract associations from attributes
      private def extract_associations(attributes : Hash(String, String)) : Hash(String, String)
        associations = {} of String => String

        attributes.each do |field, type|
          case type.downcase
          when "references", "belongs_to"
            model_name = field.gsub(/_id$/, "").camelcase
            associations[field] = "belongs_to :#{field.gsub(/_id$/, "")}, #{model_name}"
          when "has_many"
            model_name = field.singularize.camelcase
            associations[field] = "has_many :#{field}, #{model_name}"
          when "has_one"
            model_name = field.camelcase
            associations[field] = "has_one :#{field}, #{model_name}"
          end
        end

        associations
      end

      # Generate common scopes based on attributes
      private def generate_scopes(attributes : Hash(String, String)) : Array(String)
        scopes = [] of String

        # Add common scopes based on field types
        attributes.each do |field, type|
          case type.downcase
          when "bool", "boolean"
            scopes << "scope :#{field}, -> { where(#{field}: true) }"
          when "time", "datetime"
            scopes << "scope :recent, -> { order(#{field}: :desc) }"
          when "string", "text"
            if field.includes?("name") || field.includes?("title")
              scopes << "scope :by_#{field}, ->(value : String) { where(\"#{field} ILIKE ?\", \"%\" + value + \"%\") }"
            end
          end
        end

        scopes
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
          "String" # Default to String for unknown types
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

      # Check if type is nullable
      def nullable_type?(attr_type : String) : Bool
        case attr_type.downcase
        when "time", "datetime", "date", "uuid", "references", "belongs_to"
          true
        else
          false
        end
      end

      # Get nullable type representation
      def nullable_type(attr_type : String) : String
        crystal_type = crystal_type(attr_type)
        "#{crystal_type}?"
      end

      # Get constructor parameters
      def constructor_params : String
        params = [] of String

        @attributes.each do |field, type|
          next if type.downcase == "references" || type.downcase == "belongs_to"
          crystal_type = crystal_type(type)
          params << "@#{field} : #{crystal_type}"
        end

        params.join(", ")
      end

      # Get getter declarations (CQL style)
      def getter_declarations : String
        getters = [] of String

        # Add ID getter
        getters << "getter id : #{crystal_type(@id_type)}"

        # Add attribute getters
        @attributes.each do |field, type|
          next if type.downcase == "references" || type.downcase == "belongs_to"
          crystal_type = crystal_type(type)
          if nullable_type?(type)
            getters << "getter #{field} : #{nullable_type(type)}"
          else
            getters << "getter #{field} : #{crystal_type}"
          end
        end

        # Add timestamp getters if enabled
        if @timestamps
          getters << "getter created_at : Time"
          getters << "getter updated_at : Time"
        end

        getters.join("\n  ")
      end

      # Get ID default value based on type
      private def id_default_value : String
        case @id_type.downcase
        when "uuid"
          "UUID.random"
        when "int32", "int64"
          "0"
        else
          "UUID.random"
        end
      end

      # Get validation declarations (CQL style)
      def validation_declarations : String
        validations = [] of String

        @validations.each do |field, field_validations|
          field_validations.each do |validation|
            validations << "validates :#{field}, #{validation}"
          end
        end

        validations.join("\n  ")
      end

      # Check if model has validations
      def has_validations? : Bool
        !@validations.empty?
      end

      # Check if model has scopes
      def has_scopes? : Bool
        !@scopes.empty?
      end

      # Check if model has associations
      def has_associations? : Bool
        !@associations.empty?
      end

      # Get scope declarations
      def scope_declarations : String
        @scopes.join("\n  ")
      end

      # Get association declarations
      def association_declarations : String
        @associations.values.join("\n  ")
      end

      # Get database context declaration
      def db_context_declaration : String
        "db_context #{@database}, :#{table_name}"
      end

      # Get include statement (CQL style)
      def include_statement : String
        "include CQL::Model(#{crystal_type(@id_type)})"
      end

      # In the render method or after model file generation, if generate_migration is true, generate migration
      # (Assume migration generator is available as AzuCLI::Generate::Migration)
      def render(output_path : String)
        super(output_path)
        if @generate_migration
          migration = AzuCLI::Generate::Migration.new(@name, @attributes, @timestamps)
          migration.render(output_path)
        end
      end
    end
  end
end
