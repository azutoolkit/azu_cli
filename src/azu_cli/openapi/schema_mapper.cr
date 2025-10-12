require "./spec"

module AzuCLI
  module OpenAPI
    # Maps OpenAPI types to Crystal types and vice versa
    class SchemaMapper
      # Map OpenAPI type to Crystal type
      def self.to_crystal_type(schema : Schema) : String
        # Handle $ref
        if ref = schema.ref
          return extract_ref_name(ref)
        end

        type = schema.type
        format = schema.format
        nullable = schema.nullable || false

        crystal_type = case type
                       when "string"
                         map_string_type(format)
                       when "integer"
                         map_integer_type(format)
                       when "number"
                         map_number_type(format)
                       when "boolean"
                         "Bool"
                       when "array"
                         map_array_type(schema)
                       when "object"
                         map_object_type(schema)
                       else
                         "String" # Default to String for unknown types
                       end

        nullable ? "#{crystal_type}?" : crystal_type
      end

      # Map string types with format
      private def self.map_string_type(format : String?) : String
        case format
        when "date-time"
          "Time"
        when "date"
          "Time"
        when "uuid"
          "UUID"
        when "email"
          "String"
        when "uri", "url"
          "String"
        when "binary"
          "Bytes"
        else
          "String"
        end
      end

      # Map integer types with format
      private def self.map_integer_type(format : String?) : String
        case format
        when "int64"
          "Int64"
        when "int32"
          "Int32"
        else
          "Int32" # Default to Int32
        end
      end

      # Map number types with format
      private def self.map_number_type(format : String?) : String
        case format
        when "float"
          "Float32"
        when "double"
          "Float64"
        else
          "Float64" # Default to Float64
        end
      end

      # Map array types
      private def self.map_array_type(schema : Schema) : String
        if items = schema.items
          item_type = to_crystal_type(items)
          "Array(#{item_type})"
        else
          "Array(JSON::Any)" # Generic array
        end
      end

      # Map object types
      private def self.map_object_type(schema : Schema) : String
        # For objects without properties, use generic Hash
        if schema.properties.nil? || schema.properties.try(&.empty?)
          "Hash(String, JSON::Any)"
        else
          # Object with properties should be a custom class
          "Hash(String, JSON::Any)" # Generic for now
        end
      end

      # Extract name from $ref
      private def self.extract_ref_name(ref : String) : String
        # $ref format: #/components/schemas/SchemaName
        parts = ref.split("/")
        parts.last
      end

      # Map Crystal type to OpenAPI type
      def self.to_openapi_type(crystal_type : String) : {String, String?}
        # Remove ? for nullable types
        type = crystal_type.rstrip('?')

        case type
        when "String"
          {"string", nil}
        when "Int32"
          {"integer", "int32"}
        when "Int64"
          {"integer", "int64"}
        when "Float32"
          {"number", "float"}
        when "Float64"
          {"number", "double"}
        when "Bool"
          {"boolean", nil}
        when "Time"
          {"string", "date-time"}
        when "UUID"
          {"string", "uuid"}
        when "Bytes"
          {"string", "binary"}
        when /^Array\((.+)\)$/
          {"array", nil}
        when /^Hash\(/
          {"object", nil}
        else
          # Custom type - treat as object reference
          {"object", nil}
        end
      end

      # Get array item type from Crystal array type
      def self.extract_array_item_type(crystal_type : String) : String?
        if match = crystal_type.match(/^Array\((.+)\)$/)
          match[1]
        end
      end

      # Check if type is nullable
      def self.nullable?(crystal_type : String) : Bool
        crystal_type.ends_with?('?')
      end

      # Get CQL column type from Crystal type
      def self.to_cql_type(crystal_type : String) : String
        # Remove ? for nullable types
        type = crystal_type.rstrip('?')

        case type
        when "String"
          "String"
        when "Int32"
          "Int32"
        when "Int64"
          "Int64"
        when "Float32"
          "Float32"
        when "Float64"
          "Float64"
        when "Bool"
          "Bool"
        when "Time"
          "Time"
        when "UUID"
          "UUID"
        else
          "String" # Default to String
        end
      end
    end
  end
end
