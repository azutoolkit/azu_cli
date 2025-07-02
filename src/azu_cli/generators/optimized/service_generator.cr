require "../core/abstract_generator"

module AzuCLI::Generator
  # Optimized Service Generator following SOLID principles
  class ServiceGenerator < Core::AbstractGenerator
    property service_type : String
    property methods : Array(String)
    property with_interface : Bool

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @service_type = options.custom_options["type"]? || "domain"
      @methods = extract_methods(options)
      @with_interface = options.custom_options["interface"]? != "false"
      super(name, project_name, options.force, options.skip_tests)
    end

    def generator_type : String
      "service"
    end

    def generate_files : Nil
      generate_service_file
      generate_interface_file if @with_interface
    end

    def create_directories : Nil
      super
      file_strategy.create_directory("src/services")
      file_strategy.create_directory("src/interfaces") if @with_interface
      file_strategy.create_directory("spec/services") unless skip_tests
    end

    def generate_tests : Nil
      return if skip_tests
      test_variables = generate_test_variables
      create_file_from_template(
        "service/service_spec.cr.ecr",
        "spec/services/#{snake_case_name}_service_spec.cr",
        test_variables,
        "service test"
      )
    end

    private def generate_service_file : Nil
      service_variables = generate_service_variables
      create_file_from_template(
        "service/service.cr.ecr",
        "src/services/#{snake_case_name}_service.cr",
        service_variables,
        "service"
      )
    end

    private def generate_interface_file : Nil
      return unless @with_interface

      interface_variables = generate_interface_variables
      interface_prefix = config.get("interface.prefix") || "I"
      interface_name = interface_prefix + class_name + "Service"

      create_file_from_template(
        "service/interface.cr.ecr",
        "src/interfaces/#{snake_case_name}_service_interface.cr",
        interface_variables,
        "service interface"
      )
    end

    private def generate_service_variables : Hash(String, String)
      default_template_variables.merge({
        "service_type"      => @service_type,
        "methods_list"      => generate_methods_list,
        "dependencies"      => generate_dependencies,
        "error_handling"    => generate_error_handling,
        "interface_include" => generate_interface_include,
      })
    end

    private def generate_interface_variables : Hash(String, String)
      interface_prefix = config.get("interface.prefix") || "I"

      default_template_variables.merge({
        "interface_name"   => interface_prefix + class_name + "Service",
        "abstract_methods" => generate_abstract_methods,
      })
    end

    private def generate_test_variables : Hash(String, String)
      default_template_variables.merge({
        "test_methods"      => generate_test_methods,
        "service_type"      => @service_type,
        "mock_dependencies" => generate_mock_dependencies,
      })
    end

    private def extract_methods(options : Core::GeneratorOptions) : Array(String)
      explicit_methods = options.additional_args.reject { |arg| arg.includes?(":") }

      if explicit_methods.empty?
        # Get methods from configuration - first try service type specific, then defaults
        config.get_array("service_types.#{@service_type}.methods").tap do |methods|
          return methods unless methods.empty?
        end
        config.get_array("default_methods")
      else
        explicit_methods
      end
    end

    private def generate_methods_list : String
      lines = [] of String

      methods.each do |method_name|
        if pattern = config.get("method_patterns.#{method_name}")
          lines << pattern % {return_type: determine_return_type(method_name)}
        else
          lines << generate_custom_method(method_name)
        end
      end

      lines.join("\n\n")
    end

    private def generate_custom_method(method_name : String) : String
      return_type = determine_return_type(method_name)

      <<-CRYSTAL
      def #{method_name}(*args) : #{return_type}
        Log.info { "#{class_name}Service: #{method_name} called" }
        # TODO: Implement #{method_name} logic
        raise NotImplementedError.new("#{method_name} not implemented")
      end
      CRYSTAL
    end

    private def determine_return_type(method_name : String) : String
      case method_name
      when "create", "find", "update"
        if template = config.get("return_types.model")
          template % {model_name: extract_model_name}
        else
          "Bool"
        end
      when "delete", "valid?"
        "Bool"
      when "list"
        if template = config.get("return_types.array")
          template % {model_name: extract_model_name}
        else
          "Array(String)"
        end
      else
        "Bool"
      end
    end

    private def extract_model_name : String
      # Try to extract model name from service name
      service_name_without_suffix = name.gsub(/Service$/, "")
      service_name_without_suffix.gsub(/Registration$|Processor$|Manager$/, "")
    end

    private def generate_dependencies : String
      lines = [] of String

      dependency_patterns = config.get_hash("dependency_injection")
      dependency_patterns.each do |dep_type, pattern|
        case dep_type
        when "repository"
          model_name = extract_model_name
          if pattern.includes?("%{model_name}")
            lines << pattern % {model_name: model_name}
          else
            lines << pattern
          end
        when "logger"
          lines << pattern
        when "validator"
          model_name = extract_model_name
          if pattern.includes?("%{model_name}")
            lines << pattern % {model_name: model_name}
          else
            lines << pattern
          end
        end
      end

      lines.join("\n  ")
    end

    private def generate_error_handling : String
      error_handling = config.get_hash("error_handling")

      lines = [] of String
      error_handling.each do |error_type, error_class|
        lines << "class #{error_class} < Exception; end"
      end

      lines.join("\n")
    end

    private def generate_interface_include : String
      return "" unless @with_interface

      interface_prefix = config.get("interface.prefix") || "I"
      "include #{interface_prefix}#{class_name}Service"
    end

    private def generate_abstract_methods : String
      lines = [] of String

      methods.each do |method_name|
        return_type = determine_return_type(method_name)
        lines << "abstract def #{method_name}(*args) : #{return_type}"
      end

      lines.join("\n  ")
    end

    private def generate_test_methods : String
      lines = [] of String

      methods.each do |method_name|
        lines << <<-CRYSTAL
        describe "##{method_name}" do
          it "implements #{method_name} logic" do
            service = #{class_name}Service.new
            # TODO: Add test for #{method_name}
            service.should respond_to(:#{method_name})
          end
        end
        CRYSTAL
      end

      lines.join("\n\n")
    end

    private def generate_mock_dependencies : String
      dependency_patterns = config.get_hash("dependency_injection")

      lines = [] of String
      dependency_patterns.each do |dep_type, pattern|
        case dep_type
        when "repository"
          model_name = extract_model_name
          lines << "let(#{dep_type}) { Mock#{model_name}Repository.new }"
        when "validator"
          model_name = extract_model_name
          lines << "let(#{dep_type}) { Mock#{model_name}Validator.new }"
        end
      end

      lines.join("\n    ")
    end

    def success_message : String
      base_message = super
      features = [] of String
      features << "#{methods.size} method(s)" unless methods.empty?
      features << "interface" if @with_interface
      features << @service_type + " type"

      feature_text = features.empty? ? "" : " with #{features.join(", ")}"
      "#{base_message}#{feature_text}"
    end

    def post_generation_tasks : Nil
      super
      puts
      puts "🔧 Service Usage:".colorize(:yellow).bold
      puts "  1. Implement service methods in src/services/#{snake_case_name}_service.cr"
      puts "  2. Add dependency injection for repositories and validators"
      puts "  3. Use in your endpoints:"
      puts "     service = #{class_name}Service.new"
      puts "     result = service.#{methods.first? || "call"}"
      puts
      puts "📚 Learn more: https://azutopia.gitbook.io/azu/services".colorize(:cyan)
    end
  end
end
