require "./configuration"
require "./strategies"

module AzuCLI::Generator::Core
  # Abstract base generator implementing Template Method pattern
  # Follows SOLID principles with dependency injection of strategies
  abstract class AbstractGenerator
    getter name : String
    getter project_name : String
    getter force : Bool
    getter skip_tests : Bool

    # Strategy dependencies (Dependency Inversion Principle)
    property template_strategy : TemplateStrategy
    property file_strategy : FileCreationStrategy
    property naming_strategy : NamingStrategy

    @config : Configuration?
    @validation_strategy : ValidationStrategy?

    def initialize(@name : String, @project_name : String, @force = false, @skip_tests = false)
      # Initialize strategies with dependency injection
      @template_strategy = EcrTemplateStrategy.new
      @file_strategy = StandardFileCreationStrategy.new(@force, true)
      @naming_strategy = StandardNamingStrategy.new

      # Configuration and validation strategy will be loaded lazily
      @config = nil
      @validation_strategy = nil
    end

    def config : Configuration
      @config ||= Configuration.load(generator_type)
    end

    def validation_strategy : ValidationStrategy
      @validation_strategy ||= StandardValidationStrategy.new(config)
    end

    # Template Method pattern - defines the skeleton of generation algorithm
    def generate! : String
      validate_input!
      create_directories
      generate_files
      generate_tests unless skip_tests
      post_generation_tasks

      success_message
    end

    # Alias for generate! to maintain compatibility with tests
    def call : String
      generate!
    end

    # Abstract methods that subclasses must implement (Open/Closed Principle)
    abstract def generator_type : String
    abstract def generate_files : Nil

    # Hook methods that subclasses can override
    def validate_input! : Nil
      errors = validation_strategy.validate(name, {} of String => String)
      unless errors.empty?
        raise ArgumentError.new(errors.join(", "))
      end
    end

    def create_directories : Nil
      directories = config.get_array("directories.source")
      directories.each do |dir|
        file_strategy.create_directory(dir)
      end
    end

    def generate_tests : Nil
      # Default test generation - can be overridden
    end

    def post_generation_tasks : Nil
      # Hook for post-generation tasks - can be overridden
      show_next_steps
    end

    def success_message : String
      template = config.get("messages.success") || "Generated %{type} %{name} successfully!"
      template % {type: generator_type, name: name}
    end

    # Common helper methods available to all generators
    def class_name : String
      naming_strategy.class_name(name)
    end

    def snake_case_name : String
      naming_strategy.snake_case_name(name)
    end

    def kebab_case_name : String
      naming_strategy.kebab_case_name(name)
    end

    def plural_name : String
      naming_strategy.plural_name(name)
    end

    def plural_class_name : String
      naming_strategy.class_name(plural_name)
    end

    def module_name : String
      naming_strategy.module_name(project_name)
    end

    # Template variable generation
    def default_template_variables : Hash(String, String)
      {
        "name"              => name,
        "class_name"        => class_name,
        "snake_case_name"   => snake_case_name,
        "kebab_case_name"   => kebab_case_name,
        "plural_name"       => plural_name,
        "plural_class_name" => plural_class_name,
        "module_name"       => module_name,
        "project_name"      => project_name,
        "project_module"    => module_name,
        "timestamp"         => Time.utc.to_rfc3339,
      }
    end

    # File creation helpers
    def create_file_from_template(template_name : String, output_path : String, variables : Hash(String, String) = {} of String => String, description : String = "") : Bool
      template_path = get_template_path(template_name)
      all_variables = default_template_variables.merge(variables)

      content = template_strategy.render(template_path, all_variables)
      options = {"description" => description}

      file_strategy.create_file(output_path, content, options)
    end

    def get_template_path(template_name : String) : String
      templates_dir = config.get("directories.templates") || "src/azu_cli/templates/generators"
      File.join(templates_dir, template_name)
    end

    # Type mapping helpers
    def crystal_type(type : String) : String
      crystal_types = config.get_hash("crystal_types")
      crystal_types[type.downcase]? || "String"
    end

    def cql_type(type : String) : String
      cql_types = config.get_hash("cql_types")
      cql_types[type.downcase]? || "String"
    end

    # Show next steps based on configuration
    private def show_next_steps
      steps = config.get_array("next_steps")
      return if steps.empty?

      puts
      puts "📋 Next Steps:".colorize(:yellow).bold
      steps.each do |step|
        formatted_step = step % {
          name:            name,
          class_name:      class_name,
          snake_case_name: snake_case_name,
          plural_name:     plural_name,
        }
        puts "  #{formatted_step}"
      end
    end

    # Show usage examples
    def show_usage_examples
      examples = config.get_array("usage_examples")
      return if examples.empty?

      puts
      puts "Examples:".colorize(:yellow).bold
      examples.each do |example|
        puts "  #{example}"
      end
    end
  end
end
