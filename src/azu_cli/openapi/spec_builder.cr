require "./spec"
require "./type_mapper"
require "./analyzer"
require "../logger"

module AzuCLI
  module OpenAPI
    # Builds OpenAPI specification from analyzed code
    class SpecBuilder
      getter analyzer : Analyzer
      getter project_name : String
      getter version : String

      def initialize(@project_name : String, @version : String = "1.0.0", project_path : String = ".")
        @analyzer = Analyzer.new(project_path)
      end

      # Build complete OpenAPI spec
      def build : Spec
        analysis = @analyzer.analyze

        spec = Spec.new
        spec.openapi = "3.1.0"
        spec.info = build_info
        spec.servers = build_servers
        spec.paths = build_paths(analysis[:endpoints].as(Array(EndpointExtractor::EndpointInfo)))
        spec.components = build_components(
          analysis[:models].as(Array(ModelExtractor::ModelInfo)),
          analysis[:requests].as(Array(RequestExtractor::RequestInfo)),
          analysis[:responses].as(Array(ResponseExtractor::ResponseInfo))
        )
        spec.tags = build_tags(analysis[:endpoints].as(Array(EndpointExtractor::EndpointInfo)))

        spec
      end

      # Build info section
      private def build_info : Info
        info = Info.new
        info.title = "#{@project_name.camelcase} API"
        info.version = @version
        info.description = "API documentation for #{@project_name}"
        info
      end

      # Build servers section
      private def build_servers : Array(Server)
        dev_server = Server.new("http://localhost:3000", "Development server")
        [dev_server]
      end

      # Build paths from endpoints
      private def build_paths(endpoints : Array(EndpointExtractor::EndpointInfo)) : Hash(String, PathItem)
        paths = {} of String => PathItem

        endpoints.each do |endpoint|
          path_item = paths[endpoint.path]? || PathItem.new

          operation = Operation.new
          operation.summary = generate_summary(endpoint)
          operation.operationId = generate_operation_id(endpoint)
          operation.tags = [extract_tag(endpoint.path)]
          operation.responses = build_responses(endpoint)

          # Set operation based on HTTP method
          case endpoint.method.downcase
          when "get"
            path_item.get = operation
          when "post"
            path_item.post = operation
            operation.requestBody = build_request_body(endpoint)
          when "put"
            path_item.put = operation
            operation.requestBody = build_request_body(endpoint)
          when "patch"
            path_item.patch = operation
            operation.requestBody = build_request_body(endpoint)
          when "delete"
            path_item.delete = operation
          when "options"
            path_item.options = operation
          when "head"
            path_item.head = operation
          end

          paths[endpoint.path] = path_item
        end

        paths
      end

      # Build components from models, requests, and responses
      private def build_components(
        models : Array(ModelExtractor::ModelInfo),
        requests : Array(RequestExtractor::RequestInfo),
        responses : Array(ResponseExtractor::ResponseInfo),
      ) : Components
        components = Components.new
        schemas = {} of String => Schema

        # Add models
        models.each do |model|
          schema = Schema.new
          schema.type = "object"
          schema.properties = TypeMapper.properties_to_schemas(model.properties)
          schema.required = TypeMapper.extract_required_fields(model.properties)

          schemas[model.name] = schema
        end

        # Add requests
        requests.each do |request|
          schema = Schema.new
          schema.type = "object"
          schema.properties = TypeMapper.properties_to_schemas(request.properties)
          schema.required = TypeMapper.extract_required_fields(request.properties)

          schemas[request.name] = schema
        end

        # Add responses
        responses.each do |response|
          schema = Schema.new
          schema.type = "object"
          schema.properties = TypeMapper.properties_to_schemas(response.properties)
          schema.required = TypeMapper.extract_required_fields(response.properties)

          schemas[response.name] = schema
        end

        components.schemas = schemas
        components
      end

      # Build tags from endpoints
      private def build_tags(endpoints : Array(EndpointExtractor::EndpointInfo)) : Array(Tag)
        tag_names = endpoints.map { |e| extract_tag(e.path) }.uniq!

        tag_names.map do |name|
          Tag.new(name, "#{name} operations")
        end
      end

      # Build responses for an endpoint
      private def build_responses(endpoint : EndpointExtractor::EndpointInfo) : Hash(String, Response)
        response = Response.new
        response.description = "Successful response"

        content = {} of String => MediaType
        media_type = MediaType.new

        # Create schema reference from response type
        schema = Schema.new
        response_type = endpoint.response_type.split("::").last
        schema.ref = "#/components/schemas/#{response_type}"
        media_type.schema = schema

        content["application/json"] = media_type
        response.content = content

        {"200" => response}
      end

      # Build request body for an endpoint
      private def build_request_body(endpoint : EndpointExtractor::EndpointInfo) : RequestBody
        request_body = RequestBody.new
        request_body.required = true

        content = {} of String => MediaType
        media_type = MediaType.new

        # Create schema reference from request type
        schema = Schema.new
        request_type = endpoint.request_type.split("::").last
        schema.ref = "#/components/schemas/#{request_type}"
        media_type.schema = schema

        content["application/json"] = media_type
        request_body.content = content

        request_body
      end

      # Generate operation summary
      private def generate_summary(endpoint : EndpointExtractor::EndpointInfo) : String
        action = endpoint.method.upcase
        resource = extract_tag(endpoint.path)
        "#{action} #{resource}"
      end

      # Generate operation ID
      private def generate_operation_id(endpoint : EndpointExtractor::EndpointInfo) : String
        parts = endpoint.path.split("/").reject(&.empty?)

        resource = parts.find { |p| !p.match(/^(api|v\d+)$/) && !p.starts_with?("{") }
        action = endpoint.method.downcase

        if endpoint.path.includes?("{")
          "#{action}#{resource.try(&.camelcase)}ById"
        else
          "#{action}#{resource.try(&.camelcase)}"
        end
      end

      # Extract tag from path
      private def extract_tag(path : String) : String
        parts = path.split("/").reject(&.empty?)
        resource = parts.find { |p| !p.match(/^(api|v\d+)$/) && !p.starts_with?("{") }
        resource.try(&.camelcase) || "Default"
      end
    end
  end
end
