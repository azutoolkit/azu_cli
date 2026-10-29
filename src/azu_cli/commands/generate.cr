require "./base"
require "option_parser"
require "../logger"
require "../generators/**"
require "../config/**"

module AzuCLI
  module Commands
    # Generate command for creating code from templates
    class Generate < Base
      alias Generators = AzuCLI::Generate

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
      property parse_error : String? = nil
      property spark : Bool = false
      property demo_page : Bool = false

      def initialize
        super("generate", "Generate code from templates")
      end

      def execute : Result
        @all_args = without_ui_flags(@all_args)
        # OptionParser removes switches and their values from @all_args. The
        # shadow generator needs those original options, not only positionals.
        preview_args = @all_args.dup
        parse_arguments
        if result = preview_flow(preview_args)
          return result
        end

        # Detect project type and auto-set API mode
        detector = ProjectDetector.new
        if detector.api_project? && !@web_only
          @api_only = true
          Logger.debug("API project detected, using API-only mode")
        end

        # Some generators don't require a name (like auth, validate, joobq)
        generators_without_name = NAMELESS_GENERATORS

        @generator_type = get_arg(0) || ""

        # Show help if no generator type provided
        if @generator_type.empty?
          show_help
          return success("Help information displayed")
        end

        if generators_without_name.includes?(@generator_type.downcase)
          case @generator_type.downcase
          when "validate"
            @generator_name = "Templates"
          when "joobq"
            @generator_name = "JoobQ"
          else # auth, authentication
            @generator_name = "Auth"
          end
        else
          # Validate required arguments for other generators
          unless validate_required_args(2)
            return error("Usage: azu generate <type> <name> [attributes] [options]")
          end
          if name = get_arg(1)
            @generator_name = name
          else
            return error("Generator name is required")
          end
        end

        # Parse attributes from remaining arguments
        parse_attributes

        # Check for parse errors
        if parse_err = @parse_error
          return error(parse_err)
        end

        # CQL supports JSON columns, queries and converted model reads. Our
        # generated instance save! path still needs JSON-to-DB::Any mapping.
        # Reject this automatic mapping before writing a broken CRUD skeleton.
        if %w(model scaffold spark:scaffold api_resource api-resource).includes?(@generator_type) &&
           @attributes.any? { |name, type| Generators::Field.new(name, type).kind == "json" }
          return error("Automatic JSON model/scaffold generation needs a persistence mapping: the generated save! path fails in CQL 1.0.0 #attributes. CQL supports JSON columns and queries; use its query builder with explicit model conversion. JSON requests and migrations can be generated separately.")
        end

        if RESOURCE_NAMED_GENERATORS.includes?(@generator_type) && (message = Generators::Resource.name_error(@generator_name))
          return error(message)
        end
        if @spark && @generator_type != "scaffold"
          return error("--spark is supported by scaffold; use generate spark for a live component")
        end
        if @demo_page && !{"spark", "spark:component"}.includes?(@generator_type)
          return error("--page is supported by generate spark")
        end
        if RESOURCE_GENERATORS.includes?(@generator_type) && (provided = Generators::Field.provided(@attributes)).any?
          Logger.warn("#{provided.join(", ")} #{provided.size == 1 ? "is" : "are"} provided by the model and left out of the attributes")
        end

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
        when "request"
          generate_request
        when "contract"
          Logger.warn("'contract' generator is deprecated. Use 'request' instead.")
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
        when "data:migration", "data_migration"
          generate_data_migration
        when "seed"
          generate_seed
        when "component"
          generate_component
        when "spark", "spark:component"
          generate_spark
        when "spark:scaffold"
          @spark = true
          generate_scaffold
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
        when "validate"
          validate_templates
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
          parser.on("--spark", "Generate a database-backed live CRUD scaffold") { @spark = true }
          parser.on("--page", "Include a runnable demo page for a Spark component") { @demo_page = true }
          parser.on("--api-only", "Generate API-only components") { @api_only = true }
          parser.on("--web-only", "Generate web-only components") { @web_only = true }
          parser.on("--skip-tests", "Do not generate the migration (generate model)") { @skip_tests = true }
          parser.on("--skip COMPONENTS", "Skip specific components (comma-separated): model,endpoint,request,response,template,migration,page,service") do |components|
            @skip_components = components.split(",").map(&.strip.downcase)
          end
          parser.on("--strategy STRATEGY", "Authentication strategy (session)") do |strategy|
            @options["strategy"] = strategy
          end
          parser.on("--type TYPE", "Generator-specific type") do |type|
            @options["type"] = type
          end
          parser.on("--env ENV", "Seed environment (development)") { |env| @options["env"] = env }
          parser.on("--record RECORD", "Record type for validators") do |record|
            @options["record"] = record
          end
          parser.on("--dry-run", "Show the files it would write, write nothing") { @dry_run = true }
          parser.on("--yes", "Write without asking (after the preview on a terminal)") { @yes = true }
          parser.on("--check", "Type-check the project with the generated files before writing") { @check = true }
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
            field_name = parts[0]

            if RESOURCE_GENERATORS.includes?(@generator_type) && (message = Generators::Field.name_error(field_name))
              Logger.error(message)
              @parse_error = message
              next
            end

            # Check for duplicate field names
            if @attributes.has_key?(field_name)
              Logger.error("Duplicate field name '#{field_name}' found in attributes.")
              @parse_error = "Duplicate field name '#{field_name}'"
            else
              @attributes[field_name] = parts[1]
            end
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

        generator = Generators::Model.new(
          name: @generator_name,
          attributes: @attributes,
          generate_migration: !@skip_tests
        )

        render_generator(generator, Generators::Model::OUTPUT_DIR)

        # Show helpful next steps
        Logger.success("✓ Model #{@generator_name} created: src/models/#{Generators::Resource.singular(@generator_name)}.cr")
        unless @skip_tests
          Logger.success("✓ Migration created: #{AzuCLI::Config::Paths::MIGRATIONS}/*_create_#{Generators::Resource.plural(@generator_name)}.cr")
        end

        Logger.info("")
        Logger.info("Next steps:")
        Logger.info("  1. Run migrations: azu db:migrate")
        Logger.info("  2. Add validations to the request contracts in src/requests/")
        Logger.info("  3. Generate endpoints: azu generate endpoint #{@generator_name}")
        Logger.info("")
        Logger.info("Documentation: https://azutoolkit.github.io/cql/")

        success("Generated model #{@generator_name} successfully")
      end

      # An error naming the supported actions, if any of `actions` is not one of them.
      private def unsupported_actions(actions : Array(String), supported : Array(String)) : Result?
        unsupported = actions - supported
        return if unsupported.empty?
        error("Unsupported action#{"s" if unsupported.size > 1} #{unsupported.join(", ")}. Supported actions: #{supported.join(", ")}")
      end

      private def generate_endpoint : Result
        Logger.info("Generating endpoint with actions: #{@actions}")
        if failure = unsupported_actions(@actions, Generators::Endpoint::ACTIONS)
          return failure
        end

        endpoint_type = @api_only ? "api" : "web"
        @actions.each do |action|
          render_generator(Generators::Endpoint.new(@generator_name, action, endpoint_type), Generators::Endpoint::OUTPUT_DIR)
        end

        resource_path = "/#{Generators::Resource.plural(@generator_name)}"
        Logger.success("✓ Endpoint #{@generator_name} created")

        Logger.info("")
        Logger.info("Generated endpoints:")
        @actions.each do |action|
          case action
          when "index"
            Logger.info("  GET    #{resource_path}")
          when "show"
            Logger.info("  GET    #{resource_path}/:id")
          when "new"
            Logger.info("  GET    #{resource_path}/new")
          when "create"
            Logger.info("  POST   #{resource_path}")
          when "edit"
            Logger.info("  GET    #{resource_path}/:id/edit")
          when "update"
            Logger.info("  PATCH  #{resource_path}/:id")
          when "destroy"
            Logger.info("  DELETE #{resource_path}/:id")
          end
        end

        Logger.info("")
        Logger.info("Next steps:")
        Logger.info("  1. Create the requests: azu generate request #{@generator_name} <action>")
        Logger.info("  2. Create the service layer: azu generate service #{@generator_name}")
        Logger.info("")
        Logger.info("Documentation: https://azutoolkit.github.io/azu/")

        success("Generated endpoint #{@generator_name} successfully")
      end

      private def generate_service : Result
        Logger.info("Generating service")

        actions_to_generate = @actions.empty? ? Generators::Service::ACTIONS : @actions
        if failure = unsupported_actions(actions_to_generate, Generators::Service::ACTIONS)
          return failure
        end

        actions_to_generate.each do |action|
          generator = Generators::Service.new(@generator_name, action, @attributes)
          render_generator(generator, Generators::Service::OUTPUT_DIR)
        end

        Logger.success("✓ Services created in src/services/#{Generators::Resource.plural(@generator_name)}/")
        actions_to_generate.each do |action|
          Logger.info("  - #{action}_service.cr")
        end

        Logger.info("")
        Logger.info("Next steps:")
        Logger.info("  1. Implement business logic in each service")
        Logger.info("  2. Call services from endpoints:")
        Logger.info("     #{Generators::Resource.plural(@generator_name).camelcase}::CreateService.new.call(create_request)")
        Logger.info("")
        Logger.info("Documentation: https://azutoolkit.github.io/azu/")

        success("Generated service #{@generator_name} successfully")
      end

      private def generate_request : Result
        Logger.info("Generating request")

        action = @actions.first? || "index"
        if failure = unsupported_actions([action], Generators::Request::ACTIONS)
          return failure
        end
        generator = Generators::Request.new(@generator_name, action, @attributes)

        render_generator(generator, Generators::Request::OUTPUT_DIR)
        success("Generated request #{@generator_name} successfully")
      end

      private def generate_page : Result
        Logger.info("Generating page with template")

        action = @actions.first? || "index"
        if failure = unsupported_actions([action], @api_only ? Generators::Response::ACTIONS : Generators::Page::ACTIONS)
          return failure
        end
        if @api_only
          render_generator(Generators::Response.new(@generator_name, action, @attributes), Generators::Response::OUTPUT_DIR)
        else
          render_generator(Generators::Page.new(@generator_name, action, @attributes), Generators::Page::OUTPUT_DIR)
          render_generator(Generators::Template.new(@generator_name, action, @attributes), Generators::Template::OUTPUT_DIR)
        end
        success("Generated page #{@generator_name} successfully")
      end

      private def generate_job : Result
        Logger.info("Generating job")

        if message = Generators::Job.error_for(@generator_name, @attributes)
          return error(message)
        end

        generator = Generators::Job.new(
          name: @generator_name,
          parameters: @attributes
        )

        render_generator(generator, Generators::Job::OUTPUT_DIR)

        # Show helpful next steps
        job_name = generator.job_struct_name
        Logger.success("✓ Job #{job_name} created: #{generator.file_path}")

        Logger.info("")
        Logger.info("Usage examples:")
        if @attributes.empty?
          Logger.info("  # Enqueue job")
          Logger.info("  #{job_name}.enqueue")
          Logger.info("")
          Logger.info("  # Schedule for later")
          Logger.info("  #{job_name}.delay(for: 5.minutes)")
        else
          params = @attributes.keys.map { |k| "#{k}: value" }.join(", ")
          Logger.info("  # Enqueue job")
          Logger.info("  #{job_name}.enqueue(#{params})")
          Logger.info("")
          Logger.info("  # Schedule for later")
          Logger.info("  #{job_name}.delay(for: 5.minutes, #{params})")
        end

        Logger.info("")
        Logger.info("Next steps:")
        Logger.info("  1. Give it a queue that the worker runs, in src/initializers/joobq.cr:")
        Logger.info("     JoobQ::QueueFactory.register_job_type(#{job_name})")
        Logger.info("     JoobQ.config.queue_configs[\"#{generator.queue}\"] = {job_class_name: \"#{job_name}\", workers: 2, throttle: nil}")
        Logger.info("  2. Implement job logic in the perform method")
        Logger.info("  3. Start worker: azu jobs:worker")
        Logger.info("")
        Logger.info("Documentation: https://azutoolkit.github.io/joobq/")

        success("Generated job #{@generator_name} successfully")
      end

      private def generate_joobq_setup : Result
        Logger.info("Setting up JoobQ integration")

        # Get project name from current directory or options
        project_name = @options["project"]? || Dir.current.split("/").last
        redis_url = @options["redis"]? || "redis://localhost:6379"
        if message = Generators::JoobQ.redis_url_error(redis_url)
          return usage_error(message)
        end
        create_example = !@options.has_key?("no-example")

        generator = Generators::JoobQ.new(
          project_name: project_name,
          redis_url: redis_url,
          create_example_job: create_example
        )

        # Create necessary directories
        Dir.mkdir_p("config") unless Dir.exists?("config")
        Dir.mkdir_p("src/initializers") unless Dir.exists?("src/initializers")
        Dir.mkdir_p("src/jobs") unless Dir.exists?("src/jobs")

        # Render the generator files
        generator.render(".", force: @force, interactive: false, list: false, color: true)

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
        Logger.info("       version: ~> 0.4.2")
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

        generator = Generators::Middleware.new(
          name: @generator_name,
          middleware_type: middleware_type
        )

        render_generator(generator, Generators::Middleware::OUTPUT_DIR)
        success("Generated middleware #{@generator_name} successfully")
      end

      private def generate_migration : Result
        Logger.info("Generating migration")

        generator = Generators::Migration.new(
          name: @generator_name,
          attributes: @attributes
        )

        render_generator(generator, Generators::Migration::OUTPUT_DIR)

        # Show helpful next steps
        Logger.success("✓ Migration created: #{AzuCLI::Config::Paths::MIGRATIONS}/#{generator.migration_filename}")

        Logger.info("")
        Logger.info("Next steps:")
        Logger.info("  1. Review the migration file")
        Logger.info("  2. Run migration: azu db:migrate")
        Logger.info("  3. Check status: azu db:status")
        Logger.info("")
        Logger.info("Rollback commands:")
        Logger.info("  azu db:rollback          # Rollback last migration")
        Logger.info("  azu db:rollback --steps 2  # Rollback last 2 migrations")
        Logger.info("")
        Logger.info("Documentation: https://azutoolkit.github.io/cql/")

        success("Generated migration #{@generator_name} successfully")
      end

      private def generate_data_migration : Result
        Logger.info("Generating data migration")

        generator = Generators::DataMigration.new(
          name: @generator_name
        )

        render_generator(generator, Generators::DataMigration::OUTPUT_DIR)
        success("Generated data migration #{@generator_name} successfully")
      end

      private def generate_seed : Result
        environment = @options["env"]? || "development"
        generator = Generators::Seed.new(@generator_name, environment)
        render_generator(generator, Generators::Seed::OUTPUT_DIR)
        success("Generated seed file #{@generator_name} for #{environment} environment")
      end

      private def generate_component : Result
        Logger.info("Generating component")

        generator = Generators::Component.new(
          name: @generator_name,
          properties: @attributes
        )

        render_generator(generator, Generators::Component::OUTPUT_DIR)
        success("Generated component #{@generator_name} successfully")
      end

      private def generate_spark : Result
        return error("Spark components need a web project") unless ProjectDetector.new.web_project? && !@api_only
        return error("Spark components take typed fields, not actions") unless @actions.empty?
        if message = Generators::Spark.attributes_error(@attributes, component: true)
          return error(message)
        end
        render_generator(Generators::Spark.new(@generator_name, @attributes, @demo_page), Generators::Spark::OUTPUT_DIR)
        success("Generated Spark component #{@generator_name}; SPARK_SECRET and the local client endpoint are configured")
      end

      private def generate_validator : Result
        Logger.info("Generating validator")

        record_type = @options["record"]? || "User"

        generator = Generators::Validator.new(
          name: @generator_name,
          record_type: record_type
        )

        render_generator(generator, Generators::Validator::OUTPUT_DIR)
        success("Generated validator #{@generator_name} successfully")
      end

      private def generate_response : Result
        Logger.info("Generating response")

        action = @actions.first? || "show"
        if failure = unsupported_actions([action], Generators::Response::ACTIONS)
          return failure
        end
        generator = Generators::Response.new(@generator_name, action, @attributes)

        render_generator(generator, Generators::Response::OUTPUT_DIR)
        success("Generated response #{@generator_name} successfully")
      end

      private def generate_template : Result
        Logger.info("Generating template")

        action = @actions.first? || "index"
        if failure = unsupported_actions([action], Generators::Page::ACTIONS)
          return failure
        end
        generator = Generators::Template.new(@generator_name, action, @attributes)

        render_generator(generator, Generators::Template::OUTPUT_DIR)
        success("Generated template #{@generator_name} successfully")
      end

      private def generate_mailer : Result
        Logger.info("Generating mailer")

        methods = @actions.empty? ? ["welcome"] : @actions

        generator = Generators::Mailer.new(
          name: @generator_name,
          methods: methods,
          async: !@skip_components.includes?("job")
        )

        render_generator(generator, Generators::Mailer::OUTPUT_DIR)
        success("Generated mailer #{@generator_name} successfully")
      end

      private def generate_channel : Result
        Logger.info("Generating WebSocket channel")

        if message = Generators::Channel.name_error(@generator_name)
          return error(message)
        end
        unless @actions.empty?
          return error("A channel has no actions (got #{@actions.join(", ")}): it relays every message to all its clients.")
        end

        generator = Generators::Channel.new(@generator_name)
        render_generator(generator, Generators::Channel::OUTPUT_DIR)

        Logger.success("✓ Channel #{generator.camel_case_name}Channel created: src/channels/#{generator.snake_case_name}_channel.cr")
        Logger.info("Clients connect to ws://localhost:4000#{generator.route}; change what it does in on_connect and on_message.")

        success("Generated channel #{@generator_name} successfully")
      end

      private def generate_auth : Result
        Logger.info("Generating authentication")

        if ProjectDetector.new.api_project?
          return error("Authentication is generated for web projects (session cookie). API projects have no generated authentication yet.")
        end
        if strategy = @options["strategy"]?
          return error("Unsupported strategy '#{strategy}': the generated authentication uses a session cookie only.") unless strategy == "session"
        end

        if conflict = Generators::Auth.conflict
          return error(conflict)
        end

        render_generator(Generators::Auth.new, Generators::Auth::OUTPUT_DIR)

        Logger.success("✓ Authentication generated: /register, /login, /logout and /account")
        Logger.info("Next steps: azu db:migrate; azu serve (SESSION_SECRET is in the git-ignored .env)")

        success("Generated authentication successfully")
      end

      private def generate_api_resource : Result
        Logger.info("Generating API resource (complete REST API)")

        @api_only = true
        generate_scaffold
      end

      private def generate_scaffold : Result
        Logger.info("Generating scaffold (complete CRUD)")

        if @spark
          return error("Spark scaffolds need a web project") unless ProjectDetector.new.web_project? && !@api_only
          return error("--skip is not supported for Spark scaffolds; all live CRUD layers are required") unless @skip_components.empty?
          if message = Generators::Spark.attributes_error(@attributes)
            return error(message)
          end
        end

        validation_result = validate_scaffold_parameters
        return validation_result unless validation_result.success?

        generated = scaffold_steps.compact_map do |component, (generators, output_dir)|
          next if should_skip_component?(component)

          generators.each { |generator| render_generator(generator, output_dir) }
          component
        end

        Logger.info("✅ Scaffold generation completed")
        Logger.info("📦 Generated components: #{generated.join(", ")}")
        Logger.info("⏭️  Skipped components: #{@skip_components.join(", ")}") if @skip_components.any?
        Logger.info("Next: azu db:setup, then azu serve")

        success("Generated scaffold #{@generator_name} successfully")
      rescue ex : Exception
        error("Scaffold generation failed: #{ex.message}")
      end

      # The generators of each scaffold component with the directory they render into. The model
      # generator also renders the migration, unless the model itself is skipped.
      private def scaffold_steps : Hash(String, Tuple(Array(Teeplate::FileTree), String))
        type = @api_only ? "api" : "web"
        steps = {} of String => Tuple(Array(Teeplate::FileTree), String)

        steps["model"] = {[Generators::Model.new(@generator_name, @attributes, generate_migration: !should_skip_component?("migration")).as(Teeplate::FileTree)], Generators::Model::OUTPUT_DIR}
        if should_skip_component?("model")
          steps["migration"] = {[Generators::Migration.new("create_#{Generators::Resource.plural(@generator_name)}", @attributes, table: Generators::Resource.plural(@generator_name)).as(Teeplate::FileTree)], Generators::Migration::OUTPUT_DIR}
        end
        endpoint_actions = @spark ? scaffold_actions.reject("index") : scaffold_actions
        steps["endpoint"] = {generators_for(endpoint_actions) { |action| Generators::Endpoint.new(@generator_name, action, type) }, Generators::Endpoint::OUTPUT_DIR}
        steps["service"] = {generators_for(Generators::Service::ACTIONS) { |action| Generators::Service.new(@generator_name, action, @attributes, broadcast: @spark) }, Generators::Service::OUTPUT_DIR}
        steps["request"] = {generators_for(scaffold_actions) { |action| Generators::Request.new(@generator_name, action, @attributes) }, Generators::Request::OUTPUT_DIR}

        if @api_only
          steps["response"] = {generators_for(Generators::Response::ACTIONS) { |action| Generators::Response.new(@generator_name, action, @attributes) }, Generators::Response::OUTPUT_DIR}
        else
          page_actions = @spark ? Generators::Page::ACTIONS.reject("index") : Generators::Page::ACTIONS
          steps["page"] = {generators_for(page_actions) { |action| Generators::Page.new(@generator_name, action, @attributes) }, Generators::Page::OUTPUT_DIR}
          steps["template"] = {generators_for(page_actions) { |action| Generators::Template.new(@generator_name, action, @attributes) }, Generators::Template::OUTPUT_DIR}
          if @spark
            steps["spark"] = {[Generators::SparkScaffold.new(@generator_name, "index", @attributes).as(Teeplate::FileTree)], Generators::SparkScaffold::OUTPUT_DIR}
          end
        end
        steps
      end

      private def generators_for(actions : Array(String), & : String -> Teeplate::FileTree) : Array(Teeplate::FileTree)
        actions.map { |action| yield(action).as(Teeplate::FileTree) }
      end

      # An API has no forms, so no `new` and `edit`.
      private def scaffold_actions : Array(String)
        @api_only ? %w(index show create update destroy) : %w(index show new create edit update destroy)
      end

      # Every generator type `execute` routes (the generator plugin validates against this list)
      GENERATOR_TYPES = %w(
        model endpoint service request contract page job joobq middleware migration data:migration data_migration
        seed component spark spark:component spark:scaffold validator response template scaffold mailer channel auth authentication api_resource
        api-resource validate
      )
      # The generators that take no name
      NAMELESS_GENERATORS = %w(auth authentication validate joobq)

      # The generators whose `name:type` arguments become columns, getters and form fields.
      RESOURCE_GENERATORS = %w(model migration scaffold spark spark:component spark:scaffold api_resource api-resource request page response template service endpoint)
      # Those among them whose name is the resource (a migration is named for what it does).
      RESOURCE_NAMED_GENERATORS = RESOURCE_GENERATORS - %w(migration)
      SCAFFOLD_TYPES            = %w(string text int32 integer int64 float32 float64 float bool boolean time datetime date json uuid email url references belongs_to)

      # Validate scaffold generation parameters
      private def validate_scaffold_parameters : Result
        @attributes.each do |name, type|
          if message = Generators::Field.new(name, type).type_error(SCAFFOLD_TYPES)
            return error(message)
          end
        end

        if @skip_components.size >= 7 # All components skipped
          return error("Cannot generate scaffold with all components skipped. At least one component must be generated.")
        end

        success("Scaffold validation passed")
      end

      # Helper method to check if a component should be skipped
      private def should_skip_component?(component : String) : Bool
        @skip_components.includes?(component.downcase)
      end

      # Render a generator to its appropriate output directory
      private def render_generator(generator : Teeplate::FileTree, output_dir : String)
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

      # Validate Jinja templates
      private def validate_templates : Result
        Logger.info("Validating Jinja templates")

        # Look for template files in the project
        template_dirs = [
          "./public/templates",
          "./src/templates",
          "./templates",
        ]

        template_files = [] of String
        template_dirs.each do |dir|
          if Dir.exists?(dir)
            files = Dir.glob(File.join(dir, "**", "*.jinja"))
            template_files.concat(files)
          end
        end

        if template_files.empty?
          Logger.warn("No Jinja template files found in common directories")
          Logger.info("Searched in: #{template_dirs.join(", ")}")
          return success("No templates to validate")
        end

        Logger.info("Found #{template_files.size} template files to validate")

        # Validate all template files
        results = AzuCLI::Validators::JinjaValidator.validate_files(template_files)

        # Count results
        valid_files = results.count { |_, result| result.valid }
        error_count = results.sum { |_, result| result.errors.size }
        warning_count = results.sum { |_, result| result.warnings.size }

        # Display results
        puts AzuCLI::Validators::JinjaValidator.summary(results)
        puts

        # Show detailed results for files with issues
        results.each do |file_path, result|
          unless result.valid || !result.warnings.empty?
            next
          end

          puts "File: #{file_path}"
          puts result.to_s
          puts
        end

        if error_count > 0
          Logger.error("Template validation failed with #{error_count} errors")
          error("Template validation failed")
        elsif warning_count > 0
          Logger.warn("Template validation completed with #{warning_count} warnings")
          success("Template validation completed with warnings")
        else
          Logger.info("All templates are valid")
          success("Template validation passed")
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
        puts
        puts "  page <name> [attr:type]"
        puts "    Generate a page response class (Web) or JSON response class (API)"
        puts "    Example: azu generate page UserProfile name:string email:string"
        puts
        puts "  job <name> [param:type]"
        puts "    Generate a background job class with parameters"
        puts "    Example: azu generate job EmailNotification user_id:int32 template:string"
        puts
        puts "  middleware <name> [--type authentication|authorization|logging|cors|rate_limiting]"
        puts "    Generate middleware for request/response processing"
        puts "    Example: azu generate middleware Authentication --type authentication"
        puts
        puts "  migration <name> [attr:type]"
        puts "    Generate a database migration file"
        puts "    Example: azu generate migration AddAgeToUsers age:int32"
        puts
        puts "  data:migration <name>"
        puts "    Generate a data migration file for data transformations"
        puts "    Example: azu generate data:migration AddDefaultRolesToUsers"
        puts
        puts "  seed <name> [--env environment]"
        puts "    Generate a seed file for database seeding"
        puts "    Example: azu generate seed Users --env development"
        puts
        puts "  component <name> [attr:type]"
        puts "    Generate a reusable component class"
        puts "    Example: azu generate component UserCard name:string email:string"
        puts ""
        puts "  spark <name> [attr:type] [--page]"
        puts "    Generate a typed Spark live component; --page adds a runnable demo and navigation"
        puts "    Example: azu generate spark Counter count:int32 --page"
        puts ""
        puts "  spark:scaffold <name> [attr:type]"
        puts "    Generate live database CRUD (also: scaffold <name> [attr:type] --spark)"
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
        puts "  channel <name>"
        puts "    Generate a WebSocket channel served at /<name>; every message reaches all its clients"
        puts "    Example: azu generate channel Chat"
        puts
        puts "  auth"
        puts "    Generate sign up, sign in, sign out and a protected page (web projects, session cookie)"
        puts "    Example: azu generate auth"
        puts
        puts "  api_resource <name> [attr:type]"
        puts "    Generate complete REST API resource (API-only)"
        puts "    Example: azu generate api_resource Post title:string content:text"
        puts
        puts "  validate"
        puts "    Validate Jinja template syntax in the project"
        puts "    Example: azu generate validate"
        puts
        puts "Options:"
        puts "  --force                    Overwrite existing files without prompting"
        puts "  --dry-run                  Show the files it would write (and the diff of files it changes), write nothing"
        puts "  --yes                      Write without asking (on a terminal the preview still shows)"
        puts "  --check                    Type-check the project with the generated files first"
        puts "  --ui MODE                  rich (the preview, the default on a terminal) or plain"
        puts "  --skip-tests               Do not generate the migration (generate model)"
        puts "  --api-only                 Generate API-only components (JSON responses)"
        puts "  --spark                    Generate live CRUD for a web scaffold"
        puts "  --page                     Include a demo page for a Spark component"
        puts "  --web-only                 Generate web-only components (HTML pages)"
        puts "  --skip COMPONENTS          Skip specific components (comma-separated)"
        puts "                             Available components: model,endpoint,request,response,template,migration,page,service"
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
        puts "  - Service classes for business logic with CRUD operations"
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
        puts "  services/       - Business logic service files"
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
