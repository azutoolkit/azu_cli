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
      property parse_error : String? = nil

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

        # Some generators don't require a name (like auth, validate, joobq)
        generators_without_name = ["auth", "authentication", "validate", "joobq"]

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
          @generator_name = get_arg(1).not_nil!
        end

        # Parse attributes from remaining arguments
        parse_attributes

        # Check for parse errors
        if @parse_error
          return error(@parse_error.not_nil!)
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
          parser.on("--api-only", "Generate API-only components") { @api_only = true }
          parser.on("--web-only", "Generate web-only components") { @web_only = true }
          parser.on("--skip-tests", "Skip test file generation") { @skip_tests = true }
          parser.on("--skip COMPONENTS", "Skip specific components (comma-separated): model,endpoint,request,response,template,migration,page,service") do |components|
            @skip_components = components.split(",").map(&.strip.downcase)
          end
          parser.on("--strategy STRATEGY", "Authentication strategy (jwt, session, oauth)") do |strategy|
            @options["strategy"] = strategy
          end
          parser.on("--user-model MODEL", "User model name for authentication") do |model|
            @options["user_model"] = model
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
            field_name = parts[0]

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

        # Endpoint generator has custom render method
        generator.render(AzuCLI::Generate::Endpoint::OUTPUT_DIR, force: @force, interactive: false)
        success("Generated endpoint #{@generator_name} successfully")
      end

      private def generate_service : Result
        Logger.info("Generating service")

        # If no actions specified, generate all CRUD actions
        actions_to_generate = @actions.empty? ? ["create", "index", "show", "update", "destroy"] : @actions

        actions_to_generate.each do |action|
          generator = AzuCLI::Generate::Service.new(
            name: @generator_name,
            action: action,
            attributes: @attributes
          )
          render_generator(generator, AzuCLI::Generate::Service::OUTPUT_DIR)
        end

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
        return "app" unless File.exists?("./shard.yml")
        shard_yml = YAML.parse(File.read("./shard.yml"))
        shard_yml["name"].as_s
      rescue
        "app"
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

      private def generate_data_migration : Result
        Logger.info("Generating data migration")

        generator = AzuCLI::Generate::DataMigration.new(
          name: @generator_name
        )

        render_generator(generator, AzuCLI::Generate::DataMigration::OUTPUT_DIR)
        success("Generated data migration #{@generator_name} successfully")
      end

      private def generate_seed : Result
        Logger.info("Generating seed file")

        environment = @options["env"]? || "development"
        seed_name = @generator_name

        # Create seed file in appropriate environment directory
        seeds_dir = "./src/db/seeds"
        env_dir = File.join(seeds_dir, environment)
        Dir.mkdir_p(env_dir) unless Dir.exists?(env_dir)

        seed_filename = "#{Time.utc.to_s("%Y%m%d%H%M%S")}_#{seed_name.underscore}.cr"
        seed_path = File.join(env_dir, seed_filename)

        seed_content = String.build do |io|
          io << "# Seed file: #{seed_name}\n"
          io << "# Environment: #{environment}\n"
          io << "# Generated: #{Time.utc}\n\n"
          io << "require \"../models/**\"\n\n"
          io << "puts \"Seeding #{seed_name} for #{environment} environment...\"\n\n"
          io << "# TODO: Add your seed data here\n"
          io << "# Example:\n"
          io << "# #{seed_name}.create!(\n"
          io << "#   name: \"Example #{seed_name}\",\n"
          io << "#   description: \"This is a sample #{seed_name.downcase}\"\n"
          io << "# )\n\n"
          io << "puts \"✓ #{seed_name} seeded successfully\"\n"
        end

        File.write(seed_path, seed_content)
        Logger.info("✓ Seed file created: #{seed_path}")
        success("Generated seed file #{seed_name} for #{environment} environment")
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
        project_type = "api" # Always generate API-style responses for the response command

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

        strategy = @options["strategy"]? || "authly"
        user_model = @options["user_model"]? || "User"
        proj_name = project_name

        # Parse boolean options
        enable_rbac = @options["rbac"]?.try { |v| v.downcase == "true" } || true
        enable_csrf = @options["csrf"]?.try { |v| v.downcase == "true" } || true

        # Parse OAuth providers
        oauth_providers = @options["oauth-providers"]?.try(&.split(",").map(&.strip)) || ["google", "github"]

        generator = AzuCLI::Generate::Auth.new(
          project: proj_name,
          strategy: strategy,
          user_model: user_model,
          enable_rbac: enable_rbac,
          enable_csrf: enable_csrf,
          enable_oauth_providers: oauth_providers
        )

        Logger.info("Strategy: #{strategy}")
        Logger.info("User model: #{user_model}")
        Logger.info("RBAC enabled: #{enable_rbac}")
        Logger.info("CSRF protection: #{enable_csrf}")
        Logger.info("OAuth providers: #{oauth_providers.join(", ")}")

        render_generator(generator, AzuCLI::Generate::Auth::OUTPUT_DIR)

        # Fix migration timestamps to be unique
        fix_auth_migration_timestamps

        Logger.info("✓ Authentication system generated")
        Logger.info("")
        Logger.info("Next steps:")
        Logger.info("1. Run 'azu db:migrate' to create authentication tables")

        if strategy == "jwt" || strategy == "authly"
          Logger.info("2. Set JWT_SECRET and JWT_REFRESH_SECRET environment variables")
          Logger.info("3. Set JWT_ISSUER and JWT_AUDIENCE environment variables")
        end

        if strategy == "authly"
          Logger.info("4. Configure OAuth providers in your application")
          Logger.info("5. Set up Authly configuration")
        end

        if enable_csrf
          Logger.info("6. Configure CSRF protection middleware")
        end

        Logger.info("7. Configure your application to use the auth endpoints")

        success("Generated authentication system successfully")
      end

      # Fix auth migration timestamps to be unique (increment by 1 second each)
      private def fix_auth_migration_timestamps
        # Check both possible locations
        migrations_dir = if Dir.exists?("./src/db/migrations")
                          "./src/db/migrations"
                        elsif Dir.exists?("./db/migrations")
                          "./db/migrations"
                        else
                          Logger.debug("No migrations directory found for timestamp fix")
                          return
                        end

        Logger.info("Fixing migration timestamps in: #{migrations_dir}")

        # Find all migration files with the same timestamp
        migration_files = Dir.glob("#{migrations_dir}/*.cr").sort
        if migration_files.empty?
          Logger.info("No migration files found to fix")
          return
        end
        
        Logger.info("Found #{migration_files.size} migration files to check")

        # Remove empty migration files (from conditional templates)
        migration_files.reject! do |file|
          content = File.read(file)
          if content.strip.empty? || content.size < 50 # suspiciously small
            Logger.info("Removing empty/invalid migration: #{File.basename(file)}")
            File.delete(file)
            true
          else
            false
          end
        end

        return if migration_files.empty?

        # Group by timestamp to find duplicates
        grouped = migration_files.group_by do |file|
          if match = File.basename(file).match(/^(\d+)_/)
            match[1]
          end
        end

        # Fix duplicates by incrementing timestamps
        grouped.each do |timestamp, files|
          next if files.size <= 1 || timestamp.nil?

          Logger.info("Found #{files.size} migrations with duplicate timestamp #{timestamp}, fixing...")

          # Define the order for auth migrations
          migration_order = [
            "create_users",
            "create_roles",
            "create_permissions",
            "create_user_roles",
            "create_role_permissions",
            "create_oauth_applications"
          ]

          # Sort files according to the desired order
          sorted_files = files.sort_by do |file|
            basename = File.basename(file, ".cr")
            name_part = basename.sub(/^\d+_/, "")
            migration_order.index(name_part) || 999
          end

          # Rename files with incrementing timestamps
          sorted_files.each_with_index do |file, index|
            old_basename = File.basename(file)
            new_timestamp = timestamp.to_i64 + index
            
            # Read the content to extract the actual class name
            content = File.read(file)
            
            # Extract class name from the file
            class_name = if match = content.match(/class\s+(\w+)\s+<\s+CQL::Migration/)
                          match[1]
                        else
                          nil
                        end
            
            # If we have a class name, use it to construct the filename
            new_basename = if class_name
                            # Convert class name to snake_case for filename
                            snake_name = class_name
                              .gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
                              .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
                              .downcase
                            "#{new_timestamp}_#{snake_name}.cr"
                          else
                            # Fallback to just updating the timestamp
                            old_basename.sub(/^\d+/, new_timestamp.to_s)
                          end
            
            new_path = File.join(migrations_dir, new_basename)

            # Update the migration class timestamp inside the content
            updated_content = content.sub(/CQL::Migration\(#{timestamp}\)/, "CQL::Migration(#{new_timestamp})")
            
            # Write the updated content to the new file
            File.write(new_path, updated_content)
            
            # Delete old file if it's different
            File.delete(file) if file != new_path
          end
        end
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

        # Validate scaffold generation parameters
        validation_result = validate_scaffold_parameters
        return validation_result unless validation_result.success?

        components_generated = [] of String
        crud_actions = ["index", "show", "new", "create", "edit", "update", "destroy"]

        # Generate Model
        unless should_skip_component?("model")
          Logger.info("🔨 Generating model...")
          begin
            model_generator = AzuCLI::Generate::Model.new(
              name: @generator_name,
              attributes: @attributes,
              generate_migration: !should_skip_component?("migration") # Only generate migration with model if migration is not being skipped
            )
            render_generator(model_generator, AzuCLI::Generate::Model::OUTPUT_DIR)
            components_generated << "model"
            Logger.success("✓ Model generated successfully")
          rescue ex
            Logger.error("Failed to generate model: #{ex.message}")
            return error("Model generation failed: #{ex.message}")
          end
        end

        # Generate separate Migration only if model was skipped (otherwise model generator already created it)
        unless should_skip_component?("migration")
          if should_skip_component?("model") # Only generate separate migration if model was skipped
            Logger.info("🔨 Generating migration...")
            begin
              migration_generator = AzuCLI::Generate::Migration.new(
                name: "create_#{@generator_name.downcase}s",
                attributes: @attributes
              )
              render_generator(migration_generator, AzuCLI::Generate::Migration::OUTPUT_DIR)
              components_generated << "migration"
              Logger.success("✓ Migration generated successfully")
            rescue ex
              Logger.error("Failed to generate migration: #{ex.message}")
              return error("Migration generation failed: #{ex.message}")
            end
          end
        end

        # Generate Endpoints
        unless should_skip_component?("endpoint")
          Logger.info("🔨 Generating endpoints...")
          begin
            endpoint_type = @api_only ? "api" : (@web_only ? "web" : "web")
            endpoint_generator = AzuCLI::Generate::Endpoint.new(
              name: @generator_name,
              actions: crud_actions,
              endpoint_type: endpoint_type,
              scaffold: true
            )
            endpoint_generator.fields = @attributes
            endpoint_generator.render(AzuCLI::Generate::Endpoint::OUTPUT_DIR, force: @force, interactive: false)
            components_generated << "endpoint"
            Logger.success("✓ Endpoints generated successfully")
          rescue ex
            Logger.error("Failed to generate endpoints: #{ex.message}")
            return error("Endpoint generation failed: #{ex.message}")
          end
        end

        # Generate Services (if CQL enabled)
        unless should_skip_component?("service")
          Logger.info("🔨 Generating services...")

          # Service actions (skip view-only actions)
          service_actions = ["create", "index", "show", "update", "destroy"]

          service_actions.each do |action|
            service_generator = AzuCLI::Generate::Service.new(
              name: @generator_name,
              action: action,
              attributes: @attributes
            )
            render_generator(service_generator, AzuCLI::Generate::Service::OUTPUT_DIR)
          end

          components_generated << "service"
        end

        # Generate Requests (both API and Web) - aligns with Azu::Request
        unless should_skip_component?("request")
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

        # Generate Responses (API mode only)
        unless should_skip_component?("response") || @web_only
          if @api_only
            Logger.info("🔨 Generating responses...")
            output_dir = AzuCLI::Generate::Page.output_dir_for_type("api")

            # Generate responses for each CRUD action
            crud_actions.each do |action|
              response_generator = AzuCLI::Generate::Page.new(@generator_name, @attributes, action, "api")
              render_generator(response_generator, output_dir)
            end
            components_generated << "response"
          end
        end

        # Generate Pages (Web mode)
        unless should_skip_component?("page") || @api_only
          Logger.info("🔨 Generating pages...")
          output_dir = AzuCLI::Generate::Page.output_dir_for_type("web")
          crud_actions.each do |action|
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

        # Generate summary file
        generate_scaffold_summary(components_generated)

        success("Generated scaffold #{@generator_name} successfully")
      end

      # Validate scaffold generation parameters
      private def validate_scaffold_parameters : Result
        # Validate resource name format
        unless valid_crystal_identifier?(@generator_name)
          return error("Invalid resource name '#{@generator_name}'. Must be a valid Crystal identifier.")
        end

        # Check for reserved words
        reserved_words = ["id", "created_at", "updated_at", "class", "module", "def", "end", "if", "else", "elsif", "unless", "while", "until", "for", "in", "case", "when", "then", "do", "begin", "rescue", "ensure", "return", "break", "next", "yield", "super", "self", "true", "false", "nil"]
        if reserved_words.includes?(@generator_name.downcase)
          return error("Resource name '#{@generator_name}' is a reserved word. Please choose a different name.")
        end

        # Validate attribute types
        supported_types = ["string", "text", "int32", "int64", "float32", "float64", "bool", "boolean", "time", "datetime", "date", "json", "uuid", "email", "url", "references", "belongs_to"]
        @attributes.each do |field, type|
          unless supported_types.includes?(type.downcase)
            return error("Unsupported attribute type '#{type}' for field '#{field}'. Supported types: #{supported_types.join(", ")}")
          end

          # Warn about reserved field names
          if reserved_words.includes?(field.downcase)
            Logger.warn("Field name '#{field}' is a reserved word. Consider using a different name.")
          end
        end

        # Validate that at least one component will be generated
        if @skip_components.size >= 7 # All components skipped
          return error("Cannot generate scaffold with all components skipped. At least one component must be generated.")
        end

        success("Scaffold validation passed")
      end

      # Check if string is a valid Crystal identifier
      private def valid_crystal_identifier?(name : String) : Bool
        return false if name.empty?
        return false unless name.match(/^[A-Za-z_][A-Za-z0-9_]*$/)
        true
      end

      # Generate scaffold summary file
      private def generate_scaffold_summary(components_generated : Array(String))
        summary_content = <<-SUMMARY
# Scaffold Generation Summary

**Resource:** #{@generator_name}
**Generated at:** #{Time.utc}
**Project type:** #{@api_only ? "API" : (@web_only ? "Web" : "Web + API")}

## Generated Components

#{components_generated.map { |comp| "- ✅ #{comp.capitalize}" }.join("\n")}

## Generated Files

#{generate_file_list(components_generated)}

## Next Steps

1. **Database Setup:**
   - Run `azu db:migrate` to create the database tables
   - Run `azu db:seed` to populate with sample data (if applicable)

2. **Development:**
   - Start the development server with `azu serve`
   - Visit the generated endpoints in your browser or API client

3. **Customization:**
   - Modify the generated models, services, and endpoints as needed
   - Add business logic to the service classes
   - Customize the templates for web pages

## Generated Endpoints

#{generate_endpoint_list}

## Configuration

- **API Mode:** #{@api_only}
- **Web Mode:** #{@web_only}
- **Skipped Components:** #{@skip_components.any? ? @skip_components.join(", ") : "None"}

---
Generated by Azu CLI v#{AzuCLI::VERSION}
SUMMARY

        File.write("SCAFFOLD_SUMMARY.md", summary_content)
        Logger.info("📄 Summary saved to SCAFFOLD_SUMMARY.md")
      end

      # Generate file list for summary
      private def generate_file_list(components_generated : Array(String)) : String
        files = [] of String
        crud_actions = ["index", "show", "new", "create", "edit", "update", "destroy"]

        components_generated.each do |component|
          case component
          when "model"
            files << "- `src/models/#{@generator_name.underscore}.cr`"
          when "migration"
            files << "- `src/db/migrations/*_create_#{@generator_name.underscore.pluralize}.cr`"
          when "endpoint"
            crud_actions.each do |action|
              files << "- `src/endpoints/#{@generator_name.underscore.pluralize}/#{@generator_name.underscore}_#{action}_endpoint.cr`"
            end
          when "service"
            ["create", "index", "show", "update", "destroy"].each do |action|
              files << "- `src/services/#{@generator_name.underscore}/#{action}_service.cr`"
            end
            files << "- `src/services/result.cr`"
          when "request"
            crud_actions.each do |action|
              files << "- `src/requests/#{@generator_name.underscore}/#{action}_request.cr`"
            end
          when "response", "page"
            if @api_only
              crud_actions.each do |action|
                files << "- `src/pages/#{@generator_name.underscore}/#{@generator_name.underscore}_#{action}_json.cr`"
              end
            else
              crud_actions.each do |action|
                files << "- `src/pages/#{@generator_name.underscore}/#{action}_page.cr`"
              end
            end
          when "template"
            ["index", "show", "new", "edit"].each do |action|
              files << "- `public/templates/#{@generator_name.underscore}/#{action}_page.jinja`"
            end
          end
        end

        files.join("\n")
      end

      # Generate endpoint list for summary
      private def generate_endpoint_list : String
        base_path = "/#{@generator_name.underscore.pluralize}"
        endpoints = [
          "GET    #{base_path}           - List all #{@generator_name.underscore.pluralize}",
          "GET    #{base_path}/new       - New #{@generator_name.underscore} form",
          "POST   #{base_path}           - Create #{@generator_name.underscore}",
          "GET    #{base_path}/:id       - Show #{@generator_name.underscore}",
          "GET    #{base_path}/:id/edit  - Edit #{@generator_name.underscore} form",
          "PATCH  #{base_path}/:id       - Update #{@generator_name.underscore}",
          "DELETE #{base_path}/:id       - Delete #{@generator_name.underscore}",
        ]
        endpoints.join("\n")
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
        puts "  middleware <name> [type]"
        puts "    Generate middleware for request/response processing"
        puts "    Example: azu generate middleware Authentication --type auth"
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
        puts "  validate"
        puts "    Validate Jinja template syntax in the project"
        puts "    Example: azu generate validate"
        puts
        puts "Options:"
        puts "  --force                    Overwrite existing files without prompting"
        puts "  --skip-tests               Skip generating test files"
        puts "  --api-only                 Generate API-only components (JSON responses)"
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
