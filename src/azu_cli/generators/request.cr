require "teeplate"

module AzuCLI
  module Generate
    # Request generator that creates request structs
    class Request < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/requests"
      OUTPUT_DIR = "./src/requests"

      property name : String
      property attributes : Hash(String, String)
      property snake_case_name : String
      property validations : Hash(String, Array(String))

      def initialize(@name : String, @attributes : Hash(String, String))
        @snake_case_name = @name.underscore
        @validations = extract_validations(@attributes)
      end

      # Extract validations from attributes
      private def extract_validations(attributes : Hash(String, String)) : Hash(String, Array(String))
        validations = {} of String => Array(String)
        attributes.each do |field, type|
          field_validations = [] of String
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
            field_validations << "format: /^[^@]+@[^@]+\\.[^@]+$/"
          when "url"
            field_validations << "format: /^https?:\\/\\/.+/"
          end
          validations[field] = field_validations unless field_validations.empty?
        end
        validations
      end

      def camel_case_name : String
        @name.camelcase
      end

      # Get constructor parameters
      def constructor_params : String
        params = [] of String
        @attributes.each do |field, type|
          params << "@#{field} : #{crystal_type(type)}"
        end
        params.join(", ")
      end

      # Get getter declarations
      def getter_declarations : String
        getters = [] of String
        @attributes.each do |field, type|
          getters << "getter #{field} : #{crystal_type(type)}"
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

      # Check if request has validations
      def has_validations? : Bool
        !@validations.empty?
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
        when "json"
          "JSON::Any"
        else
          "String"
        end
      end
    end
  end
end
