require "./parser"
require "./model_generator"
require "./endpoint_generator"
require "./request_generator"
require "./response_generator"
require "../logger"

module AzuCLI
  module OpenAPI
    # Main code generator that orchestrates generation from OpenAPI spec
    class CodeGenerator
      getter parser : Parser
      getter force : Bool

      def initialize(spec_path : String, @force : Bool = false)
        @parser = Parser.new(spec_path)
      end

      # Generate all code from OpenAPI spec
      def generate_all
        Logger.info("Generating code from OpenAPI specification...")

        # Generate models from schemas
        generate_models

        # Generate endpoints from paths
        generate_endpoints

        Logger.success("✓ Code generation completed successfully")
      end

      # Generate models from component schemas
      def generate_models
        schemas = @parser.schemas

        return if schemas.empty?

        Logger.info("Generating #{schemas.size} model(s)...")

        schemas.each do |name, schema|
          generator = ModelGenerator.new(name, schema, @parser)
          generator.generate(@force)
        end
      end

      # Generate endpoints from paths
      def generate_endpoints
        operations = @parser.operations

        return if operations.empty?

        Logger.info("Generating #{operations.size} endpoint(s)...")

        # Group operations by resource
        operations_by_resource = operations.group_by do |op|
          extract_resource_name(op.path)
        end

        operations_by_resource.each do |resource, resource_operations|
          generator = EndpointGenerator.new(resource, resource_operations, @parser)
          generator.generate(@force)
        end
      end

      # Extract resource name from path
      private def extract_resource_name(path : String) : String
        # Extract first path segment as resource name
        # /users/{id} -> users
        # /api/v1/posts -> posts
        parts = path.split("/").reject(&.empty?)

        # Skip common prefixes like "api", "v1", "v2", etc.
        resource = parts.find { |p| !p.match(/^(api|v\d+)$/) && !p.starts_with?("{") }

        resource || "default"
      end
    end
  end
end
