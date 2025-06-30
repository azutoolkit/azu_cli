require "../command"
require "../generators/endpoint"
require "../generators/model"
require "../generators/service"
require "../generators/middleware"
require "../generators/contract"
require "../generators/page"
require "../generators/migration"
require "../generators/component"
require "../generators/custom_validator"

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
      "component"  => "Live interactive component with real-time features",
      "validator"  => "Custom CQL validator with validation logic",
      "migration"  => "Database migration file",
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
      "comp"       => "component",
      "val"        => "validator",
      "v"          => "validator",
      "mig"        => "migration",
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
      when "component"
        generate_component(component_name, additional_args, force, skip_tests)
      when "validator"
        generate_validator(component_name, additional_args, force, skip_tests)
      when "migration"
        generate_migration(component_name, additional_args, force)
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
      puts "  azu generate component Counter count:integer --websocket"
      puts "  azu generate validator EmailValidator type:email"
      puts "  azu generate migration create_users_table"
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

    private def generate_component(name : String, args : Array(String), force : Bool, skip_tests : Bool)
      log.info("Generating component: #{name}")

      # Parse arguments for component generation
      attributes = parse_attributes(args)
      events = extract_events(args)
      with_websocket = has_websocket_flag?(args)

      generator = Generator::Component.new(
        name: name,
        project_name: get_project_name,
        attributes: attributes,
        events: events,
        with_websocket: with_websocket,
        force: force,
        skip_tests: skip_tests
      )

      generator.generate!

      log.success("Component #{name} generated successfully!")
      show_component_next_steps(name)
    end

    private def generate_validator(name : String, args : Array(String), force : Bool, skip_tests : Bool)
      log.info("Generating validator: #{name}")

      # Parse arguments for validator generation
      attributes = parse_attributes(args)
      validation_type = extract_validation_type(args)
      model_name = extract_model_name(args)

      generator = Generator::CustomValidator.new(
        name: name,
        project_name: get_project_name,
        validation_type: validation_type,
        model_name: model_name,
        attributes: attributes,
        force: force,
        skip_tests: skip_tests
      )

      generator.generate!

      log.success("Validator #{name} generated successfully!")
      show_validator_next_steps(name, validation_type)
    end

    private def generate_migration(name : String, args : Array(String), force : Bool)
      log.info("Generating migration: #{name}")

      # Parse attributes for migration content
      attributes = args.select { |arg| arg.includes?(":") }

      generator = Generator::Migration.new(
        name: name,
        project_name: get_project_name,
        attributes: attributes,
        force: force,
        skip_tests: true # Migrations don't need tests
      )

      generator.generate!

      log.success("Migration #{name} generated successfully!")
      show_migration_next_steps(name)
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

    private def extract_events(args : Array(String)) : Array(String)
      events = args.select { |arg| arg.starts_with?("event:") }.map { |arg| arg.split(":", 2)[1] }
      events
    end

    private def has_websocket_flag?(args : Array(String)) : Bool
      args.includes?("--websocket") || args.includes?("--ws") || args.includes?("realtime")
    end

    private def extract_validation_type(args : Array(String)) : String
      type_arg = args.find { |arg| arg.starts_with?("type:") }
      if type_arg
        type_arg.split(":", 2)[1]
      else
        # Try to detect type from common arguments
        if args.any? { |arg| arg.includes?("email") }
          "email"
        elsif args.any? { |arg| arg.includes?("phone") }
          "phone"
        elsif args.any? { |arg| arg.includes?("url") }
          "url"
        elsif args.any? { |arg| arg.includes?("pattern") || arg.includes?("regex") }
          "regex"
        elsif args.any? { |arg| arg.includes?("min") || arg.includes?("max") }
          "range"
        else
          "custom"
        end
      end
    end

    private def extract_model_name(args : Array(String)) : String
      model_arg = args.find { |arg| arg.starts_with?("model:") }
      if model_arg
        model_arg.split(":", 2)[1]
      else
        ""
      end
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
      puts "  1. Run 'azu generate migration create_#{name.downcase}_table' to create the migration"
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

    private def show_component_next_steps(name : String)
      puts
      puts "📋 Next Steps:".colorize(:yellow).bold
      puts "  1. Customize the component content in src/components/#{name.downcase}_component.cr"
      puts "  2. Add event handlers for user interactions"
      puts "  3. Include the component in your endpoints or pages:"
      puts "     component = #{name.capitalize}Component.new"
      puts "     component.render"
      puts
      puts "  4. For real-time features, configure WebSocket routes:"
      puts "     config.router.ws \"/live\", YourWebSocketHandler"
      puts
      puts "  5. Test your component in spec/components/#{name.downcase}_component_spec.cr"
      puts
      puts "💡 Real-time Examples:".colorize(:blue).bold
      puts "  - update_element(\"id\", \"new content\")"
      puts "  - append_element(\"container\", \"<div>new item</div>\")"
      puts "  - broadcast_update({type: \"update\", data: \"value\"})"
      puts
      puts "📚 Learn more: https://azutopia.gitbook.io/azu/real-time/components".colorize(:cyan)
    end

    private def show_validator_next_steps(name : String, validation_type : String)
      puts
      puts "📋 Next Steps:".colorize(:yellow).bold
      puts "  1. Customize validation logic in src/validators/#{name.downcase}_validator.cr"
      puts "  2. Use in your CQL models:"
      puts "     class YourModel < CQL::Model"
      puts "       validate :field_name, with: #{name.capitalize}Validator"
      puts "     end"
      puts
      puts "  3. Use in request contracts:"
      puts "     struct YourContract"
      puts "       include Request"
      puts "       validate field_name, custom: #{name.capitalize}Validator"
      puts "     end"
      puts
      puts "  4. Test your validator in spec/validators/#{name.downcase}_validator_spec.cr"
      puts
      puts "💡 Validation Examples (#{validation_type}):".colorize(:blue).bold
      case validation_type.downcase
      when "email"
        puts "  - Validates email format: user@example.com"
        puts "  - Rejects invalid formats: invalid-email, @domain.com"
      when "phone"
        puts "  - Validates phone formats: (555) 123-4567, 555-123-4567"
        puts "  - Supports multiple formats including international"
      when "url"
        puts "  - Validates URL format: https://example.com"
        puts "  - Supports HTTP and HTTPS protocols"
      when "regex"
        puts "  - Custom pattern matching with configurable regex"
        puts "  - Flexible validation for specific formats"
      when "range"
        puts "  - Numeric range validation with min/max values"
        puts "  - Works with integers and floating-point numbers"
      else
        puts "  - Custom business logic validation"
        puts "  - Implement your specific validation rules"
      end
      puts
      puts "📚 Learn more: https://github.com/azutoolkit/cql/blob/master/src/active_record/validations.cr".colorize(:cyan)
    end

    private def show_migration_next_steps(name : String)
      puts
      puts "📋 Next Steps:".colorize(:yellow).bold
      puts "  1. Edit the generated migration file to define your schema changes"
      puts "  2. Run 'azu db:migrate' to apply the migration"
      puts "  3. Run 'azu db:rollback' if you need to undo the changes"
      puts "  4. Use 'azu db:status' to check migration status"
      puts
      puts "💡 Migration Examples:".colorize(:blue).bold
      puts "  azu generate migration create_users_table"
      puts "  azu generate migration add_email_to_users email:string"
      puts "  azu generate migration remove_name_from_users"
    end

    private def show_scaffold_next_steps(name : String)
      puts
      puts "📋 Next Steps:".colorize(:yellow).bold
      puts "  1. Run 'azu generate migration create_#{name.downcase}_table' to create the migration"
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
      puts "  --websocket         Enable WebSocket features (for components)"
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
      puts
      puts "Examples:"
      puts "  azu generate endpoint users"
      puts "  azu generate model User name:string email:string"
      puts "  azu generate component Counter count:integer --websocket"
      puts "  azu generate component ChatBox event:send event:typing --websocket"
      puts "  azu generate validator EmailValidator type:email"
      puts "  azu generate validator PhoneValidator type:phone"
      puts "  azu generate validator RangeValidator type:range min:1 max:100"
      puts "  azu generate validator CustomValidator pattern:\"\\A[A-Z]{2,3}\\z\""
      puts "  azu generate migration create_users_table"
      puts "  azu generate migration add_email_to_users email:string"
      puts "  azu generate service UserRegistration"
      puts "  azu generate middleware Authentication"
      puts "  azu generate scaffold Post title:string content:text"
    end
  end
end
