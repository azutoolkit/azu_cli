require "./spec"

module AzuCLI
  module OpenAPI
    # Maps Crystal types to OpenAPI types (reverse of SchemaMapper)
    class TypeMapper
      # Create OpenAPI schema from Crystal type
      def self.to_schema(crystal_type : String, description : String? = nil) : Schema
        schema = Schema.new
        schema.description = description

        # Remove ? for nullable types
        is_nullable = crystal_type.ends_with?('?')
        type = crystal_type.rstrip('?')

        schema.nullable = is_nullable if is_nullable

        case type
        when "String"
          schema.type = "string"
        when "Int32"
          schema.type = "integer"
          schema.format = "int32"
        when "Int64"
          schema.type = "integer"
          schema.format = "int64"
        when "Float32"
          schema.type = "number"
          schema.format = "float"
        when "Float64"
          schema.type = "number"
          schema.format = "double"
        when "Bool"
          schema.type = "boolean"
        when "Time"
          schema.type = "string"
          schema.format = "date-time"
        when "UUID"
          schema.type = "string"
          schema.format = "uuid"
        when "Bytes"
          schema.type = "string"
          schema.format = "binary"
        when /^Array\((.+)\)$/
          schema.type = "array"
          item_type = $1
          schema.items = to_schema(item_type)
        when /^Hash\(String,\s*(.+)\)$/
          schema.type = "object"
          schema.additionalProperties = true
        else
          # Custom type - create reference
          schema.ref = "#/components/schemas/#{type}"
        end

        schema
      end

      # Create schema properties from a hash of field definitions
      def self.properties_to_schemas(properties : Hash(String, String)) : Hash(String, Schema)
        result = {} of String => Schema

        properties.each do |name, type|
          result[name] = to_schema(type)
        end

        result
      end

      # Extract required fields (non-nullable types)
      def self.extract_required_fields(properties : Hash(String, String)) : Array(String)
        properties.select { |_, type| !type.ends_with?('?') }.keys
      end
    end
  end
end
