require "./parser"
require "./schema_mapper"
require "../logger"

module AzuCLI
  module OpenAPI
    # Generate response/page classes from OpenAPI response schemas
    class ResponseGenerator
      getter resource : String
      getter action : String
      getter schema : Schema?
      getter parser : Parser

      def initialize(@resource : String, @action : String, @schema : Schema?, @parser : Parser)
      end

      # Generate response file
      def generate(force : Bool = false)
        output_dir = "./src/pages/#{@resource}"
        file_name = "#{@resource}_#{@action}_page.cr"
        output_path = File.join(output_dir, file_name)

        # Create directory if it doesn't exist
        Dir.mkdir_p(output_dir) unless Dir.exists?(output_dir)

        # Check if file exists
        if File.exists?(output_path) && !force
          Logger.warn("Response file already exists: #{output_path} (use --force to overwrite)")
          return
        end

        # Generate response content
        content = generate_response_content

        # Write file
        File.write(output_path, content)
        Logger.success("✓ Generated response: #{output_path}")
      end

      # Generate response content
      private def generate_response_content : String
        resource_class = @resource.camelcase
        response_class = "#{resource_class}::#{resource_class}#{@action.camelcase}Page"

        if schema = @schema
          if schema.type != "object" && schema.properties.nil?
            return <<-RESPONSE
            require "json"

            struct #{response_class}
              include Azu::Response::Negotiable
              getter data : #{SchemaMapper.to_crystal_type(schema)}

              def initialize(@data)
              end

              def render_json : String
                data.to_json
              end
            end
            RESPONSE
          end
          properties = schema.properties || {} of String => Schema
          required_fields = schema.required || [] of String

          # Build property definitions
          property_defs = properties.map do |prop_name, prop_schema|
            SchemaMapper.property_definition(prop_name, prop_schema, required_fields.includes?(prop_name))
          end.join("\n")

          <<-RESPONSE
          require "json"

          # Response class for #{@action} action
          # Generated from OpenAPI specification
          struct #{response_class}
            include Azu::Response::Negotiable
            include JSON::Serializable

          #{property_defs}

            def initialize(#{SchemaMapper.initializer_params(properties, required_fields)})
            end

            def render_json : String
              to_json
            end
          end
          RESPONSE
        else
          # No schema, empty response
          <<-RESPONSE
          require "json"

          # Response class for #{@action} action
          # Generated from OpenAPI specification
          struct #{response_class}
            include Azu::Response::Negotiable
            include JSON::Serializable

            def initialize
            end

            def render_json : String
              to_json
            end
          end
          RESPONSE
        end
      end
    end
  end
end
