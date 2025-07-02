require "../core/abstract_generator"

module AzuCLI::Generator
  class HandlerGenerator < Core::AbstractGenerator
    property handler_type : String

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @handler_type = options.custom_options["type"]? || "custom"
      super(name, project_name, options.force, options.skip_tests)
    end

    def generator_type : String
      "handler"
    end

    def generate_files : Nil
      generate_handler_file
    end

    def create_directories : Nil
      super
      file_strategy.create_directory("src/handlers")
      file_strategy.create_directory("spec/handlers") unless skip_tests
    end

    def generate_tests : Nil
      return if skip_tests
      test_variables = generate_test_variables
      create_file_from_template(
        "handler/handler_spec.cr.ecr",
        "spec/handlers/#{snake_case_name}_spec.cr",
        test_variables,
        "handler test"
      )
    end

    private def generate_handler_file : Nil
      handler_variables = generate_handler_variables
      create_file_from_template(
        "handler/handler.cr.ecr",
        "src/handlers/#{snake_case_name}.cr",
        handler_variables,
        "handler"
      )
    end

    private def generate_handler_variables : Hash(String, String)
      default_template_variables.merge({
        "handler_implementation" => generate_handler_implementation,
        "handler_type"           => @handler_type,
        "helper_methods"         => generate_helper_methods,
      })
    end

    private def generate_test_variables : Hash(String, String)
      default_template_variables.merge({
        "test_methods" => generate_test_methods,
        "handler_type" => @handler_type,
      })
    end

    private def generate_handler_implementation : String
      case @handler_type
      when "auth"
        generate_auth_handler
      when "cors"
        generate_cors_handler
      else
        generate_custom_handler
      end
    end

    private def generate_auth_handler : String
      <<-CRYSTAL
      def call(context : HTTP::Server::Context)
        # Extract and validate authentication
        token = extract_auth_token(context)

        unless authenticated?(token)
          return unauthorized_response(context)
        end

        # Set user context
        if user = get_user_from_token(token)
          context.set("current_user", user)
        end

        call_next(context)
      end
      CRYSTAL
    end

    private def generate_cors_handler : String
      <<-CRYSTAL
      def call(context : HTTP::Server::Context)
        set_cors_headers(context)

        if context.request.method == "OPTIONS"
          context.response.status = HTTP::Status::OK
          return
        end

        call_next(context)
      end
      CRYSTAL
    end

    private def generate_custom_handler : String
      <<-CRYSTAL
      def call(context : HTTP::Server::Context)
        # Pre-processing logic
        before_request(context)

        # Call next handler
        call_next(context)

        # Post-processing logic
        after_response(context)
      end
      CRYSTAL
    end

    private def generate_helper_methods : String
      <<-CRYSTAL

      private def before_request(context : HTTP::Server::Context)
        Log.info { "#{self.class.name}: Processing request" }
      end

      private def after_response(context : HTTP::Server::Context)
        Log.info { "#{self.class.name}: Request completed" }
      end
      CRYSTAL
    end

    private def generate_test_methods : String
      <<-CRYSTAL
      it "processes requests correctly" do
        context = create_test_context("GET", "/")
        handler.call(context)
        # Add assertions
      end
      CRYSTAL
    end

    def success_message : String
      base_message = super
      "#{base_message} of type '#{@handler_type}'"
    end
  end
end
