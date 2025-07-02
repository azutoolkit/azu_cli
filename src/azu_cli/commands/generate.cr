require "../command"
require "../generators/core/factory"

module AzuCLI::Commands
  # Optimized Generate command using SOLID principles and design patterns
  # Integrates with the new configuration-driven generator system
  class Generate < Command
    command_name "generate"
    description "Generate Azu components using optimized configuration-driven generators"
    usage "generate <generator_type> <name> [options]"

    def setup_command_options(parser : OptionParser)
      parser.on("--skip-tests", "Skip generating test files") do
        parsed_options["skip-tests"] = true
      end

      parser.on("--skip-routes", "Skip adding routes (for endpoints)") do
        parsed_options["skip-routes"] = true
      end

      parser.on("--file-upload", "Include file upload support") do
        parsed_options["file-upload"] = true
      end
    end

    def execute_with_options(
      options : Hash(String, String | Bool | Array(String)),
      args : Array(String),
    ) : String | Nil
      require_project_root!

      if args.empty?
        show_available_generators
        return "Help displayed"
      end

      generator_type = args.first
      component_name = args[1]? || ""

      # Check if this is a request for generator-specific help
      if component_name == "--help" || component_name == "-h"
        show_generator_help(generator_type)
        return "Help displayed"
      end

      # Validate generator type
      unless AzuCLI::Generator::Core::GeneratorFactory.exists?(generator_type)
        log.error("Unknown generator: #{generator_type}")
        show_available_generators
        return "Unknown generator error"
      end

      # Validate component name
      if component_name.empty?
        log.error("Component name is required")
        log.info("Usage: azu generate #{generator_type} <name> [options]")
        return "Component name required"
      end

      unless valid_component_name?(component_name)
        log.error("Invalid component name: #{component_name}")
        log.info("Component name must contain only letters, numbers, and underscores")
        log.info("Examples: user, user_profile, BlogPost")
        return "Invalid component name"
      end

      begin
        # Create generator options from arguments and remaining args
        generator_options = AzuCLI::Generator::Core::GeneratorOptions.from_parsed_options(
          options,
          args[2..] # attributes/additional arguments
        )

        # Create generator using factory
        generator = AzuCLI::Generator::Core::GeneratorFactory.create(
          generator_type,
          component_name,
          get_project_name,
          generator_options
        )

        # Execute generation
        generator.generate!

        log.success("Generated #{generator_type} '#{component_name}' successfully")
        return "Generated successfully"
      rescue ex : ArgumentError
        log.error("Error: #{ex.message}")
        show_available_generators
        return "Generation error"
      rescue ex : Exception
        log.error("Error generating #{generator_type}: #{ex.message}")
        return "Generation failed"
      end
    end

    private def show_available_generators
      puts "\n🔧 Available generators:".colorize(:yellow).bold

      descriptions = AzuCLI::Generator::Core::GeneratorFactory.generator_descriptions

      descriptions.each do |type, description|
        aliases = AzuCLI::Generator::Core::GeneratorFactory.aliases_for(type)
        alias_text = aliases.empty? ? "" : " (aliases: #{aliases.join(", ")})"
        puts "  #{type.ljust(12)} - #{description}#{alias_text}"
      end

      puts "\nUse 'azu generate <type> --help' for type-specific help"
    end

    private def show_generator_help(generator_type : String)
      puts "Help for #{generator_type} generator would be shown here"
      # TODO: Implement generator-specific help from configuration
    end

    private def valid_component_name?(name : String) : Bool
      # Component name should contain only letters, numbers, and underscores
      # Should start with a letter
      /\A[A-Za-z][A-Za-z0-9_]*\z/.match(name) != nil
    end

    def show_command_specific_help
      puts "The optimized generate command uses configuration-driven generators"
      puts "that follow SOLID principles and design patterns for better maintainability."
      puts
      puts "Arguments:"
      puts "  <generator_type>    Type of component to generate"
      puts "  <name>              Name of the component"
      puts "  [attributes...]     Component-specific attributes"
      puts
      puts "Options:"
      puts "  --force             Overwrite existing files"
      puts "  --skip-tests        Skip generating test files"
      puts "  --skip-routes       Skip adding routes (for endpoints)"
      puts "  --file-upload       Include file upload support"
      puts "  --help              Show help for specific generator"
      puts
      puts "Generator-specific syntax:"
      puts "  Model attributes:   name:string email:string age:integer"
      puts "  Migration attrs:    email:string age:integer active:boolean"
      puts "  Endpoint actions:   index show create update destroy"
      puts "  Page variables:     title='My Page' layout=application"
      puts "  Component events:   event:click event:submit event:change"
      puts "  Component attrs:    title:string count:integer visible:boolean"
      puts "  Validator types:    type:email type:phone type:url type:regex type:range"
      puts "  Validator args:     pattern:\\A[a-z]+\\z min:0 max:100 model:User"
      puts "  Channel events:     event:message event:typing event:connect"
      puts "  Request attrs:      name:string email:string --file-upload"
      puts "  Response attrs:     user:User data:Hash format:json template:custom.jinja"
      puts "  Handler types:      type:auth type:cors type:rate_limit type:logging type:security"
      puts
      puts "Configuration:"
      puts "  Generators are configured via YAML files in src/azu_cli/generators/config/"
      puts "  Each generator type has its own configuration with templates, validations, and patterns."
      puts "  This allows for easy customization and extension without code changes."
      puts
      puts "Architecture:"
      puts "  - Configuration-driven generation"
      puts "  - SOLID principles implementation"
      puts "  - Strategy pattern for different generation approaches"
      puts "  - Template method pattern for generation workflow"
      puts "  - Factory pattern for generator creation"
      puts "  - Dependency injection for strategies"
      puts
      puts "Benefits:"
      puts "  - Highly maintainable and extensible"
      puts "  - Easy to add new generator types"
      puts "  - Configuration changes don't require code changes"
      puts "  - Consistent generation patterns across all generators"
      puts "  - Better separation of concerns"
      puts
      puts "Examples:"
      puts "  azu generate contract UserContract name:string email:string"
      puts "  azu generate contract --help                    # Show contract generator help"
      puts "  azu generate contract LoginContract email:string password:string"
    end
  end
end
