require "./base"

module AzuCLI
  module Commands
    # Generate command for code generation
    class Generate < Base
      def initialize
        super("generate", "Generate code for your Azu project")
      end

      def execute : Result
        parse_args(get_args)

        unless validate_required_args(2)
          return error("Usage: azu generate <type> <name> [options] [attributes]")
        end

        generator_type = get_arg(0).not_nil!
        name = get_arg(1).not_nil!

        # Extract attributes from remaining arguments
        attributes = extract_attributes
        additional_args = extract_additional_args

        # Create generator options
        options = create_generator_options(attributes, additional_args)

        # Execute the appropriate generator
        execute_generator(generator_type, name, options)
      end

      private def extract_attributes : Hash(String, String)
        attributes = {} of String => String

        get_args[2..-1].each do |arg|
          if arg.includes?(":")
            parts = arg.split(":", 2)
            if parts.size == 2
              attributes[parts[0]] = parts[1]
            end
          end
        end

        attributes
      end

      private def extract_additional_args : Array(String)
        get_args[2..-1].reject { |arg| arg.includes?(":") }
      end

      private def create_generator_options(attributes : Hash(String, String), additional_args : Array(String)) : Generator::Core::GeneratorOptions
        options = Generator::Core::GeneratorOptions.new
        options.attributes = attributes
        options.additional_args = additional_args
        options.force = has_option?("force")
        options.skip_tests = has_option?("skip-tests")
        options.custom_options = extract_custom_options

        options
      end

      private def extract_custom_options : Hash(String, String)
        custom_options = {} of String => String

        # Extract type-specific options
        if type = get_option("type")
          custom_options["type"] = type
        end

        if api_only = get_option("api-only")
          custom_options["api-only"] = api_only
        end

        if web_only = get_option("web-only")
          custom_options["web-only"] = web_only
        end

        custom_options
      end

      private def execute_generator(type : String, name : String, options : Generator::Core::GeneratorOptions) : Result
        begin
          # Get project name from current directory or config
          project_name = get_project_name

          # Create and execute the appropriate generator
          generator = create_generator(type, name, project_name, options)
          result = generator.generate!

          Logger.info("✅ #{result}")
          success(result)
        rescue ex : ArgumentError
          error("Invalid generator arguments: #{ex.message}")
        rescue ex : File::Error
          error("File operation failed: #{ex.message}")
        rescue ex : Exception
          error("Generation failed: #{ex.message}")
        end
      end

      private def create_generator(type : String, name : String, project_name : String, options : Generator::Core::GeneratorOptions) : Generator::Core::AbstractGenerator
        case type.downcase
        when "model"
          Generator::ModelGenerator.new(name, project_name, options)
        when "endpoint"
          Generator::EndpointGenerator.new(name, project_name, options)
        when "service"
          Generator::ServiceGenerator.new(name, project_name, options)
        when "contract"
          Generator::ContractGenerator.new(name, project_name, options)
        when "page"
          Generator::PageGenerator.new(name, project_name, options)
        when "migration"
          Generator::MigrationGenerator.new(name, project_name, options)
        when "scaffold"
          Generator::ScaffoldGenerator.new(name, project_name, options)
        when "component"
          Generator::ComponentGenerator.new(name, project_name, options)
        when "middleware"
          Generator::MiddlewareGenerator.new(name, project_name, options)
        when "validator"
          Generator::ValidatorGenerator.new(name, project_name, options)
        when "channel"
          Generator::ChannelGenerator.new(name, project_name, options)
        when "handler"
          Generator::HandlerGenerator.new(name, project_name, options)
        when "request"
          Generator::RequestGenerator.new(name, project_name, options)
        when "response"
          Generator::ResponseGenerator.new(name, project_name, options)
        else
          raise ArgumentError.new("Unknown generator type: #{type}")
        end
      end

      private def get_project_name : String
        # Try to get project name from current directory
        current_dir = Dir.current
        project_name = File.basename(current_dir)

        # If we're in a typical project structure, try to find the main file
        if File.exists?(File.join(current_dir, "shard.yml"))
          # Read project name from shard.yml
          if content = File.read(File.join(current_dir, "shard.yml"))
            if match = content.match(/name:\s*(\w+)/)
              project_name = match[1]
            end
          end
        end

        project_name
      end

      def show_help
        puts "Usage: azu generate <type> <name> [options] [attributes]"
        puts
        puts "Generate code for your Azu project."
        puts
        puts "Generator Types:"
        puts "  model <name> [attr:type]     Generate a model with attributes"
        puts "  endpoint <name> [actions]    Generate endpoints with actions"
        puts "  service <name> [methods]     Generate a service with methods"
        puts "  contract <name> [attr:type]  Generate a contract with attributes"
        puts "  page <name> [attr:type]      Generate a page with template variables"
        puts "  migration <name> [attr:type] Generate a database migration"
        puts "  scaffold <name> [attr:type]  Generate a complete CRUD scaffold"
        puts "  component <name> [attr:type] Generate a component"
        puts "  middleware <name> [type]     Generate middleware"
        puts "  validator <name> [type]      Generate a custom validator"
        puts "  channel <name> [events]      Generate a WebSocket channel"
        puts "  handler <name> [type]        Generate a request handler"
        puts "  request <name> [attr:type]   Generate a request class"
        puts "  response <name> [attr:type]  Generate a response class"
        puts
        puts "Options:"
        puts "  --force                    Overwrite existing files"
        puts "  --skip-tests               Skip test file generation"
        puts "  --type <type>              Generator-specific type"
        puts "  --api-only                 Generate API-only components"
        puts "  --web-only                 Generate web-only components"
        puts
        puts "Examples:"
        puts "  azu generate model User name:string email:string age:int32"
        puts "  azu generate endpoint Users index show create update destroy"
        puts "  azu generate scaffold Post title:string content:text published:bool"
        puts "  azu generate service UserService create find update delete"
      end
    end
  end
end
