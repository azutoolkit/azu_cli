require "./base"

module AzuCLI
  module Generators
    # Type alias for better readability
    alias PropertyDefinition = NamedTuple(name: String, type: String, default: String, validations: Array(String))

    # Strategy pattern for handling request properties
    struct RequestConfiguration
      getter properties : Array(PropertyDefinition)

      def initialize(@properties : Array(PropertyDefinition) = [] of PropertyDefinition)
      end

      def has_properties?
        !@properties.empty?
      end

      def required_properties
        @properties.select { |prop| prop[:default].empty? }
      end

      def optional_properties
        @properties.reject { |prop| prop[:default].empty? }
      end
    end

    class RequestGenerator < Base
      directory "#{__DIR__}/../templates/generators/request"

      # Instance variables expected by Teeplate from template scanning
      @request_name : String
      @request_name_camelcase : String
      @properties : Array(PropertyDefinition)

      getter configuration : RequestConfiguration

      def initialize(request_name : String,
                     properties : Array(PropertyDefinition) = [] of PropertyDefinition,
                     output_dir : String = "src",
                     generate_specs : Bool = true)
        super(request_name, output_dir, generate_specs)
        @configuration = RequestConfiguration.new(properties)
        @request_name = request_name
        @request_name_camelcase = request_name.camelcase
        @properties = properties
      end

      def template_directory : String
        "#{__DIR__}/../templates/generators/request"
      end

      def build_output_path : String
        File.join(@output_dir, "requests", "#{@name}.cr")
      end

      # Override spec template name to match our template
      protected def spec_template_name : String
        "#{request_name}_spec.cr.ecr"
      end

      # Template methods for accessing request properties
      def request_name_camelcase
        @request_name_camelcase
      end

      def request_name
        @request_name
      end

      # Delegation methods for configuration
      def properties
        @properties
      end

      def required_properties
        @configuration.required_properties
      end

      def optional_properties
        @configuration.optional_properties
      end

      # Validation methods
      protected def validate_preconditions!
        super
        validate_properties!
      end

      private def validate_properties!
        @configuration.properties.each do |prop|
          raise ArgumentError.new("Property name cannot be empty") if prop[:name].empty?
          raise ArgumentError.new("Property type cannot be empty") if prop[:type].empty?
          validate_property_validations!(prop)
        end
      end

      private def validate_property_validations!(property : PropertyDefinition)
        property[:validations].each do |validation|
          raise ArgumentError.new("Validation rule cannot be empty") if validation.empty?
        end
      end
    end
  end
end
