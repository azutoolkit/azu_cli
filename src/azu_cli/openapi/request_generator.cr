require "./parser"
require "./schema_mapper"
require "../logger"

module AzuCLI
  module OpenAPI
    # Generate request classes from OpenAPI requestBody schemas
    class RequestGenerator
      getter resource : String
      getter action : String
      getter schema : Schema?
      getter parser : Parser

      def initialize(@resource : String, @action : String, @schema : Schema?, @parser : Parser)
      end

      # Generate request file
      def generate(force : Bool = false)
        output_dir = "./src/requests/#{@resource}"
        file_name = "#{@resource}_#{@action}_request.cr"
        output_path = File.join(output_dir, file_name)

        # Create directory if it doesn't exist
        Dir.mkdir_p(output_dir) unless Dir.exists?(output_dir)

        # Check if file exists
        if File.exists?(output_path) && !force
          Logger.warn("Request file already exists: #{output_path} (use --force to overwrite)")
          return
        end

        # Generate request content
        content = generate_request_content

        # Write file
        File.write(output_path, content)
        Logger.success("✓ Generated request: #{output_path}")
      end

      # Generate request content
      private def generate_request_content : String
        resource_class = @resource.camelcase.singularize
        request_class = "#{resource_class}::#{resource_class}#{@action.camelcase}Request"

        if schema = @schema
          properties = schema.properties || {} of String => Schema
          required_fields = schema.required || [] of String

          # Build property definitions
          property_defs = properties.map do |prop_name, prop_schema|
            crystal_type = SchemaMapper.to_crystal_type(prop_schema)
            is_required = required_fields.includes?(prop_name)
            snake_name = prop_name.underscore

            unless is_required
              crystal_type = "#{crystal_type}?" unless crystal_type.ends_with?("?")
            end

            "  property #{snake_name} : #{crystal_type}"
          end.join("\n")

          <<-REQUEST
          # Request class for #{@action} action
          # Generated from OpenAPI specification
          struct #{request_class} < Azu::Request
          #{property_defs}
          end
          REQUEST
        else
          # No schema, empty request
          <<-REQUEST
          # Request class for #{@action} action
          # Generated from OpenAPI specification
          struct #{request_class} < Azu::Request
          end
          REQUEST
        end
      end
    end
  end
end
