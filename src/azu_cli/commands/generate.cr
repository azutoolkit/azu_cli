require "./base"
require "option_parser"
require "../logger"
require "../generators/**"
require "../config/**"

module AzuCLI
  module Commands
    # Generate command for creating code from templates
    class Generate < Base
      property generator_type : String = ""
      property generator_name : String = ""
      property attributes : Hash(String, String) = {} of String => String
      property actions : Array(String) = [] of String
      property options : Hash(String, String) = {} of String => String
      property force : Bool = false
      property api_only : Bool = false
      property web_only : Bool = false
      property skip_tests : Bool = false
      property skip_components : Array(String) = [] of String

      def initialize
        super("generate", "Generate code from templates")
      end

      def execute : Result
        parse_arguments

        # Detect project type and auto-set API mode
        detector = ProjectDetector.new
        if detector.api_project? && !@web_only
          @api_only = true
          Logger.debug("API project detected, using API-only mode")
        end

        # Some generators don't require a name (like auth)
        generators_without_name = ["auth", "authentication"]

        @generator_type = get_arg(0) || ""

        if generators_without_name.includes?(@generator_type.downcase)
          @generator_name = "Auth"  # Default name for auth
        else
          # Validate required arguments for other generators
          unless validate_required_args(2)
            return error("Usage: azu generate <type> <name> [attributes] [options]")
          end
          @generator_name = get_arg(1).not_nil!
        end

        # Parse attributes from remaining arguments
        parse_attributes

        # Show what we're generating
        Logger.info("Generating #{@generator_type}: #{@generator_name}")

        # Generate based on type
        case @generator_type.downcase
        when "model"
          generate_model
        when "endpoint"
          generate_endpoint
        when "service"
          generate_service
        when "contract", "request"
          generate_request
        when "page"
          generate_page
        when "job"
          generate_job
        when "joobq"
          generate_joobq_setup
        when "middleware"
          generate_middleware
        when "migration"
          generate_migration
        when "component"
          generate_component
        when "validator"
          generate_validator
        when "response"
          generate_response
        when "template"
          generate_template
        when "scaffold"
          generate_scaffold
        when "mailer"
          generate_mailer
        when "channel"
          generate_channel
        when "auth", "authentication"
          generate_auth
        when "api_resource", "api-resource"
          generate_api_resource
        else
          error("Unknown generator type: #{@generator_type}")
        end
      end

      # Check if current project is API-only
      private def api_project? : Bool
        ProjectDetector.new.api_project?
      end

      private def parse_arguments
        OptionParser.parse(get_args) do |parser|
          parser.banner = "Usage: azu generate <type> <name> [attributes] [options]"

          parser.on("--force", "Overwrite existing files") { @force = true }
          parser.on("--api-only", "Generate API-only components") { @api_only = true }
          parser.on("--web-only", "Generate web-only components") { @web_only = true }
          parser.on("--skip-tests", "Skip test file generation") { @skip_tests = true }
          parser.on("--skip COMPONENTS", "Skip specific components (comma-separated): model,endpoint,request,response,template,migration,page") do |components|
            @skip_components = components.split(",").map(&.strip.downcase)
          end
          parser.on("--strategy STRATEGY", "Authentication strategy (jwt, session, oauth)") do |strategy|
            @options["strategy"] = strategy
          end
          parser.on("--backend BACKEND", "Backend type (redis, memory, database)") do |backend|
            @options["backend"] = backend
          end
          parser.on("--type TYPE", "Generator-specific type") do |type|
            @options["type"] = type
          end
          parser.on("--record RECORD", "Record type for validators") do |record|
            @options["record"] = record
          end
          parser.on("--help", "Show help") {
            show_help
            exit(0)
          }
        end
      end

      private def parse_attributes
        # Skip the first two arguments (type and name)
        attribute_args = get_args[2..-1]? || [] of String

        attribute_args.each do |arg|
          # Skip option flags
          next if arg.starts_with?("--")

          if arg.includes?(":")
            # Parse attribute:type format
            parts = arg.split(":", 2)
            @attributes[parts[0]] = parts[1]
          else
            # Treat as action for endpoints/services
            @actions << arg unless @actions.includes?(arg)
          end
        end

        # Set default actions for endpoints if none provided
        if @generator_type == "endpoint" && @actions.empty?
          @actions = ["index", "show", "create", "update", "destroy"]
        end
      end

      private def generate_model : Result
        Logger.info("Generating model with attributes: #{@attributes}")

        generator = AzuCLI::Generate::Model.new(
          name: @generator_name,
          attributes: @attributes,
          generate_migration: !@skip_tests
        )

        render_generator(generator, AzuCLI::Generate::Model::OUTPUT_DIR)
        success("Generated model #{@generator_name} successfully")
      end

      private def generate_endpoint : Result
        Logger.info("Generating endpoint with actions: #{@actions}")

        endpoint_type = @api_only ? "api" : (@web_only ? "web" : "api")

        generator = AzuCLI::Generate::Endpoint.new(
          name: @generator_name,
          actions: @actions,
          endpoint_type: endpoint_type
        )

        # Endpoint generator has custom render method, but use proper output directory
        output_dir = AzuCLI::Generate::Endpoint::OUTPUT_DIR
        Dir.mkdir_p(output_dir) unless Dir.exists?(output_dir)
        generator.render(output_dir)
        success("Generated endpoint #{@generator_name} successfully")
      end

      private def generate_service : Result
        Logger.info("Generating service")

        generator = AzuCLI::Generate::Service.new(
          name: @generator_name,
          methods: @attributes
        )

        render_generator(generator, AzuCLI::Generate::Service::OUTPUT_DIR)
        success("Generated service #{@generator_name} successfully")
      end

      private def generate_request : Result
        Logger.info("Generating request")

        # Use the proper request generator (aligns with Azu::Request)
        action = @actions.first? || "index"

        generator = AzuCLI::Generate::Request.new(
          project: project_name,
          resource: @generator_name,
          action: action,
          attributes: @attributes
        )

        render_generator(generator, AzuCLI::Generate::Request::OUTPUT_DIR)
        success("Generated request #{@generator_name} successfully")
      end

      def project_name
        # get name from shard.yml
        shard_yml = YAML.parse(File.read("./shard.yml"))
        shard_yml["name"].as_s
      end

      private def generate_page : Result
        Logger.info("Generating page with template")

        action = @actions.first? || "index"
        project_type = @api_only ? "api" : "web"
        generator = AzuCLI::Generate::Page.new(
          name: @generator_name,
          fields: @attributes,
          action: action,
          project_type: project_type
        )

        output_dir = AzuCLI::Generate::Page.output_dir_for_type(project_type)
        render_generator(generator, output_dir)
        success("Generated page #{@generator_name} successfully")
      end

      private def generate_job : Result
        Logger.info("Generating job")

        generator = AzuCLI::Generate::Job.new(
          name: @generator_name,
          parameters: @attributes
        )

        render_generator(generator, AzuCLI::Generate::Job::OUTPUT_DIR)
        success("Generated job #{@generator_name} successfully")
      end

      private def generate_joobq_setup : Result
        Logger.info("Setting up JoobQ integration")

        # Get project name from current directory or options
        project_name = @options["project"]? || Dir.current.split("/").last
        redis_url = @options["redis"]? || "redis://localhost:6379"
        create_example = !@options.has_key?("no-example")

        generator = AzuCLI::Generate::JoobQ.new(
          project_name: project_name,
          redis_url: redis_url,
          create_example_job: create_example
        )

        # Create necessary directories
        Dir.mkdir_p("config") unless Dir.exists?("config")
        Dir.mkdir_p("src/initializers") unless Dir.exists?("src/initializers")
        Dir.mkdir_p("src/jobs") unless Dir.exists?("src/jobs")

        # Render the generator files
        generator.render(".")

        Logger.success("✓ JoobQ configuration created: config/joobq.development.yml")
        Logger.success("✓ JoobQ initializer created: src/initializers/joobq.cr")
        if create_example
          Logger.success("✓ Example job created: src/jobs/example_job.cr")
        end

        Logger.info("")
        Logger.info("Next steps:")
        Logger.info("1. Add joobq and redis to your shard.yml dependencies:")
        Logger.info("   dependencies:")
        Logger.info("     joobq:")
        Logger.info("       github: azutoolkit/joobq")
        Logger.info("     redis:")
        Logger.info("       github: stefanwille/crystal-redis")
        Logger.info("")
        Logger.info("2. Require the initializer in your main app file:")
        Logger.info("   require \"./initializers/joobq\"")
        Logger.info("")
        Logger.info("3. Start a worker process:")
        Logger.info("   azu jobs:worker")
        Logger.info("")
        Logger.info("4. Create jobs with:")
        Logger.info("   azu generate job YourJobName param:type")

        success("JoobQ setup completed successfully")
      end

      private def generate_middleware : Result
        Logger.info("Generating middleware")

        middleware_type = @options["type"]? || "authentication"

        generator = AzuCLI::Generate::Middleware.new(
          name: @generator_name,
          middleware_type: middleware_type
        )

        render_generator(generator, AzuCLI::Generate::Middleware::OUTPUT_DIR)
        success("Generated middleware #{@generator_name} successfully")
      end

      private def generate_migration : Result
        Logger.info("Generating migration")

        generator = AzuCLI::Generate::Migration.new(
          name: @generator_name,
          attributes: @attributes
        )

        render_generator(generator, AzuCLI::Generate::Migration::OUTPUT_DIR)
        success("Generated migration #{@generator_name} successfully")
      end

      private def generate_component : Result
        Logger.info("Generating component")

        generator = AzuCLI::Generate::Component.new(
          name: @generator_name,
          properties: @attributes
        )

        render_generator(generator, AzuCLI::Generate::Component::OUTPUT_DIR)
        success("Generated component #{@generator_name} successfully")
      end

      private def generate_validator : Result
        Logger.info("Generating validator")

        record_type = @options["record"]? || "User"

        generator = AzuCLI::Generate::Validator.new(
          name: @generator_name,
          record_type: record_type
        )

        render_generator(generator, AzuCLI::Generate::Validator::OUTPUT_DIR)
        success("Generated validator #{@generator_name} successfully")
      end



      private def generate_response : Result
        Logger.info("Generating response")

        from_type = @options["from"]?
        project_type = "api"  # Always generate API-style responses for the response command

        generator = AzuCLI::Generate::Page.new(
          name: @generator_name,
          fields: @attributes,
          action: "index",
          project_type: project_type,
          from_type: from_type
        )

        output_dir = AzuCLI::Generate::Page.output_dir_for_type(project_type)
        render_generator(generator, output_dir)
        success("Generated response #{@generator_name} successfully")
      end

      private def generate_template : Result
        Logger.info("Generating template")

        action = @actions.first? || "index"

        generator = AzuCLI::Generate::Template.new(
          name: @generator_name,
          fields: @attributes,
          action: action
        )

        render_generator(generator, AzuCLI::Generate::Template::OUTPUT_DIR)
        success("Generated template #{@generator_name} successfully")
      end

      private def generate_mailer : Result
        Logger.info("Generating mailer")

        methods = @actions.empty? ? ["welcome"] : @actions

        generator = AzuCLI::Generate::Mailer.new(
          name: @generator_name,
          methods: methods,
          async: !@skip_components.includes?("job")
        )

        render_generator(generator, AzuCLI::Generate::Mailer::OUTPUT_DIR)
        success("Generated mailer #{@generator_name} successfully")
      end

      private def generate_channel : Result
        Logger.info("Generating WebSocket channel")

        actions = @actions.empty? ? ["subscribed", "unsubscribed", "receive"] : @actions

        generator = AzuCLI::Generate::Channel.new(
          name: @generator_name,
          actions: actions
        )

        render_generator(generator, AzuCLI::Generate::Channel::OUTPUT_DIR)
        success("Generated channel #{@generator_name} successfully")
      end

      private def generate_auth : Result
        Logger.info("Generating authentication system")

        strategy = @options["strategy"]? || "jwt"
        proj_name = project_name

        generator = AzuCLI::Generate::Auth.new(
          project: proj_name,
          strategy: strategy
        )

        Logger.info("Strategy: #{strategy}")
        render_generator(generator, AzuCLI::Generate::Auth::OUTPUT_DIR)

        Logger.info("✓ Authentication system generated")
        Logger.info("")
        Logger.info("Next steps:")
        Logger.info("1. Run 'azu db:migrate' to create users table")
        Logger.info("2. Set JWT_SECRET environment variable (if using JWT)")
        Logger.info("3. Configure your application to use the auth endpoints")

        success("Generated authentication system successfully")
      end

      private def generate_api_resource : Result
        Logger.info("Generating API resource (complete REST API)")

        # Force API-only mode
        @api_only = true
        @skip_components << "template" unless @skip_components.includes?("template")
        @skip_components << "page" unless @skip_components.includes?("page")

        # Use scaffold generation with API mode
        generate_scaffold
      end

      private def generate_scaffold : Result
        Logger.info("Generating scaffold (complete CRUD)")

        components_generated = [] of String
        crud_actions = ["index", "show", "new", "create", "edit", "update", "destroy"]

        # Generate Model
        unless should_skip_component?("model")
          Logger.info("🔨 Generating model...")
          model_generator = AzuCLI::Generate::Model.new(
            name: @generator_name,
            attributes: @attributes,
            generate_migration: !should_skip_component?("migration") # Only generate migration with model if migration is not being skipped
          )
          render_generator(model_generator, AzuCLI::Generate::Model::OUTPUT_DIR)
          components_generated << "model"
        end

        # Generate separate Migration if not skipped and not generated with model
        unless should_skip_component?("migration")
          unless should_skip_component?("model") # If model was generated, migration might already be created
            Logger.info("🔨 Generating migration...")
            migration_generator = AzuCLI::Generate::Migration.new(
              name: "create_#{@generator_name.downcase}s",
              attributes: @attributes
            )
            render_generator(migration_generator, AzuCLI::Generate::Migration::OUTPUT_DIR)
            components_generated << "migration"
          end
        end

        # Generate Endpoints
        unless should_skip_component?("endpoint")
          Logger.info("🔨 Generating endpoints...")
          endpoint_type = @api_only ? "api" : (@web_only ? "web" : "web")
          endpoint_generator = AzuCLI::Generate::Endpoint.new(
            name: @generator_name,
            actions: crud_actions,
            endpoint_type: endpoint_type,
            scaffold: true
          )
          output_dir = AzuCLI::Generate::Endpoint::OUTPUT_DIR
          Dir.mkdir_p(output_dir) unless Dir.exists?(output_dir)
          endpoint_generator.render(output_dir)
          components_generated << "endpoint"
        end

        # Generate Requests (both API and Web) - aligns with Azu::Request
        unless should_skip_component?("request") || should_skip_component?("contract")
          Logger.info("🔨 Generating requests...")
          # Get project name from config or use default
          proj_name = project_name

          # Generate requests for each CRUD action
          crud_actions.each do |action|
            request_generator = AzuCLI::Generate::Request.new(
              project: proj_name,
              resource: @generator_name,
              action: action,
              attributes: @attributes
            )
            render_generator(request_generator, AzuCLI::Generate::Request::OUTPUT_DIR)
          end
          components_generated << "request"
        end

        # Generate Responses
        unless should_skip_component?("response")
          Logger.info("🔨 Generating responses...")
          project_type = @api_only ? "api" : "web"
          output_dir = AzuCLI::Generate::Page.output_dir_for_type(project_type)

          # Generate responses for each CRUD action
          crud_actions.each do |action|
            response_generator = AzuCLI::Generate::Page.new(@generator_name, @attributes, action, project_type)
            render_generator(response_generator, output_dir)
          end
          components_generated << "response"
        end



        # Generate Pages (Web mode)
        unless should_skip_component?("page") || @api_only
          Logger.info("🔨 Generating pages...")
          output_dir = AzuCLI::Generate::Page.output_dir_for_type("web")
          ["index", "show", "new", "edit"].each do |action|
            page_generator = AzuCLI::Generate::Page.new(@generator_name, @attributes, action, "web")
            render_generator(page_generator, output_dir)
          end
          components_generated << "page"
        end

        # Generate Templates (Web mode)
        unless should_skip_component?("template") || @api_only
          Logger.info("🔨 Generating templates...")
          ["index", "show", "new", "edit"].each do |action|
            template_generator = AzuCLI::Generate::Template.new(@generator_name, @attributes, action)
            render_generator(template_generator, AzuCLI::Generate::Template::OUTPUT_DIR)
          end
          components_generated << "template"
        end

        Logger.info("✅ Scaffold generation completed")
        Logger.info("📦 Generated components: #{components_generated.join(", ")}")

        if @skip_components.any?
          Logger.info("⏭️  Skipped components: #{@skip_components.join(", ")}")
        end

        success("Generated scaffold #{@generator_name} successfully")
      end

      # Helper method to check if a component should be skipped
      private def should_skip_component?(component : String) : Bool
        @skip_components.includes?(component.downcase)
      end

      # Render a generator to its appropriate output directory
      private def render_generator(generator : Teeplate::FileTree, output_dir : String)
        begin
          # Ensure the output directory exists
          Dir.mkdir_p(output_dir) unless Dir.exists?(output_dir)

          # Determine the actual output path
          target_path = File.expand_path(output_dir, Dir.current)

          Logger.info("Generating files in: #{target_path}")

          # Render the generator
          generator.render(target_path, force: @force, interactive: false, list: false, color: true)

          Logger.info("✅ Generated #{@generator_type} successfully")
        rescue ex : Exception
          Logger.error("Failed to generate #{@generator_type}: #{ex.message}")
          raise ex
        end
      end

      def show_help
        puts "Usage: azu generate <type> <name> [attributes] [options]"
        puts
        puts "Generate code for your Azu project using built-in generators."
        puts
        puts "Generator Types:"
        puts
        puts "  model <name> [attr:type]"
        puts "    Generate a CQL model with attributes and optional migration"
        puts "    Example: azu generate model User name:string email:string age:int32"
        puts
        puts "  endpoint <name> [actions]"
        puts "    Generate RESTful endpoints with specified actions"
        puts "    Example: azu generate endpoint Users index show create update destroy"
        puts
        puts "  service <name> [method:return_type]"
        puts "    Generate a service class for business logic"
        puts "    Example: azu generate service UserService create:User update:User"
        puts
        puts "  request <name> [attr:type]"
        puts "    Generate a request class for request validation (aligns with Azu::Request)"
        puts "    Example: azu generate request UserRequest name:string email:string"
        puts
        puts "  contract <name> [attr:type]"
        puts "    Alias for 'request' (deprecated, use 'request' instead)"
        puts
        puts "  page <name> [attr:type]"
        puts "    Generate a page response class (Web) or JSON response class (API)"
        puts "    Example: azu generate page UserProfile name:string email:string"
        puts
        puts "  job <name> [param:type]"
        puts "    Generate a background job class with parameters"
        puts "    Example: azu generate job EmailNotification user_id:int32 template:string"
        puts
        puts "  middleware <name> [type]"
        puts "    Generate middleware for request/response processing"
        puts "    Example: azu generate middleware Authentication --type auth"
        puts
        puts "  migration <name> [attr:type]"
        puts "    Generate a database migration file"
        puts "    Example: azu generate migration AddAgeToUsers age:int32"
        puts
        puts "  component <name> [attr:type]"
        puts "    Generate a reusable component class"
        puts "    Example: azu generate component UserCard name:string email:string"
        puts
        puts "  validator <name> [type]"
        puts "    Generate a custom validator class"
        puts "    Example: azu generate validator EmailValidator --record User"
        puts

        puts "  response <name> [attr:type]"
        puts "    Generate a response class for API endpoints"
        puts "    Example: azu generate response UserResponse name:string email:string"
        puts
        puts "  template <name> [attr:type]"
        puts "    Generate a Jinja2 template file"
        puts "    Example: azu generate template UserProfile name:string email:string"
        puts
        puts "  scaffold <name> [attr:type]"
        puts "    Generate a complete CRUD scaffold with all components"
        puts "    Example: azu generate scaffold Post title:string content:text published:bool"
        puts
        puts "  mailer <name> [methods]"
        puts "    Generate a mailer class for sending emails"
        puts "    Example: azu generate mailer UserMailer welcome password_reset"
        puts
        puts "  channel <name> [actions]"
        puts "    Generate a WebSocket channel for real-time communication"
        puts "    Example: azu generate channel ChatChannel subscribed receive"
        puts
        puts "  auth [--strategy jwt|session|oauth]"
        puts "    Generate complete authentication system"
        puts "    Example: azu generate auth --strategy jwt"
        puts
        puts "  api_resource <name> [attr:type]"
        puts "    Generate complete REST API resource (API-only)"
        puts "    Example: azu generate api_resource Post title:string content:text"
        puts
        puts "Options:"
        puts "  --force                    Overwrite existing files without prompting"
        puts "  --skip-tests               Skip generating test files"
        puts "  --api-only                 Generate API-only components (JSON responses)"
        puts "  --web-only                 Generate web-only components (HTML pages)"
        puts "  --skip COMPONENTS          Skip specific components (comma-separated)"
        puts "                             Available components: model,endpoint,request,response,template,migration,page"
        puts "  --help                     Show this help message"
        puts
        puts "Attribute Format:"
        puts "  Attributes follow the pattern: name:type"
        puts "  Supported types: string, int32, int64, float32, float64, bool, text, time"
        puts "  Example: name:string email:string age:int32 published:bool"
        puts
        puts "Scaffold Generator:"
        puts "  The scaffold generator creates a complete CRUD setup with all components:"
        puts "  - Model with attributes"
        puts "  - Database migration file"
        puts "  - RESTful endpoints (index, show, new, create, edit, update, destroy)"
        puts "  - Request classes for input validation (Azu::Request)"
        puts "  - Response/Page classes for output formatting"
        puts "  - Template files for web views (Web mode)"
        puts "  - Use --skip to exclude specific components"
        puts "  - Use --api-only for REST APIs without web interface"
        puts "  - Use --web-only for web applications without API"
        puts
        puts "Generator Output Directories:"
        puts "  models/         - CQL model files"
        puts "  endpoints/      - HTTP endpoint files"
        puts "  requests/       - Request validation files (Azu::Request)"
        puts "  pages/          - Page response files (Web/API)"
        puts "  jobs/           - Background job files"
        puts "  middleware/     - Middleware files"
        puts "  migrations/     - Database migration files"
        puts "  components/     - Reusable component files"
        puts "  validators/     - Custom validator files"
        puts "  templates/      - Jinja2 template files"
        puts
        puts "Skip Components Examples:"
        puts "  azu generate scaffold Post title:string content:text --skip template,page"
        puts "    Generates everything except templates and pages"
        puts "  azu generate scaffold User name:string email:string --skip migration"
        puts "    Generates everything except database migration"
        puts "  azu generate scaffold Article title:string --skip response --web-only"
        puts "    Generates web components only, skipping response/page classes"
        puts
        puts "Tips:"
        puts "  - Use --force to overwrite existing files"
        puts "  - Use --api-only for REST APIs without web interface"
        puts "  - Use --web-only for web applications without API"
        puts "  - Use --skip to exclude specific components from generation"
        puts "  - Scaffold generates both API and web components by default"
        puts "  - Generated files follow Azu framework conventions"
      end
    end
  end
end
