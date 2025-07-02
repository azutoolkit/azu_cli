require "./abstract_generator"
require "../optimized/contract_generator"
require "../optimized/component_generator"
require "../optimized/endpoint_generator"
require "../optimized/middleware_generator"
require "../optimized/migration_generator"
require "../optimized/model_generator"
require "../optimized/page_generator"
require "../optimized/service_generator"
require "../optimized/validator_generator"
require "../optimized/channel_generator"
require "../optimized/handler_generator"
require "../optimized/request_generator"
require "../optimized/response_generator"

module AzuCLI::Generator::Core
  # Factory pattern implementation for creating generators
  # Follows Single Responsibility and Open/Closed principles
  class GeneratorFactory
    # Registry of available generators (Strategy pattern)
    # Note: This will be populated as we refactor existing generators
    GENERATOR_REGISTRY = {} of String => AbstractGenerator.class

    # Aliases for generator types
    GENERATOR_ALIASES = {
      "m"          => "model",
      "e"          => "endpoint",
      "c"          => "contract",
      "p"          => "page",
      "comp"       => "component",
      "s"          => "service",
      "mid"        => "middleware",
      "mig"        => "migration",
      "v"          => "validator",
      "val"        => "validator",
      "ch"         => "channel",
      "req"        => "request",
      "res"        => "response",
      "h"          => "handler",
    }

    # Factory method - creates appropriate generator based on type
    def self.create(generator_type : String, name : String, project_name : String, options : GeneratorOptions = GeneratorOptions.new) : AbstractGenerator
      # Resolve aliases
      resolved_type = GENERATOR_ALIASES[generator_type]? || generator_type

      # Create generators using case statement for proper polymorphism
      case resolved_type
      when "contract"
        AzuCLI::Generator::ContractGenerator.new(name, project_name, options)
      when "component"
        AzuCLI::Generator::ComponentGenerator.new(name, project_name, options)
      when "endpoint"
        AzuCLI::Generator::EndpointGenerator.new(name, project_name, options)
      when "middleware"
        AzuCLI::Generator::MiddlewareGenerator.new(name, project_name, options)
      when "migration"
        AzuCLI::Generator::MigrationGenerator.new(name, project_name, options)
      when "model"
        AzuCLI::Generator::ModelGenerator.new(name, project_name, options)
      when "page"
        AzuCLI::Generator::PageGenerator.new(name, project_name, options)
      when "service"
        AzuCLI::Generator::ServiceGenerator.new(name, project_name, options)
      when "validator"
        AzuCLI::Generator::ValidatorGenerator.new(name, project_name, options)
      when "channel"
        AzuCLI::Generator::ChannelGenerator.new(name, project_name, options)
      when "handler"
        AzuCLI::Generator::HandlerGenerator.new(name, project_name, options)
      when "request"
        AzuCLI::Generator::RequestGenerator.new(name, project_name, options)
      when "response"
        AzuCLI::Generator::ResponseGenerator.new(name, project_name, options)
      else
        raise ArgumentError.new("Unknown generator type: #{generator_type}")
      end
    end

    # Get all available generator types
    def self.available_types : Array(String)
      ["contract", "component", "endpoint", "middleware", "migration", 
       "model", "page", "service", "validator", "channel", 
       "handler", "request", "response"]
    end

    # Get aliases for a generator type
    def self.aliases_for(generator_type : String) : Array(String)
      GENERATOR_ALIASES.select { |_, v| v == generator_type }.keys
    end

    # Check if generator type exists
    def self.exists?(generator_type : String) : Bool
      resolved_type = GENERATOR_ALIASES[generator_type]? || generator_type
      available_types.includes?(resolved_type)
    end

    # Get generator descriptions for help
    def self.generator_descriptions : Hash(String, String)
      descriptions = {} of String => String

      available_types.each do |type|
        # Load configuration to get description
        config = Configuration.new(type).load!
        description = config.get("description") || "Generate #{type} components"
        descriptions[type] = description
      end

      descriptions
    end
  end

  # Value object for generator options (following SOLID principles)
  struct GeneratorOptions
    property force : Bool
    property skip_tests : Bool
    property skip_routes : Bool
    property attributes : Hash(String, String)
    property additional_args : Array(String)
    property custom_options : Hash(String, String)

    def initialize(@force = false, @skip_tests = false, @skip_routes = false,
                   @attributes = {} of String => String,
                   @additional_args = [] of String,
                   @custom_options = {} of String => String)
    end

    # Factory method for creating options from command line arguments
    def self.from_args(args : Hash(String, String | Array(String)), positional : Array(String)) : GeneratorOptions
      force = has_flag?(args, "force")
      skip_tests = has_flag?(args, "skip-tests")
      skip_routes = has_flag?(args, "skip-routes")

      # Extract attributes from positional arguments
      attributes = parse_attributes(positional[2..])

      # Additional args that aren't attributes
      additional_args = positional[2..].reject { |arg| arg.includes?(":") }

      # Custom options from flags
      custom_options = extract_custom_options(args)

      new(force, skip_tests, skip_routes, attributes, additional_args, custom_options)
    end

    # Helper methods for parsing command line arguments
    private def self.has_flag?(args : Hash(String, String | Array(String)), flag : String) : Bool
      args.has_key?(flag) || args.has_key?("--#{flag}")
    end

    private def self.parse_attributes(args : Array(String)) : Hash(String, String)
      attributes = {} of String => String

      args.each do |arg|
        if arg.includes?(":")
          parts = arg.split(":", 2)
          if parts.size == 2
            attributes[parts[0]] = parts[1]
          end
        end
      end

      attributes
    end

    private def self.extract_custom_options(args : Hash(String, String | Array(String))) : Hash(String, String)
      custom = {} of String => String

      args.each do |key, value|
        next if ["force", "skip-tests", "skip-routes"].includes?(key)
        next if key.starts_with?("--")

        if value.is_a?(String)
          custom[key] = value
        elsif value.is_a?(Array(String))
          custom[key] = value.join(",")
        end
      end

      custom
    end
  end
end