require "./parser"
require "./schema_mapper"
require "./request_generator"
require "./response_generator"
require "../logger"

module AzuCLI
  module OpenAPI
    # Generate endpoints from OpenAPI paths
    class EndpointGenerator
      getter resource : String
      getter operations : Array(Parser::OperationInfo)
      getter parser : Parser

      def initialize(@resource : String, @operations : Array(Parser::OperationInfo), @parser : Parser)
      end

      # Generate endpoint files
      def generate(force : Bool = false)
        output_dir = "./src/endpoints/#{@resource}"
        Dir.mkdir_p(output_dir) unless Dir.exists?(output_dir)

        @operations.each do |op_info|
          generate_endpoint_file(op_info, output_dir, force)
        end
      end

      # Generate a single endpoint file
      private def generate_endpoint_file(op_info : Parser::OperationInfo, output_dir : String, force : Bool)
        action = extract_action_from_operation(op_info)

        # Generate request and response classes first
        generate_request_and_response(op_info, action, force)

        file_name = "#{@resource}_#{action}_endpoint.cr"
        output_path = File.join(output_dir, file_name)

        # Check if file exists
        if File.exists?(output_path) && !force
          Logger.warn("Endpoint file already exists: #{output_path} (use --force to overwrite)")
          return
        end

        # Generate endpoint content
        content = generate_endpoint_content(op_info, action)

        # Write file
        File.write(output_path, content)
        Logger.success("✓ Generated endpoint: #{output_path}")
      end

      # Extract action name from operation
      private def extract_action_from_operation(op_info : Parser::OperationInfo) : String
        # Try to extract from operation ID or path
        operation_id = op_info.operation_id.underscore

        # Common patterns
        if operation_id.includes?("get") && op_info.path.includes?("{")
          "show"
        elsif operation_id.includes?("get") || operation_id.includes?("list")
          "index"
        elsif operation_id.includes?("create") || operation_id.includes?("post")
          "create"
        elsif operation_id.includes?("update") || operation_id.includes?("put") || operation_id.includes?("patch")
          "update"
        elsif operation_id.includes?("delete") || operation_id.includes?("destroy")
          "destroy"
        else
          operation_id.split("_").last || "index"
        end
      end

      # Generate endpoint content
      private def generate_endpoint_content(op_info : Parser::OperationInfo, action : String) : String
        resource_class = @resource.camelcase
        resource_singular = @resource.camelcase.singularize
        endpoint_name = "#{resource_class}::#{resource_class}#{action.camelcase}Endpoint"
        request_class = "#{resource_class}::#{resource_class}#{action.camelcase}Request"
        response_class = "#{resource_class}::#{resource_class}#{action.camelcase}Page"

        method = op_info.method.downcase
        path = op_info.path
        summary = op_info.operation.summary || ""

        <<-ENDPOINT
        # #{summary}
        # Generated from OpenAPI specification
        struct #{endpoint_name}
          include Azu::Endpoint(#{request_class}, #{response_class})

          #{method} "#{path}"

          def call : #{response_class}
            # TODO: Implement #{action} action
            #{response_class}.new
          end
        end
        ENDPOINT
      end

      # Generate request and response classes for an operation
      private def generate_request_and_response(op_info : Parser::OperationInfo, action : String, force : Bool)
        # Extract request schema from requestBody
        request_schema = extract_request_schema(op_info)

        # Extract response schema from responses
        response_schema = extract_response_schema(op_info)

        # Generate request class
        request_generator = RequestGenerator.new(@resource, action, request_schema, @parser)
        request_generator.generate(force)

        # Generate response class
        response_generator = ResponseGenerator.new(@resource, action, response_schema, @parser)
        response_generator.generate(force)
      end

      # Extract request schema from operation requestBody
      private def extract_request_schema(op_info : Parser::OperationInfo) : Schema?
        request_body = op_info.operation.requestBody
        return nil unless request_body

        content = request_body.content
        return nil unless content

        # Look for application/json content type
        media_type = content["application/json"]?
        return nil unless media_type

        schema = media_type.schema
        return nil unless schema

        # If it's a reference, resolve it
        if ref = schema.ref
          @parser.resolve_ref(ref)
        else
          schema
        end
      end

      # Extract response schema from operation responses
      private def extract_response_schema(op_info : Parser::OperationInfo) : Schema?
        responses = op_info.operation.responses
        return nil unless responses

        # Look for 200 response
        response = responses["200"]?
        return nil unless response

        content = response.content
        return nil unless content

        # Look for application/json content type
        media_type = content["application/json"]?
        return nil unless media_type

        schema = media_type.schema
        return nil unless schema

        # If it's a reference, resolve it
        if ref = schema.ref
          @parser.resolve_ref(ref)
        else
          schema
        end
      end
    end
  end
end
