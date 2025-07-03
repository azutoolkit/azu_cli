require "./base"
require "./main_app_generator"
require "./model_generator"
require "./request_generator"
require "./response_generator"
require "./server_generator"
require "./validator_generator"
require "./endpoint_generator"

module AzuCLI
  module Generators
    # Factory pattern for creating generators
    # Provides a centralized way to create and configure generators
    class Factory
      # Error class for factory-specific errors
      class GeneratorError < Exception; end

      # Registry of available generator types
      GENERATOR_TYPES = {
        "app"       => MainAppGenerator,
        "model"     => ModelGenerator,
        "request"   => RequestGenerator,
        "response"  => ResponseGenerator,
        "server"    => ServerGenerator,
        "validator" => ValidatorGenerator,
        "endpoint"  => EndpointGenerator,
      }

      # Create a generator instance based on type and configuration
      def self.create(type : String, name : String, **options) : Base
        generator_class = GENERATOR_TYPES[type]?
        raise GeneratorError.new("Unknown generator type: #{type}") unless generator_class

        case type
        when "app"
          create_app_generator(name, **options)
        when "model"
          create_model_generator(name, **options)
        when "request"
          create_request_generator(name, **options)
        when "response"
          create_response_generator(name, **options)
        when "server"
          create_server_generator(name, **options)
        when "validator"
          create_validator_generator(name, **options)
        when "endpoint"
          create_endpoint_generator(name, **options)
        else
          raise GeneratorError.new("Unsupported generator type: #{type}")
        end
      end

      # Get list of available generator types
      def self.available_types : Array(String)
        GENERATOR_TYPES.keys
      end

      # Check if a generator type is supported
      def self.supports?(type : String) : Bool
        GENERATOR_TYPES.has_key?(type)
      end

      # Validation for common generator options
      def self.validate_common_options(**options)
        if output_dir = options[:output_dir]?
          raise GeneratorError.new("Output directory cannot be empty") if output_dir.to_s.empty?
        end
      end

      # Private factory methods for each generator type
      private def self.create_app_generator(name : String, **options) : MainAppGenerator
        validate_common_options(**options)
        output_dir = options[:output_dir]?.try(&.to_s) || "src"
        MainAppGenerator.new(name, output_dir)
      end

      private def self.create_model_generator(name : String, **options) : ModelGenerator
        validate_common_options(**options)

        attributes = options[:attributes]?.try(&.as(Array(AttributeDefinition))) || [] of AttributeDefinition
        associations = options[:associations]?.try(&.as(Array(AssociationDefinition))) || [] of AssociationDefinition
        validations = options[:validations]?.try(&.as(Array(ValidationDefinition))) || [] of ValidationDefinition
        output_dir = options[:output_dir]?.try(&.to_s) || "src"

        ModelGenerator.new(name, attributes, associations, validations, output_dir)
      end

      private def self.create_request_generator(name : String, **options) : RequestGenerator
        validate_common_options(**options)

        properties = options[:properties]?.try(&.as(Array(PropertyDefinition))) || [] of PropertyDefinition
        output_dir = options[:output_dir]?.try(&.to_s) || "src"

        RequestGenerator.new(name, properties, output_dir)
      end

      private def self.create_response_generator(name : String, **options) : ResponseGenerator
        validate_common_options(**options)

        attributes = options[:attributes]?.try(&.as(Array(ResponseAttribute))) || [] of ResponseAttribute
        include_json = options[:include_json]?.try(&.as(Bool)) || true
        output_dir = options[:output_dir]?.try(&.to_s) || "src"

        ResponseGenerator.new(name, attributes, include_json, output_dir)
      end

      private def self.create_server_generator(name : String, **options) : ServerGenerator
        validate_common_options(**options)

        handlers = options[:handlers]?.try(&.as(Array(String))) || ["web", "api"]
        output_dir = options[:output_dir]?.try(&.to_s) || "."

        ServerGenerator.new(name, handlers, output_dir)
      end

      private def self.create_validator_generator(name : String, **options) : ValidatorGenerator
        validate_common_options(**options)

        model_name = options[:model_name]?.try(&.to_s)
        raise GeneratorError.new("Model name is required for validator generator") unless model_name

        output_dir = options[:output_dir]?.try(&.to_s) || "src"

        ValidatorGenerator.new(name, model_name, output_dir)
      end

      private def self.create_endpoint_generator(name : String, **options) : EndpointGenerator
        validate_common_options(**options)

        action = options[:action]?.try(&.to_s)
        raise GeneratorError.new("Action is required for endpoint generator") unless action

        request_class = options[:request_class]?.try(&.to_s)
        response_class = options[:response_class]?.try(&.to_s)
        service_class = options[:service_class]?.try(&.to_s)
        namespace = options[:namespace]?.try(&.to_s)
        output_dir = options[:output_dir]?.try(&.to_s) || "src"

        EndpointGenerator.new(name, action, request_class, response_class, service_class, namespace, output_dir)
      end
    end

    # Builder pattern for complex generator configurations
    # Provides a fluent interface for building generator configurations
    class GeneratorBuilder
      getter type : String
      getter name : String
      getter options : Hash(Symbol, String | Bool | Array(String) | Array(AttributeDefinition) | Array(AssociationDefinition) | Array(ValidationDefinition) | Array(PropertyDefinition) | Array(ResponseAttribute))

      def initialize(@type : String, @name : String)
        @options = {} of Symbol => String | Bool | Array(String) | Array(AttributeDefinition) | Array(AssociationDefinition) | Array(ValidationDefinition) | Array(PropertyDefinition) | Array(ResponseAttribute)
      end

      def output_dir(dir : String)
        @options[:output_dir] = dir
        self
      end

      def attributes(attrs : Array(AttributeDefinition))
        @options[:attributes] = attrs
        self
      end

      def associations(assocs : Array(AssociationDefinition))
        @options[:associations] = assocs
        self
      end

      def validations(vals : Array(ValidationDefinition))
        @options[:validations] = vals
        self
      end

      def properties(props : Array(PropertyDefinition))
        @options[:properties] = props
        self
      end

      def response_attributes(attrs : Array(ResponseAttribute))
        @options[:attributes] = attrs
        self
      end

      def handlers(handlers : Array(String))
        @options[:handlers] = handlers
        self
      end

      def model_name(name : String)
        @options[:model_name] = name
        self
      end

      def action(action : String)
        @options[:action] = action
        self
      end

      def request_class(class_name : String)
        @options[:request_class] = class_name
        self
      end

      def response_class(class_name : String)
        @options[:response_class] = class_name
        self
      end

      def service_class(class_name : String)
        @options[:service_class] = class_name
        self
      end

      def namespace(namespace : String)
        @options[:namespace] = namespace
        self
      end

      def include_json(include_json_flag : Bool = true)
        @options[:include_json] = include_json_flag
        self
      end

      def build : Base
        Factory.create(@type, @name, **@options)
      end
    end
  end
end
