require "yaml"
require "json"
require "./spec"

module AzuCLI
  module OpenAPI
    # Parser for OpenAPI 3.1 specifications
    class Parser
      getter spec : Spec
      getter file_path : String

      def initialize(@file_path : String)
        @spec = parse_file(@file_path)
      end

      # Parse OpenAPI spec from file (YAML or JSON)
      private def parse_file(path : String) : Spec
        content = File.read(path)
        
        if path.ends_with?(".json")
          Spec.from_json(content)
        elsif path.ends_with?(".yaml") || path.ends_with?(".yml")
          Spec.from_yaml(content)
        else
          # Try to detect format
          begin
            Spec.from_yaml(content)
          rescue
            Spec.from_json(content)
          end
        end
      rescue ex
        raise "Failed to parse OpenAPI spec: #{ex.message}"
      end

      # Get all paths from the spec
      def paths : Hash(String, PathItem)
        @spec.paths || {} of String => PathItem
      end

      # Get all schemas from components
      def schemas : Hash(String, Schema)
        @spec.components.try(&.schemas) || {} of String => Schema
      end

      # Get all operations from all paths
      def operations : Array(OperationInfo)
        ops = [] of OperationInfo
        
        paths.each do |path, path_item|
          {"get", "post", "put", "patch", "delete", "options", "head", "trace"}.each do |method|
            operation = case method
                       when "get" then path_item.get
                       when "post" then path_item.post
                       when "put" then path_item.put
                       when "patch" then path_item.patch
                       when "delete" then path_item.delete
                       when "options" then path_item.options
                       when "head" then path_item.head
                       when "trace" then path_item.trace
                       end
            
            if operation
              ops << OperationInfo.new(
                path: path,
                method: method,
                operation: operation,
                operation_id: operation.operationId || generate_operation_id(method, path)
              )
            end
          end
        end
        
        ops
      end

      # Resolve $ref reference
      def resolve_ref(ref : String) : Schema?
        # $ref format: #/components/schemas/SchemaName
        parts = ref.split("/")
        return nil unless parts.size == 4 && parts[0] == "#" && parts[1] == "components" && parts[2] == "schemas"
        
        schema_name = parts[3]
        schemas[schema_name]?
      end

      # Generate operation ID from method and path
      private def generate_operation_id(method : String, path : String) : String
        # Convert /users/{id} to getUsersById
        parts = path.split("/").reject(&.empty?)
        action = method.downcase
        
        resource = parts.map do |part|
          if part.starts_with?("{") && part.ends_with?("}")
            "By" + part[1..-2].camelcase
          else
            part.camelcase
          end
        end.join
        
        action + resource
      end

      # Helper struct for operation information
      struct OperationInfo
        property path : String
        property method : String
        property operation : Operation
        property operation_id : String

        def initialize(@path, @method, @operation, @operation_id)
        end
      end
    end
  end
end

