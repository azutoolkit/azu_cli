require "./base"

module AzuCLI
  module Generators
    # Type alias for response attributes
    alias ResponseAttribute = NamedTuple(name: String, type: String, default: String)

    # Strategy pattern for handling response attributes
    struct ResponseConfiguration
      getter attributes : Array(ResponseAttribute)
      getter include_json : Bool

      def initialize(@attributes : Array(ResponseAttribute) = [] of ResponseAttribute,
                     @include_json : Bool = true)
      end

      def has_attributes?
        !@attributes.empty?
      end

      def required_attributes
        @attributes.select { |attr| attr[:default].empty? }
      end

      def optional_attributes
        @attributes.reject { |attr| attr[:default].empty? }
      end
    end

    class ResponseGenerator < Base
      directory "#{__DIR__}/../templates/generators/response"

      # Instance variables expected by Teeplate from template scanning
      @response_name : String
      @class_name : String
      @attributes : Array(ResponseAttribute)

      getter configuration : ResponseConfiguration

      def initialize(response_name : String,
                     attributes : Array(ResponseAttribute) = [] of ResponseAttribute,
                     include_json : Bool = true,
                     output_dir : String = "src",
                     generate_specs : Bool = true)
        super(response_name, output_dir, generate_specs)
        @configuration = ResponseConfiguration.new(attributes, include_json)
        @response_name = response_name
        @class_name = response_name.camelcase
        @attributes = attributes
      end

      def template_directory : String
        "#{__DIR__}/../templates/generators/response"
      end

      def build_output_path : String
        File.join(@output_dir, "responses", "#{@name}.cr")
      end

      # Override spec template name to match our template
      protected def spec_template_name : String
        "#{response_name}_spec.cr.ecr"
      end

      # Template methods for accessing response properties
      def response_name_camelcase
        @class_name
      end

      def response_name
        @response_name
      end

      # Convert snake_case to PascalCase for class name
      def class_name
        @class_name
      end

      # Delegation methods for configuration
      def attributes
        @attributes
      end

      def required_attributes
        @configuration.required_attributes
      end

      def optional_attributes
        @configuration.optional_attributes
      end

      # Generate getter declarations for each attribute
      def attribute_declarations
        @configuration.attributes.map do |attr|
          "@#{attr[:name]} : #{attr[:type]} = #{attr[:default]}"
        end.join("\n  ")
      end

      # Generate initializer parameters
      def initializer_parameters
        @configuration.attributes.map do |attr|
          "@#{attr[:name]} : #{attr[:type]} = #{attr[:default]}"
        end.join(", ")
      end

      # Check if JSON serialization should be included
      def json_serializable?
        @configuration.include_json
      end

      # Check if templates should be renderable (for compatibility with template)
      def include_templates_renderable?
        false # For now, set to false as this is not implemented
      end

      # Validation methods
      protected def validate_preconditions!
        super
        validate_attributes!
      end

      private def validate_attributes!
        @configuration.attributes.each do |attr|
          raise ArgumentError.new("Attribute name cannot be empty") if attr[:name].empty?
          raise ArgumentError.new("Attribute type cannot be empty") if attr[:type].empty?
        end
      end
    end
  end
end
