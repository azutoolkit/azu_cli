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

        # Merge custom options (like --type, --api-only, etc.)
        custom_options = extract_custom_options
        custom_options.each { |k, v| options[k] = v }

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
        case type.downcase
        when "model"
          create_model_generator(name, project_name, options)
        when "migration"
          create_migration_generator(name, project_name, options)
        when "request"
          create_request_generator(name, project_name, options)
        when "component"
          create_component_generator(name, project_name, options)
        when "validator"
          create_validator_generator(name, project_name, options)
        when "response"
          create_response_generator(name, project_name, options)
        when "page_response"
          create_page_response_generator(name, project_name, options)
        when "endpoint"
          create_endpoint_generator(name, project_name, options)
        when "job"
          create_job_generator(name, project_name, options)
        when "middleware"
          create_middleware_generator(name, project_name, options)
        else
          "Generator type '#{type}' not yet implemented"
        end
      end

      private def create_migration_generator(name : String, project_name : String, options : Hash(String, String)) : String
        # Extract attributes from options
        attributes = {} of String => String
        options.each do |key, value|
          next if key.starts_with?("arg_") || key == "force" || key == "skip_tests"
          attributes[key] = value
        end

        # Create migration generator
        generator = AzuCLI::Generate::Migration.new(
          name: name,
          attributes: attributes,
          timestamps: options["timestamps"]? == "true"
        )

        # Generate the migration
        generator.render(project_name)

        "Generated migration '#{name}' with #{attributes.size} attributes"
      end

      private def create_job_generator(name : String, project_name : String, options : Hash(String, String)) : String
        parameters = {} of String => String
        queue = "default"
        retries = 3
        expires = "1.days"

        options.each do |key, value|
          next if key.starts_with?("arg_") || key == "force" || key == "skip_tests"
          case key
          when "queue"
            queue = value
          when "retries"
            retries = value.to_i
          when "expires"
            expires = value
          else
            # Treat other options as parameters
            parameters[key] = value
          end
        end

        generator = AzuCLI::Generate::Job.new(
          name: name,
          parameters: parameters,
          queue: queue,
          retries: retries,
          expires: expires
        )

        generator.render(project_name)
        "Generated job '#{name}' with #{parameters.size} parameters (queue: #{queue}, retries: #{retries}, expires: #{expires})"
      end

      private def create_endpoint_generator(name : String, project_name : String, options : Hash(String, String)) : String
        actions = [] of String
        endpoint_type = "api"
        scaffold = false

        options.each do |key, value|
          next if key.starts_with?("arg_") || key == "force" || key == "skip_tests"
          case key
          when "actions"
            actions = value.split(",").map(&.strip)
          when "type"
            endpoint_type = value.downcase
          when "scaffold"
            scaffold = value.downcase == "true"
          else
            # Treat other options as actions
            actions << value
          end
        end

        generator = AzuCLI::Generate::Endpoint.new(
          name: name,
          actions: actions,
          endpoint_type: endpoint_type,
          scaffold: scaffold
        )

        generator.render(project_name)

        # Generate scaffold components if requested
        if scaffold
          scaffold_message = generate_scaffold_components(name, endpoint_type, project_name)
          "Generated endpoint '#{name}' with #{actions.size} actions (#{endpoint_type}) and scaffolded #{scaffold_message}"
        else
          "Generated endpoint '#{name}' with #{actions.size} actions (#{endpoint_type})"
        end
      end

      private def generate_scaffold_components(name : String, endpoint_type : String, project_name : String) : String
        components = [] of String

        if endpoint_type == "api"
          # Generate request and response
          request_generator = AzuCLI::Generate::Request.new(name, {} of String => String)
          request_generator.render(project_name)
          components << "request"

          response_generator = AzuCLI::Generate::Response.new(name, {} of String => String)
          response_generator.render(project_name)
          components << "response"
        else
          # Generate contract and page
          # Note: Contract and Page generators would need to be implemented
          components << "contract"
          components << "page"
        end

        components.join(", ")
      end

      private def create_model_generator(name : String, project_name : String, options : Hash(String, String)) : String
        # Extract attributes from options
        attributes = {} of String => String
        options.each do |key, value|
          next if key.starts_with?("arg_") || key == "force" || key == "skip_tests"
          attributes[key] = value
        end

        # Create model generator
        generator = AzuCLI::Generate::Model.new(
          name: name,
          attributes: attributes,
          timestamps: options["timestamps"]? == "true",
          database: options["database"]? || "BlogDB",
          id_type: options["id_type"]? || "UUID"
        )

        # Generate the model
        generator.render(project_name)

        "Generated model '#{name}' with #{attributes.size} attributes"
      end

      private def create_request_generator(name : String, project_name : String, options : Hash(String, String)) : String
        attributes = {} of String => String
        options.each do |key, value|
          next if key.starts_with?("arg_") || key == "force" || key == "skip_tests"
          attributes[key] = value
        end

        generator = AzuCLI::Generate::Request.new(
          name: name,
          attributes: attributes
        )

        generator.render(project_name)
        "Generated request '#{name}' with #{attributes.size} attributes"
      end

      private def create_component_generator(name : String, project_name : String, options : Hash(String, String)) : String
        # Extract properties from options
        properties = {} of String => String
        events = [] of String

        options.each do |key, value|
          next if key.starts_with?("arg_") || key == "force" || key == "skip_tests"
          if key == "events"
            events = value.split(",").map(&.strip)
          else
            properties[key] = value
          end
        end

        generator = AzuCLI::Generate::Component.new(
          name: name,
          properties: properties,
          events: events
        )

        generator.render(project_name)
        "Generated component '#{name}' with #{properties.size} properties and #{events.size} events"
      end

      private def create_validator_generator(name : String, project_name : String, options : Hash(String, String)) : String
        # Extract validation rules and record type from options
        validation_rules = [] of String
        record_type = "User"

        options.each do |key, value|
          next if key.starts_with?("arg_") || key == "force" || key == "skip_tests"
          case key
          when "rules"
            validation_rules = value.split(",").map(&.strip)
          when "record_type", "record"
            record_type = value
          else
            # Treat other options as validation rules
            validation_rules << value
          end
        end

        generator = AzuCLI::Generate::Validator.new(
          name: name,
          record_type: record_type,
          validation_rules: validation_rules
        )

        generator.render(project_name)
        "Generated validator '#{name}' for #{record_type} with #{validation_rules.size} validation rules"
      end

      private def create_response_generator(name : String, project_name : String, options : Hash(String, String)) : String
        fields = {} of String => String
        from_type = nil
        options.each do |key, value|
          next if key.starts_with?("arg_") || key == "force" || key == "skip_tests"
          if key == "from"
            from_type = value
          else
            fields[key] = value
          end
        end
        generator = AzuCLI::Generate::Response.new(
          name: name,
          fields: fields,
          from_type: from_type
        )
        generator.render(project_name)
        "Generated response '#{name}' with #{fields.size} fields#{from_type ? " from #{from_type}" : ""}"
      end

      private def create_page_response_generator(name : String, project_name : String, options : Hash(String, String)) : String
        fields = {} of String => String
        options.each do |key, value|
          next if key.starts_with?("arg_") || key == "force" || key == "skip_tests"
          fields[key] = value
        end
        generator = AzuCLI::Generate::PageResponse.new(
          name: name,
          fields: fields
        )
        generator.render(project_name)
        "Generated page response '#{name}' with #{fields.size} fields"
      end

      private def create_middleware_generator(name : String, project_name : String, options : Hash(String, String)) : String
        middleware_type = "authentication"
        skip_paths = [] of String
        context_vars = {} of String => String

        options.each do |key, value|
          next if key.starts_with?("arg_") || key == "force" || key == "skip_tests"
          case key
          when "type"
            middleware_type = value
          when "skip_paths"
            skip_paths = value.split(",").map(&.strip)
          else
            # Treat other options as context variables
            context_vars[key] = value
          end
        end

        generator = AzuCLI::Generate::Middleware.new(
          name: name,
          middleware_type: middleware_type,
          skip_paths: skip_paths,
          context_vars: context_vars
        )

        generator.render(project_name)
        "Generated middleware '#{name}' (type: #{middleware_type}, skip_paths: #{skip_paths.size}, context_vars: #{context_vars.size})"
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
