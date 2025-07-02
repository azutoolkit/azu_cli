require "./base"

module AzuCLI
  module Generator
    class Request < Base
      getter attributes : Hash(String, String)
      getter validations : Hash(String, String)
      getter with_file_upload : Bool

      def initialize(@name : String, @project_name : String, @attributes = Hash(String, String).new, @validations = Hash(String, String).new, @with_file_upload = false, @force = false, @skip_tests = false)
        super(name, project_name, force, skip_tests)
        validate_name!
      end

      def generate!
        create_directories
        generate_request
        generate_tests unless skip_tests

        puts "  📥 Generated #{class_name}Request".colorize(:green)
        show_request_usage_info
      end

      private def create_directories
        ensure_directory("src/requests")
        ensure_directory("spec/requests") unless skip_tests
      end

      private def generate_request
        template_variables = {
          "attributes_list"    => generate_attributes_list,
          "validations_list"   => generate_validations_list,
          "constructor"        => generate_constructor,
          "file_upload_attrs"  => generate_file_upload_attributes,
        }

        copy_template(
          "generators/request/request.cr.ecr",
          "src/requests/#{snake_case_name}_request.cr",
          template_variables
        )
      end

      private def generate_tests
        template_variables = {
          "valid_attributes"    => generate_valid_test_attributes,
          "invalid_attributes"  => generate_invalid_test_attributes,
          "validation_tests"    => generate_validation_tests,
        }

        copy_template(
          "generators/request/request_spec.cr.ecr",
          "spec/requests/#{snake_case_name}_request_spec.cr",
          template_variables
        )
      end

      private def generate_attributes_list : String
        lines = [] of String

        # Add file upload attributes if needed
        if with_file_upload
          lines << "  getter file : Azu::Params::Multipart::File?"
        end

        attributes.each do |attr_name, attr_type|
          crystal_type = crystal_type(attr_type)
          nullable = attr_type.ends_with?("?")

          if nullable
            lines << "  getter #{attr_name} : #{crystal_type}?"
          else
            lines << "  getter #{attr_name} : #{crystal_type}"
          end
        end

        lines.join("\n")
      end

      private def generate_constructor : String
        constructor_params = [] of String
        initialization_params = [] of String

        if with_file_upload
          constructor_params << "@file : Azu::Params::Multipart::File? = nil"
        end

        attributes.each do |attr_name, attr_type|
          crystal_type = crystal_type(attr_type)
          nullable = attr_type.ends_with?("?")

          if nullable
            constructor_params << "@#{attr_name} : #{crystal_type}? = nil"
          else
            default_value = generate_default_value(crystal_type)
            constructor_params << "@#{attr_name} : #{crystal_type} = #{default_value}"
          end
        end

        if constructor_params.empty?
          return "  # No constructor parameters needed"
        end

        constructor_signature = constructor_params.join(", ")

        <<-CRYSTAL
        def initialize(#{constructor_signature})
        end
        CRYSTAL
      end

      private def generate_default_value(crystal_type : String) : String
        case crystal_type
        when "String"
          "\"\""
        when "Int32"
          "0"
        when "Int64"
          "0_i64"
        when "Float64"
          "0.0"
        when "Bool"
          "false"
        when "Time"
          "Time.utc"
        when "Array(String)"
          "[] of String"
        when "Hash(String, String)"
          "{} of String => String"
        else
          "nil"
        end
      end

      private def generate_validations_list : String
        lines = [] of String

        # File upload validation
        if with_file_upload
          lines << "  validate :file, file: {max_size: 10.megabytes, allowed_types: %w(jpg jpeg png gif pdf)}"
        end

        # Attribute validations
        attributes.each do |attr_name, attr_type|
          unless attr_type.ends_with?("?")
            lines << "  validate :#{attr_name}, presence: true"

            # Type-specific validations
            case attr_type.downcase
            when "string", "text"
              lines << "  validate :#{attr_name}, length: {min: 1, max: 255}"
            when "integer", "int", "big_integer", "bigint"
              lines << "  validate :#{attr_name}, numericality: {greater_than: 0}"
            when "float", "decimal"
              lines << "  validate :#{attr_name}, numericality: {greater_than: 0.0}"
            when "email"
              lines << "  validate :#{attr_name}, format: /\\A[\\w+\\-.]+@[a-z\\d\\-]+(\\.[a-z\\d\\-]+)*\\.[a-z]+\\z/i"
            end
          end
        end

        # Custom validations from the validations hash
        validations.each do |attr_name, validation_rule|
          lines << "  validate :#{attr_name}, #{validation_rule}"
        end

        lines.join("\n")
      end

      private def generate_file_upload_attributes : String
        return "" unless with_file_upload

        <<-CRYSTAL

        # File upload helpers
        def file_present? : Bool
          !file.nil? && file.not_nil!.size > 0
        end

        def file_extension : String?
          return nil unless file_present?
          File.extname(file.not_nil!.filename || "")
        end

        def file_content_type : String?
          file.try(&.headers["Content-Type"]?)
        end
        CRYSTAL
      end

      private def generate_valid_test_attributes : String
        attr_values = [] of String

        if with_file_upload
          attr_values << "file: mock_file"
        end

        attributes.each do |attr_name, attr_type|
          value = case crystal_type(attr_type).gsub("?", "")
                  when "String"
                    "\"test_#{attr_name}\""
                  when "Int32"
                    "42"
                  when "Int64"
                    "42_i64"
                  when "Float64"
                    "3.14"
                  when "Bool"
                    "true"
                  when "Time"
                    "Time.utc"
                  else
                    "\"test_#{attr_name}\""
                  end
          attr_values << "#{attr_name}: #{value}"
        end

        attr_values.join(",\n        ")
      end

      private def generate_invalid_test_attributes : String
        # Generate test cases for invalid attributes
        test_cases = [] of String

        attributes.each do |attr_name, attr_type|
          next if attr_type.ends_with?("?") # Skip optional attributes

          case crystal_type(attr_type)
          when "String"
            test_cases << "#{attr_name}: \"\""  # Empty string
          when "Int32", "Int64"
            test_cases << "#{attr_name}: -1"    # Negative number
          when "Float64"
            test_cases << "#{attr_name}: -1.0"  # Negative float
          end
        end

        test_cases.join(",\n        ")
      end

      private def generate_validation_tests : String
        lines = [] of String

        attributes.each do |attr_name, attr_type|
          next if attr_type.ends_with?("?")

          lines << generate_validation_test(attr_name, attr_type)
        end

        if with_file_upload
          lines << generate_file_validation_test
        end

        lines.join("\n\n")
      end

      private def generate_validation_test(attr_name : String, attr_type : String) : String
        <<-CRYSTAL
        it "validates #{attr_name} presence" do
          request = #{module_name}::#{class_name}Request.new(#{attr_name}: #{get_invalid_value(attr_type)})
          request.valid?.should be_false
          request.errors.should contain("#{attr_name.capitalize}")
        end
        CRYSTAL
      end

      private def generate_file_validation_test : String
        <<-CRYSTAL
        it "validates file upload" do
          request = #{module_name}::#{class_name}Request.new(file: large_file)
          request.valid?.should be_false
          request.errors.should contain("File")
        end

        it "accepts valid file uploads" do
          request = #{module_name}::#{class_name}Request.new(file: valid_file)
          request.valid?.should be_true
        end
        CRYSTAL
      end

      private def get_invalid_value(attr_type : String) : String
        case crystal_type(attr_type)
        when "String"
          "\"\""
        when "Int32"
          "0"
        when "Int64"
          "0_i64"
        when "Float64"
          "0.0"
        else
          "nil"
        end
      end

      private def show_request_usage_info
        puts
        puts "📥 Request Usage:".colorize(:yellow).bold
        puts "  1. Use in your endpoints:"
        puts "     struct MyEndpoint"
        puts "       include Azu::Endpoint(#{class_name}Request, MyResponse)"
        puts "       # Access validated attributes via request object"
        puts "     end"
        puts
        puts "  2. Manual validation:"
        puts "     request = #{class_name}Request.new(#{generate_example_params})"
        puts "     if request.valid?"
        puts "       # Process valid request"
        puts "     else"
        puts "       # Handle validation errors: request.errors"
        puts "     end"
        puts
        if with_file_upload
          puts "  3. File upload handling:"
          puts "     if request.file_present?"
          puts "       # Process uploaded file"
          puts "       puts request.file_extension"
          puts "       puts request.file_content_type"
          puts "     end"
          puts
        end
        puts "💡 Request Features:".colorize(:blue).bold
        puts "  - Compile-time type safety"
        puts "  - Automatic parameter validation"
        puts "  - Integration with Azu endpoints"
        if with_file_upload
          puts "  - File upload support with validation"
        end
        puts
        puts "📚 Learn more: https://azutopia.gitbook.io/azu/validation/requests".colorize(:cyan)
      end

      private def generate_example_params : String
        params = [] of String

        if with_file_upload
          params << "file: uploaded_file"
        end

        attributes.each do |attr_name, attr_type|
          value = case crystal_type(attr_type).gsub("?", "")
                  when "String"
                    "\"example\""
                  when "Int32"
                    "10"
                  when "Int64"
                    "10_i64"
                  when "Float64"
                    "10.5"
                  when "Bool"
                    "true"
                  else
                    "\"example\""
                  end
          params << "#{attr_name}: #{value}"
        end

        params.join(", ")
      end
    end
  end
end
