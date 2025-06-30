require "../command"
require "../generators/endpoint"
require "../generators/model"
require "../generators/service"
require "../generators/middleware"
require "../generators/contract"
require "../generators/page"

module AzuCLI::Commands
  # Generate command - creates various Azu components using generators
  class Generate < Command
    command_name "generate"
    description "Generate Azu components (endpoints, models, services, etc.)"
    usage "generate <generator_type> <name> [options]"

    GENERATORS = {
      "endpoint"   => "HTTP endpoint with contract and page",
      "model"      => "CQL Active Record model",
      "service"    => "DDD application service",
      "middleware" => "HTTP middleware component",
      "contract"   => "Request/response contract",
      "page"       => "Page component (view)",
      "scaffold"   => "Complete resource with CRUD operations",
    }

    GENERATOR_ALIASES = {
      "controller" => "endpoint",
      "e"          => "endpoint",
      "m"          => "model",
      "s"          => "service",
      "mw"         => "middleware",
      "c"          => "contract",
      "p"          => "page",
    }

    def execute(args : Hash(String, String | Array(String))) : String | Nil
      require_project_root!

      positional = get_positional_args(args)

      if positional.empty?
        show_available_generators
        return nil
      end

      generator_type = positional.first
      component_name = positional[1]? || ""

      # Resolve aliases
      generator_type = GENERATOR_ALIASES[generator_type]? || generator_type

      # Validate generator type
      unless GENERATORS.has_key?(generator_type)
        log.error("Unknown generator: #{generator_type}")
        show_available_generators
        return nil
      end

      # Validate component name
      if component_name.empty?
        log.error("Component name is required")
        log.info("Usage: azu generate #{generator_type} <name> [options]")
        return nil
      end

      unless valid_component_name?(component_name)
        log.error("Invalid component name: #{component_name}")
        log.info("Component name must contain only letters, numbers, and underscores")
        log.info("Examples: user, user_profile, BlogPost")
        return nil
      end

      # Get options
      force = has_flag?(args, "force")
      skip_tests = has_flag?(args, "skip-tests")
      skip_routes = has_flag?(args, "skip-routes")

      # Get additional arguments for specific generators
      additional_args = positional[2..]

      # Execute the appropriate generator
      case generator_type
      when "endpoint"
        generate_endpoint(component_name, additional_args, force, skip_tests, skip_routes)
      when "model"
        generate_model(component_name, additional_args, force, skip_tests)
      when "service"
        generate_service(component_name, additional_args, force, skip_tests)
      when "middleware"
        generate_middleware(component_name, additional_args, force, skip_tests)
      when "contract"
        generate_contract(component_name, additional_args, force, skip_tests)
      when "page"
        generate_page(component_name, additional_args, force, skip_tests)
      when "scaffold"
        generate_scaffold(component_name, additional_args, force, skip_tests, skip_routes)
      end

      nil
    end

    private def valid_component_name?(name : String) : Bool
      # Allow PascalCase, camelCase, snake_case, and kebab-case
      /^[a-zA-Z][a-zA-Z0-9_-]*$/.matches?(name)
    end

    private def show_available_generators
      puts
      puts "🛠️  Available Generators:".colorize(:cyan).bold
      puts

      GENERATORS.each do |type, description|
        aliases = GENERATOR_ALIASES.select { |_, v| v == type }.keys
        alias_text = aliases.empty? ? "" : " (#{aliases.join(", ")})".colorize(:dark_gray)

        puts "  #{type.colorize(:green).bold}#{alias_text}"
        puts "    #{description}"
        puts
      end

      puts "Examples:".colorize(:yellow).bold
      puts "  azu generate endpoint users"
      puts "  azu generate model User name:string email:string"
      puts "  azu generate service UserRegistration"
      puts "  azu generate scaffold Post title:string content:text"
      puts
      puts "Use 'azu generate <type> --help' for specific generator options"
    end

    private def generate_endpoint(name : String, args : Array(String), force : Bool, skip_tests : Bool, skip_routes : Bool)
      log.info("Generating endpoint: #{name}")

      generator = Generator::Endpoint.new(
        name: name,
        project_name: get_project_name,
        actions: extract_actions(args),
        force: force,
        skip_tests: skip_tests,
        skip_routes: skip_routes
      )

      generator.generate!

      log.success("Endpoint #{name} generated successfully!")
      show_endpoint_next_steps(name)
    end

    private def generate_model(name : String, args : Array(String), force : Bool, skip_tests : Bool)
      log.info("Generating model: #{name}")

      attributes = parse_attributes(args)

      generator = Generator::Model.new(
        name: name,
        project_name: get_project_name,
        attributes: attributes,
        force: force,
        skip_tests: skip_tests
      )

      generator.generate!

      log.success("Model #{name} generated successfully!")
      show_model_next_steps(name)
    end

    private def generate_service(name : String, args : Array(String), force : Bool, skip_tests : Bool)
      log.info("Generating service: #{name}")

      generator = Generator::Service.new(
        name: name,
        project_name: get_project_name,
        methods: args,
        force: force,
        skip_tests: skip_tests
      )

      generator.generate!

      log.success("Service #{name} generated successfully!")
      show_service_next_steps(name)
    end

    private def generate_middleware(name : String, args : Array(String), force : Bool, skip_tests : Bool)
      log.info("Generating middleware: #{name}")

      generator = Generator::Middleware.new(
        name: name,
        project_name: get_project_name,
        force: force,
        skip_tests: skip_tests
      )

      generator.generate!

      log.success("Middleware #{name} generated successfully!")
      show_middleware_next_steps(name)
    end

    private def generate_contract(name : String, args : Array(String), force : Bool, skip_tests : Bool)
      log.info("Generating contract: #{name}")

      attributes = parse_attributes(args)

      generator = Generator::Contract.new(
        name: name,
        project_name: get_project_name,
        attributes: attributes,
        force: force,
        skip_tests: skip_tests
      )

      generator.generate!

      log.success("Contract #{name} generated successfully!")
    end

    private def generate_page(name : String, args : Array(String), force : Bool, skip_tests : Bool)
      log.info("Generating page: #{name}")

      generator = Generator::Page.new(
        name: name,
        project_name: get_project_name,
        template_vars: parse_template_vars(args),
        force: force,
        skip_tests: skip_tests
      )

      generator.generate!

      log.success("Page #{name} generated successfully!")
    end

    private def generate_scaffold(name : String, args : Array(String), force : Bool, skip_tests : Bool, skip_routes : Bool)
      log.info("Generating scaffold: #{name}")

      attributes = parse_attributes(args)

      # Generate all components for a complete resource
      model_generator = Generator::Model.new(
        name: name,
        project_name: get_project_name,
        attributes: attributes,
        force: force,
        skip_tests: skip_tests
      )

      endpoint_generator = Generator::Endpoint.new(
        name: name,
        project_name: get_project_name,
        actions: ["index", "show", "new", "create", "edit", "update", "destroy"],
        force: force,
        skip_tests: skip_tests,
        skip_routes: skip_routes
      )

      # Generate components
      model_generator.generate!
      endpoint_generator.generate!

      log.success("Scaffold #{name} generated successfully!")
      show_scaffold_next_steps(name)
    end

    private def extract_actions(args : Array(String)) : Array(String)
      actions = args.select { |arg| !arg.includes?(":") }
      actions.empty? ? ["index", "show", "new", "create", "edit", "update", "destroy"] : actions
    end

    private def parse_attributes(args : Array(String)) : Hash(String, String)
      attributes = Hash(String, String).new

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

    private def parse_template_vars(args : Array(String)) : Hash(String, String)
      vars = Hash(String, String).new

      args.each do |arg|
        if arg.includes?("=")
          parts = arg.split("=", 2)
          if parts.size == 2
            vars[parts[0]] = parts[1]
          end
        end
      end

      vars
    end

    private def show_endpoint_next_steps(name : String)
      puts
      puts "📋 Next Steps:".colorize(:yellow).bold
      puts "  1. Define your endpoint routes in the #{name} endpoint"
      puts "  2. Implement the business logic in the call methods"
      puts "  3. Update the contracts with proper validation rules"
      puts "  4. Customize the page templates"
      puts "  5. Add tests in spec/endpoints/#{name.downcase}_spec.cr"
    end

    private def show_model_next_steps(name : String)
      puts
      puts "📋 Next Steps:".colorize(:yellow).bold
      puts "  1. Run 'azu db:create_migration #{name.downcase}' to create the migration"
      puts "  2. Add validations and associations to your model"
      puts "  3. Run 'azu db:migrate' to apply the migration"
      puts "  4. Add model tests in spec/models/#{name.downcase}_spec.cr"
    end

    private def show_service_next_steps(name : String)
      puts
      puts "📋 Next Steps:".colorize(:yellow).bold
      puts "  1. Implement the service methods in src/services/#{name.downcase}.cr"
      puts "  2. Add service dependencies via dependency injection"
      puts "  3. Add proper error handling and validation"
      puts "  4. Add service tests in spec/services/#{name.downcase}_spec.cr"
    end

    private def show_middleware_next_steps(name : String)
      puts
      puts "📋 Next Steps:".colorize(:yellow).bold
      puts "  1. Implement the middleware logic in src/middleware/#{name.downcase}.cr"
      puts "  2. Add the middleware to your application stack"
      puts "  3. Configure middleware options if needed"
      puts "  4. Add middleware tests in spec/middleware/#{name.downcase}_spec.cr"
    end

    private def show_scaffold_next_steps(name : String)
      puts
      puts "📋 Next Steps:".colorize(:yellow).bold
      puts "  1. Run 'azu db:create_migration #{name.downcase}' to create the migration"
      puts "  2. Run 'azu db:migrate' to apply the migration"
      puts "  3. Customize the generated templates and endpoints"
      puts "  4. Add authentication and authorization as needed"
      puts "  5. Test the complete CRUD functionality"
    end

    def show_command_specific_help
      puts "Arguments:"
      puts "  <generator_type>    Type of component to generate"
      puts "  <name>              Name of the component"
      puts "  [attributes...]     Component-specific attributes"
      puts
      puts "Options:"
      puts "  --force             Overwrite existing files"
      puts "  --skip-tests        Skip generating test files"
      puts "  --skip-routes       Skip adding routes (for endpoints)"
      puts
      puts "Generator-specific syntax:"
      puts "  Model attributes:   name:string email:string age:integer"
      puts "  Endpoint actions:   index show create update destroy"
      puts "  Page variables:     title='My Page' layout=application"
      puts
      puts "Examples:"
      puts "  azu generate endpoint users"
      puts "  azu generate model User name:string email:string"
      puts "  azu generate service UserRegistration"
      puts "  azu generate middleware Authentication"
      puts "  azu generate scaffold Post title:string content:text"
    end
  end
end
