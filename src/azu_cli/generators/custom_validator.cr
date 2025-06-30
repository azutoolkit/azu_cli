require "./base"

module AzuCLI
  module Generator
    class CustomValidator < Base
      getter attributes : Hash(String, String)
      getter validation_type : String
      getter model_name : String

      def initialize(@name : String, @project_name : String, @validation_type = "custom", @model_name = "", @attributes = Hash(String, String).new, @force = false, @skip_tests = false)
        super(name, project_name, force, skip_tests)
        validate_name!
      end

      def generate!
        create_directories
        generate_validator
        generate_tests unless skip_tests

        puts "  🔍 Generated #{class_name}Validator".colorize(:green)
        show_validator_usage_info
      end

      private def create_directories
        ensure_directory("src/validators")
        ensure_directory("spec/validators") unless skip_tests
      end

      private def generate_validator
        template_variables = {
          "validation_type"      => validation_type,
          "model_name"          => model_name,
          "validator_method"    => generate_validator_method,
          "validation_logic"    => generate_validation_logic,
          "attributes_list"     => generate_attributes_list,
          "error_message"       => generate_error_message,
        }

        copy_template(
          "generators/custom_validator/custom_validator.cr.ecr",
          "src/validators/#{snake_case_name}_validator.cr",
          template_variables
        )
      end

      private def generate_tests
        template_variables = {
          "test_cases"          => generate_test_cases,
          "valid_examples"      => generate_valid_examples,
          "invalid_examples"    => generate_invalid_examples,
          "model_name"          => model_name,
        }

        copy_template(
          "generators/custom_validator/custom_validator_spec.cr.ecr",
          "spec/validators/#{snake_case_name}_validator_spec.cr",
          template_variables
        )
      end

      private def generate_validator_method : String
        case validation_type.downcase
        when "email"
          generate_email_validator
        when "phone"
          generate_phone_validator
        when "url"
          generate_url_validator
        when "regex", "pattern"
          generate_regex_validator
        when "range"
          generate_range_validator
        when "custom"
          generate_custom_validator
        else
          generate_custom_validator
        end
      end

      private def generate_email_validator : String
        <<-CRYSTAL
        def self.validate_email(value : String) : Bool
          # Email validation regex pattern
          email_regex = /\A[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\z/
          !value.empty? && email_regex.matches?(value)
        end
        CRYSTAL
      end

      private def generate_phone_validator : String
        <<-CRYSTAL
        def self.validate_phone(value : String) : Bool
          # Phone number validation (supports multiple formats)
          # Allows +1-555-123-4567, (555) 123-4567, 555.123.4567, 5551234567
          phone_regex = /\A(?:\+?1[-.\s]?)?\(?([0-9]{3})\)?[-.\s]?([0-9]{3})[-.\s]?([0-9]{4})\z/
          !value.empty? && phone_regex.matches?(value.gsub(/\s+/, ""))
        end
        CRYSTAL
      end

      private def generate_url_validator : String
        <<-CRYSTAL
        def self.validate_url(value : String) : Bool
          # URL validation regex
          url_regex = /\Ahttps?:\/\/(?:[-\w.])+(?:\:[0-9]+)?(?:\/(?:[\w\/_.])*)?(?:\?(?:[\w&=%.])*)?(?:\#(?:[\w.])*)?\\z/
          !value.empty? && url_regex.matches?(value)
        end
        CRYSTAL
      end

      private def generate_regex_validator : String
        pattern = attributes["pattern"]? || "\\A[a-zA-Z0-9]+\\z"
        <<-CRYSTAL
        def self.validate_pattern(value : String) : Bool
          # Custom regex pattern validation
          pattern = /#{pattern}/
          !value.empty? && pattern.matches?(value)
        end
        CRYSTAL
      end

      private def generate_range_validator : String
        min_val = attributes["min"]? || "0"
        max_val = attributes["max"]? || "100"
        <<-CRYSTAL
        def self.validate_range(value : Int32 | Int64 | Float32 | Float64) : Bool
          # Range validation
          min_value = #{min_val}
          max_value = #{max_val}
          value >= min_value && value <= max_value
        end
        CRYSTAL
      end

      private def generate_custom_validator : String
        <<-CRYSTAL
        def self.validate_#{snake_case_name}(value) : Bool
          # Custom validation logic
          # Implement your specific validation rules here

          # Example: Check if value meets your criteria
          return false if value.nil? || value.to_s.empty?

          # Add your custom validation logic
          # For example:
          # - Business rule validation
          # - Complex format checking
          # - External API validation
          # - Multi-field validation

          true # Return true if valid, false if invalid
        end
        CRYSTAL
      end

      private def generate_validation_logic : String
        case validation_type.downcase
        when "email"
          "validate_email(#{attributes.keys.first? || "email"})"
        when "phone"
          "validate_phone(#{attributes.keys.first? || "phone"})"
        when "url"
          "validate_url(#{attributes.keys.first? || "url"})"
        when "regex", "pattern"
          "validate_pattern(#{attributes.keys.first? || "value"})"
        when "range"
          "validate_range(#{attributes.keys.first? || "value"})"
        else
          "validate_#{snake_case_name}(#{attributes.keys.first? || "value"})"
        end
      end

      private def generate_attributes_list : String
        return "" if attributes.empty?

        lines = [] of String
        attributes.each do |attr_name, attr_type|
          crystal_type = crystal_type(attr_type)
          lines << "    property #{attr_name} : #{crystal_type}"
        end

        lines.join("\n")
      end

      private def generate_error_message : String
        case validation_type.downcase
        when "email"
          "\"Invalid email format\""
        when "phone"
          "\"Invalid phone number format\""
        when "url"
          "\"Invalid URL format\""
        when "regex", "pattern"
          "\"Value does not match required pattern\""
        when "range"
          "\"Value must be within the specified range\""
        else
          "\"#{class_name} validation failed\""
        end
      end

      private def generate_test_cases : String
        case validation_type.downcase
        when "email"
          generate_email_test_cases
        when "phone"
          generate_phone_test_cases
        when "url"
          generate_url_test_cases
        when "regex", "pattern"
          generate_regex_test_cases
        when "range"
          generate_range_test_cases
        else
          generate_custom_test_cases
        end
      end

      private def generate_email_test_cases : String
        <<-CRYSTAL
        describe ".validate_email" do
          it "validates correct email formats" do
            #{module_name}::#{class_name}Validator.validate_email("user@example.com").should be_true
            #{module_name}::#{class_name}Validator.validate_email("test+tag@domain.co.uk").should be_true
          end

          it "rejects invalid email formats" do
            #{module_name}::#{class_name}Validator.validate_email("invalid-email").should be_false
            #{module_name}::#{class_name}Validator.validate_email("@domain.com").should be_false
            #{module_name}::#{class_name}Validator.validate_email("user@").should be_false
            #{module_name}::#{class_name}Validator.validate_email("").should be_false
          end
        end
        CRYSTAL
      end

      private def generate_phone_test_cases : String
        <<-CRYSTAL
        describe ".validate_phone" do
          it "validates correct phone formats" do
            #{module_name}::#{class_name}Validator.validate_phone("555-123-4567").should be_true
            #{module_name}::#{class_name}Validator.validate_phone("(555) 123-4567").should be_true
            #{module_name}::#{class_name}Validator.validate_phone("555.123.4567").should be_true
            #{module_name}::#{class_name}Validator.validate_phone("5551234567").should be_true
          end

          it "rejects invalid phone formats" do
            #{module_name}::#{class_name}Validator.validate_phone("123").should be_false
            #{module_name}::#{class_name}Validator.validate_phone("invalid-phone").should be_false
            #{module_name}::#{class_name}Validator.validate_phone("").should be_false
          end
        end
        CRYSTAL
      end

      private def generate_url_test_cases : String
        <<-CRYSTAL
        describe ".validate_url" do
          it "validates correct URL formats" do
            #{module_name}::#{class_name}Validator.validate_url("https://example.com").should be_true
            #{module_name}::#{class_name}Validator.validate_url("http://subdomain.example.org/path").should be_true
          end

          it "rejects invalid URL formats" do
            #{module_name}::#{class_name}Validator.validate_url("not-a-url").should be_false
            #{module_name}::#{class_name}Validator.validate_url("ftp://example.com").should be_false
            #{module_name}::#{class_name}Validator.validate_url("").should be_false
          end
        end
        CRYSTAL
      end

      private def generate_regex_test_cases : String
        <<-CRYSTAL
        describe ".validate_pattern" do
          it "validates values matching the pattern" do
            #{module_name}::#{class_name}Validator.validate_pattern("abc123").should be_true
          end

          it "rejects values not matching the pattern" do
            #{module_name}::#{class_name}Validator.validate_pattern("invalid!@#").should be_false
            #{module_name}::#{class_name}Validator.validate_pattern("").should be_false
          end
        end
        CRYSTAL
      end

      private def generate_range_test_cases : String
        min_val = attributes["min"]? || "0"
        max_val = attributes["max"]? || "100"
        <<-CRYSTAL
        describe ".validate_range" do
          it "validates values within range" do
            #{module_name}::#{class_name}Validator.validate_range(#{min_val}).should be_true
            #{module_name}::#{class_name}Validator.validate_range(#{max_val}).should be_true
            #{module_name}::#{class_name}Validator.validate_range(50).should be_true
          end

          it "rejects values outside range" do
            #{module_name}::#{class_name}Validator.validate_range(#{min_val.to_i - 1}).should be_false
            #{module_name}::#{class_name}Validator.validate_range(#{max_val.to_i + 1}).should be_false
          end
        end
        CRYSTAL
      end

      private def generate_custom_test_cases : String
        <<-CRYSTAL
        describe ".validate_#{snake_case_name}" do
          it "validates correct values" do
            # Add test cases for valid values
            #{module_name}::#{class_name}Validator.validate_#{snake_case_name}("valid_value").should be_true
          end

          it "rejects invalid values" do
            # Add test cases for invalid values
            #{module_name}::#{class_name}Validator.validate_#{snake_case_name}("").should be_false
            #{module_name}::#{class_name}Validator.validate_#{snake_case_name}(nil).should be_false
          end
        end
        CRYSTAL
      end

      private def generate_valid_examples : String
        case validation_type.downcase
        when "email"
          "\"user@example.com\", \"test+tag@domain.co.uk\""
        when "phone"
          "\"555-123-4567\", \"(555) 123-4567\""
        when "url"
          "\"https://example.com\", \"http://test.org/path\""
        else
          "\"valid_value\", \"another_valid_value\""
        end
      end

      private def generate_invalid_examples : String
        case validation_type.downcase
        when "email"
          "\"invalid-email\", \"@domain.com\", \"\""
        when "phone"
          "\"123\", \"invalid-phone\", \"\""
        when "url"
          "\"not-a-url\", \"ftp://example.com\", \"\""
        else
          "\"invalid_value\", \"\", nil"
        end
      end

      private def show_validator_usage_info
        puts
        puts "📋 Validator Usage:".colorize(:yellow).bold
        puts "  1. Use in your CQL model:"
        puts "     class #{model_name.empty? ? "YourModel" : model_name} < CQL::Model"
        puts "       validate :#{attributes.keys.first? || "field"}, with: #{class_name}Validator"
        puts "     end"
        puts
        puts "  2. Use in contracts:"
        puts "     struct YourContract"
        puts "       include Request"
        puts "       validate #{attributes.keys.first? || "field"}, custom: #{class_name}Validator"
        puts "     end"
        puts
        puts "  3. Use directly in code:"
        puts "     #{class_name}Validator.#{generate_validation_logic}"
        puts
        puts "💡 Validation Types:".colorize(:blue).bold
        puts "  - email: Email format validation"
        puts "  - phone: Phone number validation"
        puts "  - url: URL format validation"
        puts "  - regex: Custom regex pattern"
        puts "  - range: Numeric range validation"
        puts "  - custom: Custom business logic"
        puts
        puts "📚 Learn more: https://github.com/azutoolkit/cql/blob/master/src/active_record/validations.cr".colorize(:cyan)
      end
    end
  end
end
