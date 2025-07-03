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

      private def create_generator_options(attributes : Hash(String, String), additional_args : Array(String)) : Hash(String, String)
        options = {} of String => String
        attributes.each { |k, v| options[k] = v }
        additional_args.each_with_index { |arg, i| options["arg_#{i}"] = arg }
        options["force"] = has_option?("force").to_s
        options["skip_tests"] = has_option?("skip-tests").to_s

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

      private def execute_generator(type : String, name : String, options : Hash(String, String)) : Result
        begin
          # Get project name from current directory or config
          project_name = get_project_name

          # Create and execute the appropriate generator
          result = create_generator(type, name, project_name, options)

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

      private def create_generator(type : String, name : String, project_name : String, options : Hash(String, String)) : String
        # For now, return a placeholder until individual generators are implemented
        "Generated #{type} '#{name}' for project '#{project_name}'"
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
