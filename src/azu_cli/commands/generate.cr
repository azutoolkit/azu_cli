require "../command"
require "../generators/endpoint"
require "../generators/model"
require "../generators/service"
require "../generators/middleware"
require "../generators/contract"
require "../generators/page"
require "../generators/migration"
require "../generators/component"
require "../generators/validator"
require "../generators/channel"
require "../generators/request"
require "../generators/response"
require "../generators/handler"

module AzuCLI::Commands
  # Generate command - creates various Azu components using generators
  class Generate < Command
    command_name "generate"
    description "Generate Azu components (endpoints, models, services, etc.)"
    usage "generate <generator_type> <name> [options]"

    GENERATORS = {
      "endpoint"   => "Generate HTTP endpoints with contracts and pages",
      "model"      => "Generate CQL models with validations and associations",
      "contract"   => "Generate request validation contracts",
      "page"       => "Generate template-based page components",
      "component"  => "Generate interactive live components",
      "service"    => "Generate business logic service classes",
      "middleware" => "Generate HTTP middleware handlers",
      "migration"  => "Generate database migration files",
      "validator"  => "Generate custom validation classes",
      "channel"    => "Generate WebSocket channels for real-time communication",
      "request"    => "Generate request objects with validation",
      "response"   => "Generate response objects with template rendering",
      "handler"    => "Generate HTTP handlers for request processing",
      "scaffold"   => "Generate complete resource with all components",
    }

    GENERATOR_ALIASES = {
      "e"          => "endpoint",
      "m"          => "model",
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
      "scaffold"   => "scaffold",
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
      when "channel"
        generate_channel(component_name, additional_args, force, skip_tests)
      when "request"
        generate_request(component_name, additional_args, force, skip_tests)
      when "response"
        generate_response(component_name, additional_args, force, skip_tests)
      when "handler"
        generate_handler(component_name, additional_args, force, skip_tests)
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
      puts "  azu generate channel ChatChannel event:message event:typing --auth"
      puts "  azu generate request UserRequest name:string email:string --file-upload"
      puts "  azu generate response UserResponse user:User format:json"
      puts "  azu generate handler AuthHandler type:auth --auth"
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

      # Parse validator-specific arguments
      validation_type = extract_validation_type(args)
      model_name = extract_model_name(args) || "User"
      pattern = extract_pattern(args)
      range_options = extract_range_options(args)

      generator = Generator::Validator.new(
        name: name,
        project_name: get_project_name,
        validation_type: validation_type,
        model_name: model_name,
        pattern: pattern,
        range_options: range_options,
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

    private def generate_channel(name : String, args : Array(String), force : Bool, skip_tests : Bool)
      log.info("Generating channel: #{name}")

      events = extract_events(args)
      with_auth = has_auth_flag?(args)

      generator = Generator::Channel.new(
        name: name,
        project_name: get_project_name,
        events: events,
        with_auth: with_auth,
        force: force,
        skip_tests: skip_tests
      )

      generator.generate!

      log.success("Channel #{name} generated successfully!")
      show_channel_next_steps(name)
    end

    private def generate_request(name : String, args : Array(String), force : Bool, skip_tests : Bool)
      log.info("Generating request: #{name}")

      attributes = parse_attributes(args)
      validations = parse_validations(args)
      with_file_upload = has_file_upload_flag?(args)

      generator = Generator::Request.new(
        name: name,
        project_name: get_project_name,
        attributes: attributes,
        validations: validations,
        with_file_upload: with_file_upload,
        force: force,
        skip_tests: skip_tests
      )

      generator.generate!

      log.success("Request #{name} generated successfully!")
      show_request_next_steps(name)
    end

    private def generate_response(name : String, args : Array(String), force : Bool, skip_tests : Bool)
      log.info("Generating response: #{name}")

      attributes = parse_attributes(args)
      template_name = extract_template_name(args)
      response_format = extract_response_format(args)

      generator = Generator::Response.new(
        name: name,
        project_name: get_project_name,
        attributes: attributes,
        template_name: template_name,
        response_format: response_format,
        force: force,
        skip_tests: skip_tests
      )

      generator.generate!

      log.success("Response #{name} generated successfully!")
      show_response_next_steps(name)
    end

    private def generate_handler(name : String, args : Array(String), force : Bool, skip_tests : Bool)
      log.info("Generating handler: #{name}")

      handler_type = extract_handler_type(args)
      with_auth = has_auth_flag?(args)

      generator = Generator::Handler.new(
        name: name,
        project_name: get_project_name,
        handler_type: handler_type,
        with_auth: with_auth,
        force: force,
        skip_tests: skip_tests
      )

      generator.generate!

      log.success("Handler #{name} generated successfully!")
      show_handler_next_steps(name, handler_type)
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

    private def has_auth_flag?(args : Array(String)) : Bool
      args.includes?("--auth") || args.includes?("--authentication")
    end

    private def has_file_upload_flag?(args : Array(String)) : Bool
      args.includes?("--file-upload") || args.includes?("--upload") || args.includes?("--multipart")
    end

    private def extract_template_name(args : Array(String)) : String
      template_arg = args.find { |arg| arg.starts_with?("template:") }
      template_arg ? template_arg.split(":", 2)[1] : ""
    end

    private def extract_response_format(args : Array(String)) : String
      format_arg = args.find { |arg| arg.starts_with?("format:") }
      format_arg ? format_arg.split(":", 2)[1] : "html"
    end

    private def extract_handler_type(args : Array(String)) : String
      type_arg = args.find { |arg| arg.starts_with?("type:") }
      type_arg ? type_arg.split(":", 2)[1] : "custom"
    end

    private def parse_validations(args : Array(String)) : Hash(String, String)
      validations = {} of String => String

      args.each do |arg|
        if arg.starts_with?("validation:")
          parts = arg.split(":", 3)
          if parts.size >= 3
            field = parts[1]
            rule = parts[2]
            validations[field] = rule
          end
        end
      end

      validations
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

    private def extract_model_name(args : Array(String)) : String?
      model_arg = args.find { |arg| arg.starts_with?("model:") }
      model_arg ? model_arg.split(":", 2)[1] : nil
    end

    private def extract_pattern(args : Array(String)) : String
      pattern_arg = args.find { |arg| arg.starts_with?("pattern:") }
      pattern_arg ? pattern_arg.split(":", 2)[1] : ""
    end

    private def extract_range_options(args : Array(String)) : Hash(String, String)
      options = {} of String => String

      min_arg = args.find { |arg| arg.starts_with?("min:") }
      max_arg = args.find { |arg| arg.starts_with?("max:") }

      options["min"] = min_arg.split(":", 2)[1] if min_arg
      options["max"] = max_arg.split(":", 2)[1] if max_arg

      options
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
      puts "📚 Learn more: https://azutoolkit.github.io/azu/real-time/components".colorize(:cyan)
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

    private def show_channel_next_steps(name : String)
      puts
      puts "📡 Next Steps:".colorize(:yellow).bold
      puts "  1. Customize message handling in src/channels/#{name.downcase}_channel.cr"
      puts "  2. Register your channel in server configuration:"
      puts "     MyApp.start ["
      puts "       # ... other handlers"
      puts "       Azu::Handler::WebSocket.new(\"/#{name.downcase}\", #{name.capitalize}Channel)"
      puts "     ]"
      puts
      puts "  3. Connect from client JavaScript:"
      puts "     const socket = new WebSocket('ws://localhost:4000/#{name.downcase}');"
      puts "     socket.send(JSON.stringify({type: 'action', payload: {data: 'hello'}}));"
      puts
      puts "  4. Test your channel in spec/channels/#{name.downcase}_channel_spec.cr"
      puts
      puts "💡 WebSocket Features:".colorize(:blue).bold
      puts "  - Real-time bidirectional communication"
      puts "  - JSON message handling"
      puts "  - Broadcasting to multiple clients"
      puts "  - Connection lifecycle management"
      puts
      puts "📚 Learn more: https://azutoolkit.github.io/azu/real-time/channels".colorize(:cyan)
    end

    private def show_request_next_steps(name : String)
      puts
      puts "📝 Next Steps:".colorize(:yellow).bold
      puts "  1. Customize validation in src/requests/#{name.downcase}_request.cr"
      puts "  2. Use in your endpoints:"
      puts "     struct #{name.capitalize}Endpoint"
      puts "       include Azu::Endpoint(#{name.capitalize}Request, #{name.capitalize}Response)"
      puts "       def call"
      puts "         request = #{name.capitalize}Request.new(params)"
      puts "         return error_response unless request.valid?"
      puts "       end"
      puts "     end"
      puts
      puts "  3. Handle validation errors:"
      puts "     errors = request.errors"
      puts "     return render_errors(errors) unless errors.empty?"
      puts
      puts "  4. Test your request in spec/requests/#{name.downcase}_request_spec.cr"
      puts
      puts "💡 Request Features:".colorize(:blue).bold
      puts "  - Type-safe parameter validation"
      puts "  - File upload support"
      puts "  - Custom validation rules"
      puts "  - Error message localization"
      puts
      puts "📚 Learn more: https://azutoolkit.github.io/azu/validation/requests".colorize(:cyan)
    end

    private def show_response_next_steps(name : String)
      puts
      puts "📤 Next Steps:".colorize(:yellow).bold
      puts "  1. Customize response logic in src/responses/#{name.downcase}_response.cr"
      puts "  2. Use in your endpoints:"
      puts "     struct #{name.capitalize}Endpoint"
      puts "       include Azu::Endpoint(#{name.capitalize}Request, #{name.capitalize}Response)"
      puts "       def call"
      puts "         response = #{name.capitalize}Response.new(data: result)"
      puts "         response.render"
      puts "       end"
      puts "     end"
      puts
      puts "  3. Template customization:"
      puts "     - Edit public/templates/#{name.downcase}/#{name.downcase}.jinja"
      puts "     - Add custom variables and logic"
      puts
      puts "  4. Test your response in spec/responses/#{name.downcase}_response_spec.cr"
      puts
      puts "💡 Response Features:".colorize(:blue).bold
      puts "  - Multiple format support (JSON, HTML, XML)"
      puts "  - Template rendering with Jinja"
      puts "  - Automatic data serialization"
      puts "  - HTTP status and header management"
      puts
      puts "📚 Learn more: https://azutoolkit.github.io/azu/responses".colorize(:cyan)
    end

    private def show_handler_next_steps(name : String, handler_type : String)
      puts
      puts "🛠️  Next Steps:".colorize(:yellow).bold
      puts "  1. Customize handler logic in src/handlers/#{name.downcase}_handler.cr"
      puts "  2. Add handler to your application pipeline:"
      puts "     MyApp.start ["
      puts "       #{name.capitalize}Handler.new,"
      puts "       # ... other handlers"
      puts "     ]"
      puts
      puts "  3. Handler type: #{handler_type.capitalize}"
      case handler_type.downcase
      when "auth", "authentication"
        puts "     - Implement token validation logic"
        puts "     - Configure user lookup from tokens"
      when "cors"
        puts "     - Configure allowed origins for production"
        puts "     - Customize CORS headers as needed"
      when "rate_limit", "throttle"
        puts "     - Adjust rate limit thresholds"
        puts "     - Consider using Redis for distributed rate limiting"
      when "logging"
        puts "     - Configure log output destinations"
        puts "     - Add custom request/response logging"
      when "security"
        puts "     - Customize Content Security Policy"
        puts "     - Add application-specific security validations"
      else
        puts "     - Implement before_request and after_response logic"
        puts "     - Add custom processing as needed"
      end
      puts
      puts "  4. Test your handler in spec/handlers/#{name.downcase}_handler_spec.cr"
      puts
      puts "💡 Handler Features:".colorize(:blue).bold
      puts "  - HTTP::Handler implementation"
      puts "  - Chain-of-responsibility pattern"
      puts "  - Request/response lifecycle hooks"
      puts
      puts "📚 Learn more: https://azutoolkit.github.io/azu/handlers".colorize(:cyan)
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
      puts "  --auth              Enable authentication features"
      puts "  --file-upload       Enable file upload support (for requests)"
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
      puts "  azu generate channel ChatChannel event:message event:typing --auth"
      puts "  azu generate channel NotificationChannel event:alert event:broadcast"
      puts "  azu generate request UserRequest name:string email:string --file-upload"
      puts "  azu generate request SearchRequest query:string page:integer format:json"
      puts "  azu generate response UserResponse user:User format:json"
      puts "  azu generate response DataResponse data:Hash template:custom.jinja format:html"
      puts "  azu generate handler AuthHandler type:auth --auth"
      puts "  azu generate handler CorsHandler type:cors"
      puts "  azu generate handler RateLimitHandler type:rate_limit"
      puts "  azu generate handler SecurityHandler type:security"
      puts "  azu generate scaffold Post title:string content:text"
    end
  end
end
