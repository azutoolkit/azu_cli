require "./base"

module AzuCLI
  module Generator
    class Validator < Base
      getter validation_type : String
      getter model_name : String
      getter pattern : String
      getter range_options : Hash(String, String)

      def initialize(@name : String, @project_name : String, @validation_type = "custom", @model_name = "User", @pattern = "", @range_options = Hash(String, String).new, @force = false, @skip_tests = false)
        super(name, project_name, force, skip_tests)
        validate_name!
      end

      def generate!
        create_directories
        generate_validator
        generate_tests unless skip_tests

        puts "  ✅ Generated #{class_name}Validator".colorize(:green)
        show_validator_usage_info
      end

      private def create_directories
        ensure_directory("src/validators")
        ensure_directory("spec/validators") unless skip_tests
      end

      private def generate_validator
        template_variables = {
          "validator_implementation" => generate_validator_implementation,
          "constants"                => generate_constants,
          "initialize_method"        => generate_initialize_method,
          "field_name"               => generate_field_name,
          "error_message"            => generate_error_message,
        }

        copy_template(
          "generators/validator/validator.cr.ecr",
          "src/validators/#{snake_case_name}_validator.cr",
          template_variables
        )
      end

      private def generate_tests
        template_variables = {
          "test_cases"        => generate_test_cases,
          "valid_examples"    => generate_valid_examples,
          "invalid_examples"  => generate_invalid_examples,
          "mock_model"        => generate_mock_model,
        }

        copy_template(
          "generators/validator/validator_spec.cr.ecr",
          "spec/validators/#{snake_case_name}_validator_spec.cr",
          template_variables
        )
      end

      private def generate_validator_implementation : String
        case validation_type.downcase
        when "email"
          generate_email_validator
        when "unique", "uniqueness"
          generate_unique_validator
        when "age", "range"
          generate_age_validator
        when "file"
          generate_file_validator
        when "password"
          generate_password_validator
        when "phone"
          generate_phone_validator
        when "url"
          generate_url_validator
        when "regex", "pattern"
          generate_regex_validator
        else
          generate_custom_validator
        end
      end

      private def generate_email_validator : String
        <<-CRYSTAL
        def valid? : Array(Schema::Error)
          errors = [] of Schema::Error

          email = @record.email
          return errors if email.empty?

          unless EMAIL_REGEX.match(email)
            errors << Schema::Error.new(@field, @message)
          end

          errors
        end
        CRYSTAL
      end

      private def generate_unique_validator : String
        <<-CRYSTAL
        def valid? : Array(Schema::Error)
          errors = [] of Schema::Error

          # Check if email already exists in database
          if #{model_name}.where(email: @record.email).where { id != @record.id }.exists?
            errors << Schema::Error.new(@field, @message)
          end

          errors
        end
        CRYSTAL
      end

      private def generate_age_validator : String
        min_age = range_options["min"]? || "13"
        max_age = range_options["max"]? || "120"

        <<-CRYSTAL
        def valid? : Array(Schema::Error)
          errors = [] of Schema::Error

          age = @record.age
          return errors unless age # Skip if age is nil

          unless (#{min_age}..#{max_age}).includes?(age)
            errors << Schema::Error.new(@field, @message)
          end

          errors
        end
        CRYSTAL
      end

      private def generate_file_validator : String
        <<-CRYSTAL
        def valid? : Array(Schema::Error)
          errors = [] of Schema::Error

          # This assumes your #{model_name} model has a profile_image_url field
          return errors unless @record.profile_image_url

          extension = File.extname(@record.profile_image_url || "").downcase
          unless IMAGE_EXTENSIONS.includes?(extension)
            errors << Schema::Error.new(@field, @message)
          end

          errors
        end
        CRYSTAL
      end

      private def generate_password_validator : String
        <<-CRYSTAL
        def valid? : Array(Schema::Error)
          errors = [] of Schema::Error

          password = @record.password
          return errors if password.empty?

          # Check length
          if password.size < 8
            errors << Schema::Error.new(@field, "Password must be at least 8 characters long!")
            return errors
          end

          # Check for uppercase letter
          unless password.match(/[A-Z]/)
            errors << Schema::Error.new(@field, "Password must contain at least one uppercase letter!")
          end

          # Check for lowercase letter
          unless password.match(/[a-z]/)
            errors << Schema::Error.new(@field, "Password must contain at least one lowercase letter!")
          end

          # Check for number
          unless password.match(/[0-9]/)
            errors << Schema::Error.new(@field, "Password must contain at least one number!")
          end

          # Check for special character (optional)
          unless password.match(/[!@#$%^&*(),.?":{}|<>]/)
            errors << Schema::Error.new(@field, "Password should contain at least one special character!")
          end

          errors
        end
        CRYSTAL
      end

      private def generate_phone_validator : String
        <<-CRYSTAL
        def valid? : Array(Schema::Error)
          errors = [] of Schema::Error

          phone = @record.phone
          return errors if phone.empty?

          unless PHONE_REGEX.match(phone)
            errors << Schema::Error.new(@field, @message)
          end

          errors
        end
        CRYSTAL
      end

      private def generate_url_validator : String
        <<-CRYSTAL
        def valid? : Array(Schema::Error)
          errors = [] of Schema::Error

          url = @record.url
          return errors if url.empty?

          begin
            uri = URI.parse(url)
            unless ["http", "https"].includes?(uri.scheme)
              errors << Schema::Error.new(@field, @message)
            end
          rescue URI::Error
            errors << Schema::Error.new(@field, @message)
          end

          errors
        end
        CRYSTAL
      end

      private def generate_regex_validator : String
        regex_pattern = pattern.empty? ? "/^[A-Za-z0-9]+$/" : pattern

        <<-CRYSTAL
        def valid? : Array(Schema::Error)
          errors = [] of Schema::Error

          value = @record.#{generate_field_name}
          return errors if value.empty?

          unless PATTERN_REGEX.match(value)
            errors << Schema::Error.new(@field, @message)
          end

          errors
        end
        CRYSTAL
      end

      private def generate_custom_validator : String
        <<-CRYSTAL
        def valid? : Array(Schema::Error)
          errors = [] of Schema::Error

          value = @record.#{generate_field_name}
          return errors if value.empty?

          # TODO: Implement your custom validation logic here
          # Example:
          # unless your_validation_condition(value)
          #   errors << Schema::Error.new(@field, @message)
          # end

          errors
        end
        CRYSTAL
      end

      private def generate_constants : String
        case validation_type.downcase
        when "email"
          "  EMAIL_REGEX = /\\A[\\w+\\-.]+@[a-z\\d\\-]+(\\.[a-z\\d\\-]+)*\\.[a-z]+\\z/i"
        when "file"
          "  IMAGE_EXTENSIONS = %w(.jpg .jpeg .png .gif .webp)"
        when "phone"
          "  PHONE_REGEX = /\\A[\\+]?[1-9]?[0-9]{7,12}\\z/"
        when "regex", "pattern"
          regex_pattern = pattern.empty? ? "/^[A-Za-z0-9]+$/" : pattern
          "  PATTERN_REGEX = #{regex_pattern}"
        else
          ""
        end
      end

      private def generate_initialize_method : String
        field_name = generate_field_name
        error_message = generate_error_message

        <<-CRYSTAL
        def initialize(@record : #{model_name})
          @field = :#{field_name}
          @message = "#{error_message}"
        end
        CRYSTAL
      end

      private def generate_field_name : String
        case validation_type.downcase
        when "email"
          "email"
        when "unique", "uniqueness"
          "email"
        when "age", "range"
          "age"
        when "file"
          "profile_image"
        when "password"
          "password"
        when "phone"
          "phone"
        when "url"
          "url"
        else
          snake_case_name.gsub("_validator", "")
        end
      end

      private def generate_error_message : String
        case validation_type.downcase
        when "email"
          "Email must be valid!"
        when "unique", "uniqueness"
          "Email must be unique!"
        when "age", "range"
          min_age = range_options["min"]? || "13"
          max_age = range_options["max"]? || "120"
          "Age must be between #{min_age} and #{max_age}!"
        when "file"
          "Profile image must be a valid image file!"
        when "password"
          "Password must contain at least 8 characters, one uppercase, one lowercase, and one number!"
        when "phone"
          "Phone number must be valid!"
        when "url"
          "URL must be valid!"
        when "regex", "pattern"
          "#{class_name.gsub("Validator", "")} format is invalid!"
        else
          "#{class_name.gsub("Validator", "")} is invalid!"
        end
      end

      private def generate_test_cases : String
        case validation_type.downcase
        when "email"
          generate_email_test_cases
        when "unique", "uniqueness"
          generate_unique_test_cases
        when "age", "range"
          generate_age_test_cases
        when "file"
          generate_file_test_cases
        when "password"
          generate_password_test_cases
        when "phone"
          generate_phone_test_cases
        when "url"
          generate_url_test_cases
        else
          generate_custom_test_cases
        end
      end

      private def generate_email_test_cases : String
        <<-CRYSTAL
        describe "email validation" do
          it "validates correct email addresses" do
            valid_emails = [
              "user@example.com",
              "test.email+tag@domain.co.uk",
              "valid_email@test-domain.com"
            ]

            valid_emails.each do |email|
              #{model_name.downcase} = create_#{model_name.downcase}(email: email)
              validator = #{class_name}Validator.new(#{model_name.downcase})
              validator.valid?.should be_empty
            end
          end

          it "rejects invalid email addresses" do
            invalid_emails = [
              "invalid-email",
              "user@",
              "@domain.com",
              "",
              "spaces in@email.com"
            ]

            invalid_emails.each do |email|
              #{model_name.downcase} = create_#{model_name.downcase}(email: email)
              validator = #{class_name}Validator.new(#{model_name.downcase})
              validator.valid?.should_not be_empty
            end
          end
        end
        CRYSTAL
      end

      private def generate_unique_test_cases : String
        <<-CRYSTAL
        describe "email uniqueness validation" do
          it "passes when email is unique" do
            #{model_name.downcase} = create_#{model_name.downcase}(email: "unique@example.com")
            validator = #{class_name}Validator.new(#{model_name.downcase})
            validator.valid?.should be_empty
          end

          it "fails when email already exists" do
            existing_#{model_name.downcase} = create_#{model_name.downcase}(email: "duplicate@example.com")
            new_#{model_name.downcase} = create_#{model_name.downcase}(email: "duplicate@example.com")

            validator = #{class_name}Validator.new(new_#{model_name.downcase})
            validator.valid?.should_not be_empty
          end
        end
        CRYSTAL
      end

      private def generate_age_test_cases : String
        min_age = range_options["min"]? || "13"
        max_age = range_options["max"]? || "120"

        <<-CRYSTAL
        describe "age validation" do
          it "validates ages within range" do
            valid_ages = [#{min_age}, 25, 65, #{max_age}]

            valid_ages.each do |age|
              #{model_name.downcase} = create_#{model_name.downcase}(age: age)
              validator = #{class_name}Validator.new(#{model_name.downcase})
              validator.valid?.should be_empty
            end
          end

          it "rejects ages outside range" do
            invalid_ages = [#{(min_age.to_i - 1)}, #{(max_age.to_i + 1)}]

            invalid_ages.each do |age|
              #{model_name.downcase} = create_#{model_name.downcase}(age: age)
              validator = #{class_name}Validator.new(#{model_name.downcase})
              validator.valid?.should_not be_empty
            end
          end

          it "passes when age is nil" do
            #{model_name.downcase} = create_#{model_name.downcase}(age: nil)
            validator = #{class_name}Validator.new(#{model_name.downcase})
            validator.valid?.should be_empty
          end
        end
        CRYSTAL
      end

      private def generate_file_test_cases : String
        <<-CRYSTAL
        describe "file validation" do
          it "validates correct image extensions" do
            valid_extensions = [".jpg", ".jpeg", ".png", ".gif", ".webp"]

            valid_extensions.each do |ext|
              #{model_name.downcase} = create_#{model_name.downcase}(profile_image_url: "photo#{ext}")
              validator = #{class_name}Validator.new(#{model_name.downcase})
              validator.valid?.should be_empty
            end
          end

          it "rejects invalid file extensions" do
            invalid_extensions = [".txt", ".pdf", ".doc", ".exe"]

            invalid_extensions.each do |ext|
              #{model_name.downcase} = create_#{model_name.downcase}(profile_image_url: "file#{ext}")
              validator = #{class_name}Validator.new(#{model_name.downcase})
              validator.valid?.should_not be_empty
            end
          end

          it "passes when profile_image_url is nil" do
            #{model_name.downcase} = create_#{model_name.downcase}(profile_image_url: nil)
            validator = #{class_name}Validator.new(#{model_name.downcase})
            validator.valid?.should be_empty
          end
        end
        CRYSTAL
      end

      private def generate_password_test_cases : String
        <<-CRYSTAL
        describe "password validation" do
          it "validates strong passwords" do
            strong_passwords = [
              "Password123!",
              "MySecure1@",
              "Str0ng#Pass"
            ]

            strong_passwords.each do |password|
              #{model_name.downcase} = create_#{model_name.downcase}(password: password)
              validator = #{class_name}Validator.new(#{model_name.downcase})
              validator.valid?.should be_empty
            end
          end

          it "rejects weak passwords" do
            weak_passwords = [
              "short",
              "nouppercase1!",
              "NOLOWERCASE1!",
              "NoNumbers!",
              "NoSpecial1"
            ]

            weak_passwords.each do |password|
              #{model_name.downcase} = create_#{model_name.downcase}(password: password)
              validator = #{class_name}Validator.new(#{model_name.downcase})
              validator.valid?.should_not be_empty
            end
          end
        end
        CRYSTAL
      end

      private def generate_phone_test_cases : String
        <<-CRYSTAL
        describe "phone validation" do
          it "validates correct phone numbers" do
            valid_phones = [
              "1234567890",
              "+1234567890",
              "555123456789"
            ]

            valid_phones.each do |phone|
              #{model_name.downcase} = create_#{model_name.downcase}(phone: phone)
              validator = #{class_name}Validator.new(#{model_name.downcase})
              validator.valid?.should be_empty
            end
          end

          it "rejects invalid phone numbers" do
            invalid_phones = [
              "123",
              "abc1234567890",
              "123-456-7890"
            ]

            invalid_phones.each do |phone|
              #{model_name.downcase} = create_#{model_name.downcase}(phone: phone)
              validator = #{class_name}Validator.new(#{model_name.downcase})
              validator.valid?.should_not be_empty
            end
          end
        end
        CRYSTAL
      end

      private def generate_url_test_cases : String
        <<-CRYSTAL
        describe "URL validation" do
          it "validates correct URLs" do
            valid_urls = [
              "https://example.com",
              "http://test.com/path",
              "https://sub.domain.com/path?query=value"
            ]

            valid_urls.each do |url|
              #{model_name.downcase} = create_#{model_name.downcase}(url: url)
              validator = #{class_name}Validator.new(#{model_name.downcase})
              validator.valid?.should be_empty
            end
          end

          it "rejects invalid URLs" do
            invalid_urls = [
              "not-a-url",
              "ftp://example.com",
              "example.com"
            ]

            invalid_urls.each do |url|
              #{model_name.downcase} = create_#{model_name.downcase}(url: url)
              validator = #{class_name}Validator.new(#{model_name.downcase})
              validator.valid?.should_not be_empty
            end
          end
        end
        CRYSTAL
      end

      private def generate_custom_test_cases : String
        <<-CRYSTAL
        describe "custom validation" do
          it "validates correctly" do
            #{model_name.downcase} = create_#{model_name.downcase}
            validator = #{class_name}Validator.new(#{model_name.downcase})

            # TODO: Add your specific test cases
            # validator.valid?.should be_empty
          end
        end
        CRYSTAL
      end

      private def generate_valid_examples : String
        case validation_type.downcase
        when "email"
          "user@example.com"
        when "age", "range"
          "25"
        when "phone"
          "1234567890"
        when "url"
          "https://example.com"
        else
          "valid_value"
        end
      end

      private def generate_invalid_examples : String
        case validation_type.downcase
        when "email"
          "invalid-email"
        when "age", "range"
          "999"
        when "phone"
          "abc123"
        when "url"
          "not-a-url"
        else
          "invalid_value"
        end
      end

      private def generate_mock_model : String
        field_name = generate_field_name

        <<-CRYSTAL

        private def create_#{model_name.downcase}(#{field_name} : String? = "#{generate_valid_examples}")
          # Mock #{model_name} for testing
          # In a real app, you'd use factories or create actual model instances
          #{model_name}.new(#{field_name}: #{field_name})
        end
        CRYSTAL
      end

      private def show_validator_usage_info
        puts
        puts "✅ Validator Usage:".colorize(:yellow).bold
        puts "  1. Use in your models:"
        puts "     struct #{model_name}"
        puts "       include Azu::Request"
        puts "       # ... attributes ..."
        puts "       use #{class_name}Validator"
        puts "     end"
        puts
        puts "  2. Manual validation:"
        puts "     #{model_name.downcase} = #{model_name}.new(#{generate_field_name}: \"value\")"
        puts "     validator = #{class_name}Validator.new(#{model_name.downcase})"
        puts "     errors = validator.valid?"
        puts "     puts \"Valid!\" if errors.empty?"
        puts
        puts "  3. Validation type: #{validation_type.capitalize}"
        case validation_type.downcase
        when "email"
          puts "     - Validates email format using regex"
          puts "     - Example valid: user@example.com"
          puts "     - Example invalid: invalid-email"
        when "unique", "uniqueness"
          puts "     - Validates uniqueness in database"
          puts "     - Checks against existing records"
        when "age", "range"
          min_age = range_options["min"]? || "13"
          max_age = range_options["max"]? || "120"
          puts "     - Validates age range: #{min_age} to #{max_age}"
        when "file"
          puts "     - Validates file extensions"
          puts "     - Allowed: .jpg, .jpeg, .png, .gif, .webp"
        when "password"
          puts "     - Validates password strength"
          puts "     - Requires: 8+ chars, uppercase, lowercase, number"
        when "phone"
          puts "     - Validates phone number format"
        when "url"
          puts "     - Validates URL format and scheme"
        else
          puts "     - Custom validation logic"
          puts "     - Implement your specific rules"
        end
        puts
        puts "💡 Validator Features:".colorize(:blue).bold
        puts "  - Extends Azu::Validator"
        puts "  - Returns Array(Schema::Error)"
        puts "  - Integrates with Azu Request validation"
        puts "  - Reusable across models and contracts"
        puts
        puts "📚 Learn more: https://azutopia.gitbook.io/azu/validation/custom-validators".colorize(:cyan)
      end
    end
  end
end
