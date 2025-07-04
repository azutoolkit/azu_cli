require "teeplate"

module AzuCLI
  module Generate
    # Model generator that creates CQL::ActiveRecord::Model structs
    class Model < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/models"

      # Model configuration properties
      property name : String
      property attributes : Hash(String, String)
      property timestamps : Bool
      property database : String
      property id_type : String
      property validations : Hash(String, Array(String))
      property snake_case_name : String

      def initialize(@name : String, @attributes : Hash(String, String), @timestamps : Bool = true,
                     @database : String = "BlogDB", @id_type : String = "UUID")
        @snake_case_name = @name.underscore
        @validations = extract_validations(@attributes)
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
            field_validations << "size: 2..100"
          when "int32", "int64", "integer"
            field_validations << "gt: 0"
          when "float32", "float64", "float"
            field_validations << "gt: 0.0"
            field_validations << "lt: 1_000_000.0"
          when "email"
            field_validations << "presence: true"
            field_validations << "format: /^[^@]+@[^@]+.[^@]+$/"
          when "url"
            field_validations << "format: /^https?://.+/"
          end

          validations[field] = field_validations unless field_validations.empty?
        end

        validations
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
        else
          "String" # Default to String for unknown types
        end
      end

      # Check if type is nullable
      def nullable_type?(attr_type : String) : Bool
        case attr_type.downcase
        when "time", "datetime", "date", "uuid"
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
          crystal_type = crystal_type(type)
          params << "@#{field} : #{crystal_type}"
        end

        params.join(", ")
      end

      # Get getter declarations
      def getter_declarations : String
        getters = [] of String

        # Add ID getter
        getters << "getter id : #{crystal_type(@id_type)}?"

        # Add attribute getters
        @attributes.each do |field, type|
          crystal_type = crystal_type(type)
          if nullable_type?(type)
            getters << "getter #{field} : #{nullable_type(type)}"
          else
            getters << "getter #{field} : #{crystal_type}"
          end
        end

        # Add timestamp getters if enabled
        if @timestamps
          getters << "getter created_at : Time?"
          getters << "getter updated_at : Time?"
        end

        getters.join("\n  ")
      end

      # Get validation declarations
      def validation_declarations : String
        validations = [] of String

        @validations.each do |field, field_validations|
          validation_str = field_validations.join(", ")
          validations << "validate :#{field}, #{validation_str}"
        end

        validations.join("\n  ")
      end

      # Check if model has validations
      def has_validations? : Bool
        !@validations.empty?
      end

      # Get database context declaration
      def db_context_declaration : String
        "db_context #{@database}, :#{table_name}"
      end

      # Get include statement
      def include_statement : String
        "include CQL::ActiveRecord::Model(#{crystal_type(@id_type)})"
      end
    end
  end
end
