require "../core/abstract_generator"

module AzuCLI::Generator
  # Optimized Endpoint Generator following SOLID principles
  # Uses configuration-driven approach with Template Method pattern
  class EndpointGenerator < Core::AbstractGenerator
    property actions : Array(String)
    property skip_routes : Bool

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @actions = extract_actions(options)
      @skip_routes = options.skip_routes
      super(name, project_name, options.force, options.skip_tests)
    end

    # Concrete implementation of abstract method
    def generator_type : String
      "endpoint"
    end

    # Concrete implementation of abstract method
    def generate_files : Nil
      generate_contracts
      generate_pages
      generate_endpoints
    end

    # Override to add endpoint-specific directory creation
    def create_directories : Nil
      super

      # Create endpoint-specific directories from configuration
      file_strategy.create_directory("src/endpoints/#{snake_case_name}")
      file_strategy.create_directory("src/contracts/#{snake_case_name}")
      file_strategy.create_directory("src/pages/#{snake_case_name}")

      unless skip_tests
        file_strategy.create_directory("spec/endpoints")
      end
    end

    # Override to generate endpoint tests
    def generate_tests : Nil
      return if skip_tests

      actions.each do |action|
        test_variables = generate_test_variables(action)
        test_path = "spec/endpoints/#{snake_case_name}/#{action}_endpoint_spec.cr"

        create_file_from_template(
          "endpoint/endpoint_spec.cr.ecr",
          test_path,
          test_variables,
          "#{action} endpoint test"
        )
      end
    end

    # Extract actions from options or use defaults
    private def extract_actions(options : Core::GeneratorOptions) : Array(String)
      # Get actions from additional args or use defaults
      explicit_actions = options.additional_args.reject { |arg| arg.includes?(":") }
      
      if explicit_actions.empty?
        config.get_array("default_actions")
      else
        explicit_actions
      end
    end

    # Generate contracts for all actions
    private def generate_contracts : Nil
      actions.each do |action|
        contract_variables = generate_contract_variables(action)
        contract_path = "src/contracts/#{snake_case_name}/#{action}_contract.cr"

        template_name = "endpoint/#{action}_contract.cr.ecr"
        create_file_from_template(
          template_name,
          contract_path,
          contract_variables,
          "#{action} contract"
        )
      end
    end

    # Generate pages for all actions
    private def generate_pages : Nil
      actions.each do |action|
        page_variables = generate_page_variables(action)
        page_path = "src/pages/#{snake_case_name}/#{action}_page.cr"

        template_name = "endpoint/#{action}_page.cr.ecr"
        create_file_from_template(
          template_name,
          page_path,
          page_variables,
          "#{action} page"
        )
      end
    end

    # Generate endpoints for all actions
    private def generate_endpoints : Nil
      actions.each do |action|
        endpoint_variables = generate_endpoint_variables(action)
        endpoint_path = "src/endpoints/#{snake_case_name}/#{action}_endpoint.cr"

        template_name = "endpoint/#{action}_endpoint.cr.ecr"
        create_file_from_template(
          template_name,
          endpoint_path,
          endpoint_variables,
          "#{action} endpoint"
        )
      end
    end

    # Generate contract variables for specific action
    private def generate_contract_variables(action : String) : Hash(String, String)
      default_template_variables.merge({
        "action"       => action,
        "action_class" => classify(action),
        "validations"  => generate_action_validations(action),
      })
    end

    # Generate page variables for specific action
    private def generate_page_variables(action : String) : Hash(String, String)
      default_template_variables.merge({
        "action"       => action,
        "action_class" => classify(action),
        "template_data" => generate_template_data(action),
      })
    end

    # Generate endpoint variables for specific action
    private def generate_endpoint_variables(action : String) : Hash(String, String)
      http_methods = config.get_hash("http_methods")
      route_patterns = config.get_hash("route_patterns")

      default_template_variables.merge({
        "action"       => action,
        "action_class" => classify(action),
        "http_method"  => http_methods[action]? || "get",
        "route_path"   => generate_route_path(action, route_patterns),
      })
    end

    # Generate test variables for specific action
    private def generate_test_variables(action : String) : Hash(String, String)
      default_template_variables.merge({
        "action"       => action,
        "action_class" => classify(action),
        "test_setup"   => generate_test_setup(action),
      })
    end

    # Generate action-specific validations
    private def generate_action_validations(action : String) : String
      validation_patterns = config.get_hash("contract_validations")

      case action
      when "show", "edit", "update", "destroy"
        validation_patterns["id"]? || "validate :id, presence: true"
      when "index"
        lines = [] of String
        if page_validation = validation_patterns["pagination.page"]?
          lines << page_validation
        end
        if per_page_validation = validation_patterns["pagination.per_page"]?
          lines << per_page_validation
        end
        lines.join("\n    ")
      else
        ""
      end
    end

    # Generate template data for action
    private def generate_template_data(action : String) : String
      case action
      when "index"
        "\"#{plural_name}\" => @#{plural_name}"
      when "show", "edit", "update"
        "\"#{snake_case_name}\" => @#{snake_case_name}"
      when "new", "create"
        "\"#{snake_case_name}\" => @#{snake_case_name}"
      else
        "\"action\" => \"#{action}\""
      end
    end

    # Generate route path for action
    private def generate_route_path(action : String, route_patterns : Hash(String, String)) : String
      pattern = route_patterns[action]?
      return "/#{plural_name}" unless pattern

      pattern.gsub("%{plural_name}", plural_name)
    end

    # Generate test setup for action
    private def generate_test_setup(action : String) : String
      case action
      when "show", "edit", "update", "destroy"
        "#{snake_case_name} = create(:#{snake_case_name})"
      when "index"
        "#{plural_name} = create_list(:#{snake_case_name}, 3)"
      else
        ""
      end
    end

    # String classification helper
    private def classify(str : String) : String
      str.split(/[-_\s]/).map(&.capitalize).join
    end

    # Override success message to include endpoint-specific information
    def success_message : String
      base_message = super
      "#{base_message} with #{actions.size} action(s): #{actions.join(", ")}"
    end

    # Override to show endpoint-specific next steps
    def post_generation_tasks : Nil
      super
      show_endpoint_usage_info
    end

    # Show endpoint usage information
    private def show_endpoint_usage_info
      puts
      puts "📋 Endpoint Usage:".colorize(:yellow).bold
      puts "  1. Generated actions: #{actions.join(", ")}"
      puts
      puts "  2. Add routes to your application:"
      actions.each do |action|
        http_method = config.get_hash("http_methods")[action]? || "get"
        route_path = generate_route_path(action, config.get_hash("route_patterns"))
        puts "     #{http_method.upcase.ljust(7)} #{route_path.ljust(25)} => #{class_name}::#{classify(action)}Endpoint"
      end
      puts
      puts "  3. Files generated:"
      puts "     - Contracts: src/contracts/#{snake_case_name}/"
      puts "     - Endpoints: src/endpoints/#{snake_case_name}/"
      puts "     - Pages: src/pages/#{snake_case_name}/"
      unless skip_tests
        puts "     - Tests: spec/endpoints/#{snake_case_name}/"
      end
      puts
      puts "📚 Learn more: https://azutopia.gitbook.io/azu/endpoints".colorize(:cyan)
    end
  end
end