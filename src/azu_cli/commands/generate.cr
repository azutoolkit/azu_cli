require "./base"
require "option_parser"
require "../logger"
require "../generators/**"

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

      def initialize
        super("generate", "Generate code from templates")
      end

      def execute : Result
        parse_arguments

        # Validate required arguments
        unless validate_required_args(2)
          return error("Usage: azu generate <type> <name> [attributes] [options]")
        end

        @generator_type = get_arg(0).not_nil!
        @generator_name = get_arg(1).not_nil!

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
        when "contract"
          generate_contract
        when "page"
          generate_page
        when "job"
          generate_job
        when "middleware"
          generate_middleware
        when "migration"
          generate_migration
        when "component"
          generate_component
        when "validator"
          generate_validator
        when "request"
          generate_request
        when "response"
          generate_response
        when "template"
          generate_template
        when "scaffold"
          generate_scaffold
        else
          error("Unknown generator type: #{@generator_type}")
        end
      end

      private def parse_arguments
        OptionParser.parse(get_args) do |parser|
          parser.banner = "Usage: azu generate <type> <name> [attributes] [options]"

          parser.on("--force", "Overwrite existing files") { @force = true }
          parser.on("--api-only", "Generate API-only components") { @api_only = true }
          parser.on("--web-only", "Generate web-only components") { @web_only = true }
          parser.on("--skip-tests", "Skip test file generation") { @skip_tests = true }
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

        # For now, use component generator as service base
        # TODO: Create dedicated Service generator
        generator = AzuCLI::Generate::Component.new(
          name: @generator_name,
          properties: @attributes
        )

        render_generator(generator, AzuCLI::Generate::Component::OUTPUT_DIR)
        success("Generated service #{@generator_name} successfully")
      end

      private def generate_contract : Result
        Logger.info("Generating contract")

        # Use request generator for contracts (similar structure)
        generator = AzuCLI::Generate::Request.new(
          name: @generator_name,
          attributes: @attributes
        )

        render_generator(generator, AzuCLI::Generate::Request::OUTPUT_DIR)
        success("Generated contract #{@generator_name} successfully")
      end

      private def generate_page : Result
        Logger.info("Generating page with template")

        action = @actions.first? || "index"
        generator = AzuCLI::Generate::Page.new(
          name: @generator_name,
          fields: @attributes,
          action: action
        )

        render_generator(generator, AzuCLI::Generate::Page::OUTPUT_DIR)
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

      private def generate_request : Result
        Logger.info("Generating request")

        generator = AzuCLI::Generate::Request.new(
          name: @generator_name,
          attributes: @attributes
        )

        render_generator(generator, AzuCLI::Generate::Request::OUTPUT_DIR)
        success("Generated request #{@generator_name} successfully")
      end

      private def generate_response : Result
        Logger.info("Generating response")

        from_type = @options["from"]?

        generator = AzuCLI::Generate::Response.new(
          name: @generator_name,
          fields: @attributes,
          from_type: from_type
        )

        render_generator(generator, AzuCLI::Generate::Response::OUTPUT_DIR)
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

      private def generate_scaffold : Result
        Logger.info("Generating scaffold (complete CRUD)")

        # Scaffold generates multiple components
        # Model
        model_generator = AzuCLI::Generate::Model.new(
          name: @generator_name,
          attributes: @attributes
        )
        render_generator(model_generator, AzuCLI::Generate::Model::OUTPUT_DIR)

        # Endpoint
        endpoint_type = @api_only ? "api" : (@web_only ? "web" : "web")
        endpoint_generator = AzuCLI::Generate::Endpoint.new(
          name: @generator_name,
          actions: ["index", "show", "new", "create", "edit", "update", "destroy"],
          endpoint_type: endpoint_type,
          scaffold: true
        )
        # Endpoint generator has custom render method, but use proper output directory
        output_dir = AzuCLI::Generate::Endpoint::OUTPUT_DIR
        Dir.mkdir_p(output_dir) unless Dir.exists?(output_dir)
        endpoint_generator.render(output_dir)

        # Request and Response (for API) or Contract and Page (for web)
        if @api_only
          request_generator = AzuCLI::Generate::Request.new(@generator_name, @attributes)
          render_generator(request_generator, AzuCLI::Generate::Request::OUTPUT_DIR)

          response_generator = AzuCLI::Generate::Response.new(@generator_name, @attributes)
          render_generator(response_generator, AzuCLI::Generate::Response::OUTPUT_DIR)
        else
          # Generate contracts for each CRUD action
          ["index", "show", "new", "create", "edit", "update", "destroy"].each do |action|
            contract_generator = AzuCLI::Generate::Request.new("#{@generator_name}_#{action}", @attributes)
            render_generator(contract_generator, AzuCLI::Generate::Request::OUTPUT_DIR)
          end

          # Generate pages for each CRUD action
          ["index", "show", "new", "edit"].each do |action|
            page_generator = AzuCLI::Generate::Page.new(@generator_name, @attributes, action)
            render_generator(page_generator, AzuCLI::Generate::Page::OUTPUT_DIR)
          end
        end

        Logger.info("✅ Scaffold generation completed")
        success("Generated scaffold #{@generator_name} successfully")
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
        puts "Generate code for your Azu project."
        puts
        puts "Generator Types:"
        puts "  model <name> [attr:type]     Generate a model with attributes"
        puts "  endpoint <name> [actions]    Generate endpoints with actions"
        puts "  service <name> [methods]     Generate a service with methods"
        puts "  contract <name> [attr:type]  Generate a contract with attributes"
        puts "  page <name> [attr:type]      Generate a page with template variables"
        puts "  job <name> [param:type]      Generate a background job"
        puts "  middleware <name> [type]     Generate middleware"
        puts "  migration <name> [attr:type] Generate a database migration"
        puts "  component <name> [attr:type] Generate a component"
        puts "  validator <name> [type]      Generate a custom validator"
        puts "  request <name> [attr:type]   Generate a request class"
        puts "  response <name> [attr:type]  Generate a response class"
        puts "  template <name> [attr:type]  Generate a Jinja2 template"
        puts "  scaffold <name> [attr:type]  Generate a complete CRUD scaffold"
        puts
        puts "Options:"
        puts "  --force                    Overwrite existing files"
        puts "  --skip-tests               Skip test file generation"
        puts "  --api-only                 Generate API-only components"
        puts "  --web-only                 Generate web-only components"
        puts
        puts "Attribute Format:"
        puts "  name:string email:string age:int32 published:bool"
        puts
        puts "Examples:"
        puts "  azu generate model User name:string email:string age:int32"
        puts "  azu generate endpoint Users index show create update destroy"
        puts "  azu generate scaffold Post title:string content:text published:bool"
        puts "  azu generate job EmailNotification user_id:int32 template:string"
        puts "  azu generate middleware Authentication --type auth"
        puts "  azu generate page UserProfile name:string email:string"
        puts
        puts "Scaffold generates:"
        puts "  - Model with migration"
        puts "  - CRUD endpoints"
        puts "  - Request/Response classes (API mode)"
        puts "  - Contract/Page classes (Web mode)"
      end
    end
  end
end
