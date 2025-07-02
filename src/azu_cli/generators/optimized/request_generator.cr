require "../core/abstract_generator"

module AzuCLI::Generator
  class RequestGenerator < Core::AbstractGenerator
    property attributes : Hash(String, String)
    property request_type : String

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @attributes = options.attributes
      @request_type = options.custom_options["type"]? || "form"
      super(name, project_name, options.force, options.skip_tests)
    end

    def generator_type : String
      "request"
    end

    def generate_files : Nil
      generate_request_file
    end

    def create_directories : Nil
      super
      file_strategy.create_directory("src/requests")
      file_strategy.create_directory("spec/requests") unless skip_tests
    end

    def generate_tests : Nil
      return if skip_tests
      test_variables = generate_test_variables
      create_file_from_template(
        "request/request_spec.cr.ecr",
        "spec/requests/#{snake_case_name}_spec.cr",
        test_variables,
        "request test"
      )
    end

    private def generate_request_file : Nil
      request_variables = generate_request_variables
      create_file_from_template(
        "request/request.cr.ecr",
        "src/requests/#{snake_case_name}.cr",
        request_variables,
        "request"
      )
    end

    private def generate_request_variables : Hash(String, String)
      default_template_variables.merge({
        "validations" => generate_validations,
        "attributes_list" => generate_attributes_list,
        "request_type" => @request_type,
      })
    end

    private def generate_test_variables : Hash(String, String)
      default_template_variables.merge({
        "test_validations" => generate_test_validations,
        "request_type" => @request_type,
      })
    end

    private def generate_validations : String
      return "" if attributes.empty?

      lines = [] of String
      attributes.each do |attr_name, attr_type|
        validation_pattern = get_validation_for_type(attr_type)
        lines << validation_pattern % {field: attr_name}
      end

      lines.join("\n    ")
    end

    private def generate_attributes_list : String
      return "" if attributes.empty?

      lines = [] of String
      attributes.each do |attr_name, attr_type|
        crystal_type_name = crystal_type(attr_type)
        lines << "    property #{attr_name} : #{crystal_type_name}?"
      end

      lines.join("\n")
    end

    private def generate_test_validations : String
      return "" if attributes.empty?

      lines = [] of String
      attributes.each do |attr_name, _|
        lines << <<-CRYSTAL
        it "validates #{attr_name} presence" do
          request = #{class_name}.new
          request.#{attr_name} = nil
          request.valid?.should be_false
        end
        CRYSTAL
      end

      lines.join("\n\n")
    end

    private def get_validation_for_type(attr_type : String) : String
      validation_patterns = config.get_hash("validation_patterns")
      
      case attr_type.downcase
      when "string", "text"
        validation_patterns["presence"]? || "validate :%{field}, presence: true"
      when "email"
        validation_patterns["format"]? || "validate :%{field}, format: /\\A[\\w+\\-.]+@[a-z\\d\\-]+(\\.[a-z\\d\\-]+)*\\.[a-z]+\\z/i"
      else
        validation_patterns["presence"]? || "validate :%{field}, presence: true"
      end
    end

    def success_message : String
      base_message = super
      "#{base_message} with #{attributes.size} attribute(s)"
    end
  end
end