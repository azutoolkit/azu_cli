require "../core/abstract_generator"

module AzuCLI::Generator
  # Optimized Validator Generator following SOLID principles
  class ValidatorGenerator < Core::AbstractGenerator
    property validator_type : String
    property pattern : String?
    property parameters : Hash(String, String)

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @validator_type = options.custom_options["type"]? || "custom"
      @pattern = options.custom_options["pattern"]?
      @parameters = extract_parameters(options)
      super(name, project_name, options.force, options.skip_tests)
    end

    def generator_type : String
      "validator"
    end

    def generate_files : Nil
      generate_validator_file
    end

    def create_directories : Nil
      super
      file_strategy.create_directory("src/validators")
      file_strategy.create_directory("spec/validators") unless skip_tests
    end

    def generate_tests : Nil
      return if skip_tests
      test_variables = generate_test_variables
      create_file_from_template(
        "validator/validator_spec.cr.ecr",
        "spec/validators/#{snake_case_name}_validator_spec.cr",
        test_variables,
        "validator test"
      )
    end

    private def generate_validator_file : Nil
      validator_variables = generate_validator_variables
      create_file_from_template(
        "validator/validator.cr.ecr",
        "src/validators/#{snake_case_name}_validator.cr",
        validator_variables,
        "validator"
      )
    end

    private def generate_validator_variables : Hash(String, String)
      default_template_variables.merge({
        "validator_type" => @validator_type,
        "base_class" => config.get("base_validator.class") || "CQL::Validator",
        "validation_logic" => generate_validation_logic,
        "error_message" => generate_error_message,
        "parameters" => generate_parameters_code,
        "initialize_method" => generate_initialize_method,
      })
    end

    private def generate_test_variables : Hash(String, String)
      default_template_variables.merge({
        "validator_type" => @validator_type,
        "test_cases" => generate_test_cases,
        "valid_values" => generate_valid_values,
        "invalid_values" => generate_invalid_values,
      })
    end

    private def extract_parameters(options : Core::GeneratorOptions) : Hash(String, String)
      params = {} of String => String

      options.additional_args.each do |arg|
        if arg.includes?(":")
          parts = arg.split(":", 2)
          if parts.size == 2
            params[parts[0]] = parts[1]
          end
        end
      end

      # Add pattern if provided directly
      if @pattern
        params["pattern"] = @pattern.not_nil!
      end

      params
    end

    private def generate_validation_logic : String
      validator_config = config.get_hash("validator_types.#{@validator_type}")

      if validation_pattern = config.get("validation_patterns.#{@validator_type}_validation")
        substitute_pattern_variables(validation_pattern)
      else
        generate_custom_validation_logic
      end
    end

    private def substitute_pattern_variables(pattern : String) : String
      result = pattern

      # Substitute common patterns
      case @validator_type
      when "regex", "format"
        if pattern_value = (@pattern || parameters["pattern"]?)
          result = result.gsub("%{pattern}", pattern_value)
        end
      when "range"
        if min = parameters["min"]?
          result = result.gsub("%{min}", min)
        end
        if max = parameters["max"]?
          result = result.gsub("%{max}", max)
        end
      when "uniqueness"
        if model = parameters["model"]?
          result = result.gsub("%{model_class}", model)
        end
        if column = parameters["column"]?
          result = result.gsub("%{column}", column)
        end
      end

      result
    end

    private def generate_custom_validation_logic : String
      <<-CRYSTAL
      def validate(value : String, context : CQL::ValidationContext) : Bool
        return true if value.nil? || value.empty?

        # TODO: Implement custom validation logic
        # Return true if valid, false if invalid
        true
      end
      CRYSTAL
    end

    private def generate_error_message : String
      validator_config = config.get_hash("validator_types.#{@validator_type}")

      if error_msg = validator_config["error_message"]?.try(&.as_s)
        substitute_error_message_variables(error_msg)
      else
        config.get("error_message_patterns.custom") || "is invalid"
      end
    end

    private def substitute_error_message_variables(message : String) : String
      result = message

      case @validator_type
      when "range"
        if min = parameters["min"]?
          result = result.gsub("%{min}", min)
        end
        if max = parameters["max"]?
          result = result.gsub("%{max}", max)
        end
      when "length"
        if min = parameters["min"]?
          result = result.gsub("%{min}", min)
        end
        if max = parameters["max"]?
          result = result.gsub("%{max}", max)
        end
      end

      result
    end

    private def generate_parameters_code : String
      return "" if parameters.empty?

      lines = [] of String

      parameter_configs = config.get_hash("configuration_parameters.#{@validator_type}")

      parameters.each do |param_name, param_value|
        if param_type = parameter_configs[param_name]?
          lines << "property #{param_name} : #{param_type}"
        else
          lines << "property #{param_name} : String"
        end
      end

      lines.join("\n  ")
    end

    private def generate_initialize_method : String
      return "" if parameters.empty?

      param_list = parameters.keys.map { |key| "@#{key} : #{get_param_type(key)}" }.join(", ")
      assignments = parameters.keys.map { |key| "@#{key} = #{key}" }.join("\n    ")

      <<-CRYSTAL
      def initialize(#{param_list})
        #{assignments}
      end
      CRYSTAL
    end

    private def get_param_type(param_name : String) : String
      parameter_configs = config.get_hash("configuration_parameters.#{@validator_type}")
      parameter_configs[param_name]?.try(&.as_s) || "String"
    end

    private def generate_test_cases : String
      lines = [] of String

      lines << generate_presence_test if @validator_type != "presence"
      lines << generate_type_specific_tests

      lines.join("\n\n")
    end

    private def generate_presence_test : String
      <<-CRYSTAL
      it "returns true for nil or empty values" do
        validator = #{class_name}Validator.new#{generate_test_parameters}
        validator.validate(nil, context).should be_true
        validator.validate("", context).should be_true
      end
      CRYSTAL
    end

    private def generate_type_specific_tests : String
      case @validator_type
      when "email"
        <<-CRYSTAL
        it "validates email format" do
          validator = #{class_name}Validator.new#{generate_test_parameters}
          validator.validate("user@example.com", context).should be_true
          validator.validate("invalid-email", context).should be_false
        end
        CRYSTAL
      when "phone"
        <<-CRYSTAL
        it "validates phone format" do
          validator = #{class_name}Validator.new#{generate_test_parameters}
          validator.validate("+1 (555) 123-4567", context).should be_true
          validator.validate("invalid-phone", context).should be_false
        end
        CRYSTAL
      when "url"
        <<-CRYSTAL
        it "validates URL format" do
          validator = #{class_name}Validator.new#{generate_test_parameters}
          validator.validate("https://example.com", context).should be_true
          validator.validate("invalid-url", context).should be_false
        end
        CRYSTAL
      when "range"
        <<-CRYSTAL
        it "validates numeric range" do
          validator = #{class_name}Validator.new#{generate_test_parameters}
          validator.validate("50", context).should be_true
          validator.validate("150", context).should be_false
        end
        CRYSTAL
      else
        <<-CRYSTAL
        it "validates custom logic" do
          validator = #{class_name}Validator.new#{generate_test_parameters}
          # TODO: Add specific test cases for #{@validator_type} validation
          validator.validate("valid_value", context).should be_true
        end
        CRYSTAL
      end
    end

    private def generate_test_parameters : String
      return "" if parameters.empty?

      test_params = case @validator_type
                   when "range"
                     "(min: 0.0, max: 100.0)"
                   when "length"
                     "(min: 2, max: 50)"
                   when "uniqueness"
                     "(model_class: User, column: \"email\")"
                   when "regex"
                     "(pattern: /\\A[A-Z]{2,3}\\z/)"
                   else
                     ""
                   end

      test_params
    end

    private def generate_valid_values : String
      case @validator_type
      when "email"
        '["user@example.com", "test.email@domain.co.uk"]'
      when "phone"
        '["+1 (555) 123-4567", "555-123-4567"]'
      when "url"
        '["https://example.com", "http://test.org"]'
      when "range"
        '["50", "25", "75"]'
      else
        '["valid_value"]'
      end
    end

    private def generate_invalid_values : String
      case @validator_type
      when "email"
        '["invalid-email", "user@", "@domain.com"]'
      when "phone"
        '["invalid-phone", "123", "abcd"]'
      when "url"
        '["invalid-url", "not-a-url", "ftp://example.com"]'
      when "range"
        '["150", "-10", "abc"]'
      else
        '["invalid_value"]'
      end
    end

    def success_message : String
      base_message = super
      features = [] of String
      features << @validator_type + " type"
      features << "#{parameters.size} parameter(s)" unless parameters.empty?

      feature_text = features.empty? ? "" : " with #{features.join(", ")}"
      "#{base_message}#{feature_text}"
    end

    def post_generation_tasks : Nil
      super
      puts
      puts "✅ Validator Usage:".colorize(:yellow).bold
      puts "  1. Use in CQL models:"
      puts "     validate :field, with: #{class_name}Validator.new#{generate_example_usage}"
      puts "  2. Use in request contracts:"
      puts "     validate :field, custom: #{class_name}Validator"
      puts "  3. Test your validator in spec/validators/#{snake_case_name}_validator_spec.cr"
      puts
      puts "📚 Learn more: https://github.com/azutoolkit/cql#validations".colorize(:cyan)
    end

    private def generate_example_usage : String
      case @validator_type
      when "range"
        "(min: 0.0, max: 100.0)"
      when "length"
        "(min: 2, max: 50)"
      when "regex"
        "(pattern: /\\A[A-Z]{2,3}\\z/)"
      else
        ""
      end
    end
  end
end
