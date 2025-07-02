require "../core/abstract_generator"

module AzuCLI::Generator
  # Optimized Contract Generator following SOLID principles
  # Uses configuration-driven approach with Template Method pattern
  class ContractGenerator < Core::AbstractGenerator
    property attributes : Hash(String, String)
    property contract_type : String

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @attributes = options.attributes
      @contract_type = options.custom_options["type"]? || "request"
      super(name, project_name, options.force, options.skip_tests)
    end

    # Concrete implementation of abstract method
    def generator_type : String
      "contract"
    end

    # Concrete implementation of abstract method
    def generate_files : Nil
      generate_contract_file
    end

    # Override to add contract-specific directory creation
    def create_directories : Nil
      super

      # Create contract-specific directories from configuration
      contract_dir = config.get("directories.source") || "src/contracts"
      file_strategy.create_directory(contract_dir)

      unless skip_tests
        spec_dir = config.get("directories.spec") || "spec/contracts"
        file_strategy.create_directory(spec_dir)
      end
    end

    # Override to generate contract tests
    def generate_tests : Nil
      return if skip_tests

      test_template = config.get("templates.spec") || "contract/contract_spec.cr.ecr"
      test_path = "spec/contracts/#{snake_case_name}_spec.cr"

      test_variables = generate_test_variables

      create_file_from_template(
        test_template,
        test_path,
        test_variables,
        "contract test"
      )
    end

    # Generate the main contract file
    private def generate_contract_file : Nil
      template = config.get("templates.main") || "contract/contract.cr.ecr"
      output_path = "src/contracts/#{snake_case_name}.cr"

      contract_variables = generate_contract_variables

      create_file_from_template(
        template,
        output_path,
        contract_variables,
        "contract"
      )
    end

    # Generate template variables specific to contracts
    private def generate_contract_variables : Hash(String, String)
      default_template_variables.merge({
        "attributes_list"  => generate_attributes_list,
        "validations_list" => generate_validations_list,
        "contract_type"    => @contract_type,
        "includes_list"    => generate_includes_list,
      })
    end

    # Generate test-specific template variables
    private def generate_test_variables : Hash(String, String)
      default_template_variables.merge({
        "test_attributes"  => generate_test_attributes,
        "validation_tests" => generate_validation_tests,
        "contract_type"    => @contract_type,
      })
    end

    # Generate the attributes list for the contract
    private def generate_attributes_list : String
      return "" if attributes.empty?

      lines = [] of String
      attributes.each do |attr_name, attr_type|
        crystal_type_name = crystal_type(attr_type)
        nullable = attr_type.ends_with?("?")

        if nullable
          lines << "    getter #{attr_name} : #{crystal_type_name}?"
        else
          lines << "    getter #{attr_name} : #{crystal_type_name}"
        end
      end

      lines.join("\n")
    end

    # Generate validation rules based on configuration
    private def generate_validations_list : String
      return "" if attributes.empty?

      lines = [] of String
      validation_patterns = config.get_hash("validation_patterns")

      attributes.each do |attr_name, attr_type|
        next if attr_type.ends_with?("?") # Skip optional attributes

        # Add presence validation for required fields
        if pattern = validation_patterns["presence"]?
          lines << "    " + (pattern % {field: attr_name})
        end

        # Add type-specific validations
        case attr_type.downcase
        when "string", "text"
          if pattern = validation_patterns["length"]?
            lines << "    " + (pattern % {field: attr_name, min: "1", max: "255"})
          end
        when "email"
          if pattern = validation_patterns["format"]?
            email_regex = "/\\A[\\w+\\-.]+@[a-z\\d\\-]+(\\.[a-z\\d\\-]+)*\\.[a-z]+\\z/i"
            lines << "    " + (pattern % {field: attr_name, pattern: email_regex})
          end
          if pattern = validation_patterns["uniqueness"]?
            lines << "    " + (pattern % {field: attr_name})
          end
        when "integer", "int", "bigint"
          if pattern = validation_patterns["numericality"]?
            lines << "    " + (pattern % {field: attr_name, min: "0"})
          end
        end
      end

      lines.join("\n")
    end

    # Generate includes based on contract type
    private def generate_includes_list : String
      contract_type_config = config.get_hash("contract_types.#{@contract_type}")
      return "include Request" if contract_type_config.empty?

      case @contract_type
      when "request"
        "include Request"
      when "response"  
        "include Response"
      else
        "include Request"
      end
    end

    # Generate test attributes list
    private def generate_test_attributes : String
      return "" if attributes.empty?

      lines = [] of String
      test_values = config.get_hash("test_values")

      attributes.each do |attr_name, attr_type|
        clean_type = attr_type.gsub("?", "").downcase
        test_value = test_values[clean_type]? || test_values["string"]? || "\"test_value\""

        # Apply template variables to test value
        if test_value.includes?("Contract")
          test_value = test_value.gsub("Contract", class_name)
        end

        lines << "        #{attr_name}: #{test_value},"
      end

      lines.join("\n")
    end

    # Generate test validation examples
    private def generate_validation_tests : String
      return "" if attributes.empty?

      lines = [] of String

      attributes.each do |attr_name, attr_type|
        next if attr_type.ends_with?("?") # Skip optional attributes

        lines << generate_validation_test(attr_name, attr_type)
      end

      lines.join("\n\n")
    end

    # Generate individual validation test
    private def generate_validation_test(attr_name : String, attr_type : String) : String
      test_value = case crystal_type(attr_type)
                   when "String"
                     "\"\""
                   when "Int32", "Int64"
                     "nil"
                   when "Float64"
                     "nil"
                   else
                     "nil"
                   end

      <<-CRYSTAL
        it "validates #{attr_name} presence" do
          contract = #{module_name}::#{class_name}.new(#{attr_name}: #{test_value})
          contract.valid?.should be_false
          contract.errors.should contain("#{attr_name.capitalize}")
        end
      CRYSTAL
    end

    # Override success message to include contract-specific information
    def success_message : String
      base_message = super
      "#{base_message} with #{attributes.size} attribute(s) of type '#{@contract_type}'"
    end

    # Override to show contract-specific next steps
    def post_generation_tasks : Nil
      super
      show_contract_usage_info
    end

    # Show contract usage information
    private def show_contract_usage_info
      puts
      puts "📝 Contract Usage:".colorize(:yellow).bold
      puts "  1. Use in your endpoints:"
      puts "     struct MyEndpoint"
      puts "       include Azu::Endpoint(#{class_name}, MyResponse)"
      puts "       # Access validated attributes via contract"
      puts "     end"
      puts
      puts "  2. Manual validation:"
      puts "     contract = #{class_name}.new(#{generate_example_params})"
      puts "     if contract.valid?"
      puts "       # Process valid contract"
      puts "     else"
      puts "       # Handle validation errors: contract.errors"
      puts "     end"
      puts
      puts "💡 Contract Type: #{@contract_type.capitalize}".colorize(:blue).bold

      contract_type_info = config.get_hash("contract_types.#{@contract_type}")
      unless contract_type_info.empty?
        description = config.get("contract_types.#{@contract_type}.description")
        puts "  #{description}" if description
      end

      puts
      puts "📚 Learn more: https://azutopia.gitbook.io/azu/validation/contracts".colorize(:cyan)
    end

    # Generate example parameters for usage info
    private def generate_example_params : String
      return "" if attributes.empty?

      params = [] of String
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