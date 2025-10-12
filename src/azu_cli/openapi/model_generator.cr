require "./parser"
require "./schema_mapper"
require "../logger"

module AzuCLI
  module OpenAPI
    # Generate CQL models from OpenAPI schemas
    class ModelGenerator
      getter name : String
      getter schema : Schema
      getter parser : Parser

      def initialize(@name : String, @schema : Schema, @parser : Parser)
      end

      # Generate model file
      def generate(force : Bool = false)
        model_name = @name.camelcase
        file_name = @name.underscore
        output_dir = "./src/models"
        output_path = File.join(output_dir, "#{file_name}.cr")

        # Create directory if it doesn't exist
        Dir.mkdir_p(output_dir) unless Dir.exists?(output_dir)

        # Check if file exists
        if File.exists?(output_path) && !force
          Logger.warn("Model file already exists: #{output_path} (use --force to overwrite)")
          return
        end

        # Generate model content
        content = generate_model_content(model_name)

        # Write file
        File.write(output_path, content)
        Logger.success("✓ Generated model: #{output_path}")
      end

      # Generate model content
      private def generate_model_content(model_name : String) : String
        properties = @schema.properties || {} of String => Schema
        required_fields = @schema.required || [] of String

        # Build property definitions
        property_defs = properties.map do |prop_name, prop_schema|
          crystal_type = SchemaMapper.to_crystal_type(prop_schema)
          is_required = required_fields.includes?(prop_name)

          # Make non-required fields nullable
          unless is_required
            crystal_type = "#{crystal_type}?" unless crystal_type.ends_with?("?")
          end

          snake_name = prop_name.underscore
          description = prop_schema.description

          comment = description ? "  # #{description}\n" : ""
          "#{comment}  property #{snake_name} : #{crystal_type}"
        end.join("\n")

        <<-MODEL
        require "json"

        # #{@schema.description || model_name} model
        # Generated from OpenAPI schema
        struct #{model_name}
          include JSON::Serializable

        #{property_defs}

          def initialize(#{generate_initializer_params(properties, required_fields)})
        #{generate_initializer_body(properties)}
          end
        end
        MODEL
      end

      # Generate initializer parameters
      private def generate_initializer_params(properties : Hash(String, Schema), required : Array(String)) : String
        properties.map do |prop_name, prop_schema|
          crystal_type = SchemaMapper.to_crystal_type(prop_schema)
          is_required = required.includes?(prop_name)
          snake_name = prop_name.underscore

          if is_required
            "@#{snake_name} : #{crystal_type}"
          else
            crystal_type = "#{crystal_type}?" unless crystal_type.ends_with?("?")
            "@#{snake_name} : #{crystal_type} = nil"
          end
        end.join(", ")
      end

      # Generate initializer body
      private def generate_initializer_body(properties : Hash(String, Schema)) : String
        # Properties are assigned automatically via @param syntax
        ""
      end
    end
  end
end
