require "../command"
require "../generators/optimized_base"
require "../generators/optimized/contract_generator"

module AzuCLI::Commands
  # Optimized Generate command using SOLID principles and design patterns
  # Integrates with the new configuration-driven generator system
  class GenerateOptimized < Command
    command_name "generate"
    description "Generate Azu components using optimized configuration-driven generators"
    usage "generate <generator_type> <name> [options]"

    # Register available generators with the factory
    private def self.register_generators
      AzuCLI::Generator::OptimizedBase.register_generator("contract", AzuCLI::Generator::ContractGenerator)
      # Other generators will be registered as they are migrated
    end

    def execute(args : Hash(String, String | Array(String))) : String | Nil
      require_project_root!

      # Ensure generators are registered
      self.class.register_generators

      positional = get_positional_args(args)

      if positional.empty?
        show_available_generators
        return "Help displayed"
      end

      generator_type = positional.first
      component_name = positional[1]? || ""

      # Check if this is a request for generator-specific help
      if component_name == "--help" || component_name == "-h"
        AzuCLI::Generator::OptimizedBase.show_generator_help(generator_type)
        return "Help displayed"
      end

      # Validate generator type
      unless AzuCLI::Generator::OptimizedBase.supports?(generator_type)
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

      unless AzuCLI::Generator::OptimizedBase.valid_component_name?(component_name)
        log.error("Invalid component name: #{component_name}")
        log.info("Component name must contain only letters, numbers, and underscores")
        log.info("Examples: user, user_profile, BlogPost")
        return "Invalid component name"
      end

      # Generate using the optimized system
      result = AzuCLI::Generator::OptimizedBase.generate(
        generator_type,
        component_name,
        get_project_name,
        args,
        positional
      )

      # Check if generation was successful
      if result.starts_with?("Error:") || result.starts_with?("Generation failed:")
        log.error(result)
        return result
      else
        log.success(result)
        return "Generated successfully"
      end
    end

    private def show_available_generators
      AzuCLI::Generator::OptimizedBase.show_available_generators
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