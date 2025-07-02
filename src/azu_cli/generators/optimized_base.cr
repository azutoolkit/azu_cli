require "cadmium_inflector"
require "./core/configuration"
require "./core/strategies"
require "./core/abstract_generator"
require "./core/factory"

module AzuCLI
  module Generator
    # Optimized Base Generator that bridges old and new systems
    # Follows SOLID principles and uses dependency injection
    class OptimizedBase
      include Core

      # Factory method for creating generators (Factory Pattern)
      def self.create(type : String, name : String, project_name : String, args : Hash(String, String | Array(String)), positional : Array(String)) : AbstractGenerator
        options = GeneratorOptions.from_args(args, positional)
        GeneratorFactory.create(type, name, project_name, options)
      end

      # Command interface for integration with existing command system
      def self.generate(type : String, name : String, project_name : String, args : Hash(String, String | Array(String)), positional : Array(String)) : String
        begin
          generator = create(type, name, project_name, args, positional)
          generator.generate!
        rescue ex : ArgumentError
          "Error: #{ex.message}"
        rescue ex : Exception
          "Generation failed: #{ex.message}"
        end
      end

      # Check if generator type is supported
      def self.supports?(type : String) : Bool
        GeneratorFactory.exists?(type)
      end

      # Get available generator types
      def self.available_types : Array(String)
        GeneratorFactory.available_types
      end

      # Get generator descriptions for help
      def self.descriptions : Hash(String, String)
        GeneratorFactory.generator_descriptions
      end

      # Show available generators with descriptions and aliases
      def self.show_available_generators
        puts
        puts "🛠️  Available Generators:".colorize(:cyan).bold
        puts

        descriptions.each do |type, description|
          aliases = GeneratorFactory.aliases_for(type)
          alias_text = aliases.empty? ? "" : " (#{aliases.join(", ")})".colorize(:dark_gray)

          puts "  #{type.colorize(:green).bold}#{alias_text}"
          puts "    #{description}"
          puts
        end

        puts "Examples:".colorize(:yellow).bold
        puts "  azu generate model User name:string email:string"
        puts "  azu generate endpoint users"
        puts "  azu generate validator EmailValidator type:email"
        puts "  azu generate component Counter count:integer --websocket"
        puts
        puts "Use 'azu generate <type> --help' for specific generator options"
      end

      # Validation helper for component names
      def self.valid_component_name?(name : String) : Bool
        /^[a-zA-Z][a-zA-Z0-9_-]*$/.matches?(name)
      end

      # Parse attributes from command line arguments
      def self.parse_attributes(args : Array(String)) : Hash(String, String)
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

      # Check for command line flags
      def self.has_flag?(args : Hash(String, String | Array(String)), flag : String) : Bool
        args.has_key?(flag) || args.has_key?("--#{flag}")
      end

      # Extract positional arguments from command arguments
      def self.get_positional_args(args : Hash(String, String | Array(String))) : Array(String)
        if positional = args["positional"]?
          case positional
          when Array(String)
            positional
          when String
            [positional]
          else
            [] of String
          end
        else
          [] of String
        end
      end

      # Register a new generator type (Open/Closed Principle)
      def self.register_generator(type : String, generator_class : AbstractGenerator.class)
        GeneratorFactory::GENERATOR_REGISTRY[type] = generator_class
      end

      # Show help for specific generator type
      def self.show_generator_help(type : String)
        return unless supports?(type)

        config = Configuration.load(type)

        puts "#{type.capitalize} Generator".colorize(:cyan).bold
        puts
        puts "Description:"
        puts "  #{config.get("description") || "Generate #{type} components"}"
        puts

        # Show usage examples
        examples = config.get_array("usage_examples")
        unless examples.empty?
          puts "Examples:"
          examples.each do |example|
            puts "  #{example}"
          end
          puts
        end

        # Show next steps
        steps = config.get_array("next_steps")
        unless steps.empty?
          puts "Next Steps:"
          steps.each_with_index do |step, index|
            puts "  #{index + 1}. #{step}"
          end
        end
      end
    end
  end
end