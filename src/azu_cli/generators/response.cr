require "teeplate"

module AzuCLI
  module Generate
    # Response generator that creates Azu::Response structs
    class Response < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/responses"
      OUTPUT_DIR = "./src/responses"

      property name : String
      property fields : Hash(String, String)
      property from_type : String?
      property snake_case_name : String

      def initialize(@name : String, @fields : Hash(String, String) = {} of String => String, @from_type : String? = nil)
        @snake_case_name = @name.underscore
      end

      # Convert name to response struct name
      def struct_name : String
        @name.camelcase + "Response"
      end

      # Get getter declarations
      def getter_declarations : String
        @fields.map { |name, type| "getter #{name} : #{crystal_type(type)}" }.join("\n  ")
      end

      # Get constructor parameters for fields
      def constructor_params : String
        @fields.map { |name, type| "@#{name} : #{crystal_type(type)}" }.join(", ")
      end

      # Get assignments from source type (e.g., User)
      def assignments_from_source : String
        return "" unless @from_type
        @fields.map { |name, _| "@#{name} = #{from_var}.#{name}" }.join("\n    ")
      end

      # Get the variable name for the source type
      def from_var : String
        @from_type.try(&.underscore) || "source"
      end

      # Get Crystal type for field
      def crystal_type(field_type : String) : String
        case field_type.downcase
        when "string"
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
        when "string?"
          "String?"
        when "int32?"
          "Int32?"
        when "int64?"
          "Int64?"
        when "float64?"
          "Float64?"
        when "bool?"
          "Bool?"
        else
          "String"
        end
      end

      # Get to_json call for render
      def render_method : String
        "def render\n    to_json\n  end"
      end
    end
  end
end
