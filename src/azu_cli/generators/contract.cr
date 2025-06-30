require "./base"

module AzuCLI
  module Generator
    class Contract < Base
      getter attributes : Hash(String, String)

      def initialize(@name : String, @project_name : String, @attributes = Hash(String, String).new, @force = false, @skip_tests = false)
        super(name, project_name, force, skip_tests)
        validate_name!
      end

      def generate!
        create_directories
        generate_contract
        generate_tests unless skip_tests

        puts "  📝 Generated #{class_name} contract with #{attributes.size} attribute(s)".colorize(:green)
      end

      private def create_directories
        ensure_directory("src/contracts")
        ensure_directory("spec/contracts") unless skip_tests
      end

      private def generate_contract
        template_vars = {
          "attributes_list" => generate_attributes_list,
          "validations_list" => generate_validations_list,
        }

        copy_template(
          "generators/contract/contract.cr.ecr",
          "src/contracts/#{snake_case_name}.cr",
          template_vars
        )
      end

      private def generate_tests
        template_vars = {
          "attributes_list" => generate_test_attributes,
        }

        copy_template(
          "generators/contract/contract_spec.cr.ecr",
          "spec/contracts/#{snake_case_name}_spec.cr",
          template_vars
        )
      end

      private def generate_attributes_list : String
        return "" if attributes.empty?

        lines = [] of String
        attributes.each do |attr_name, attr_type|
          crystal_type = crystal_type(attr_type)
          nullable = attr_type.ends_with?("?")
          type_annotation = nullable ? "#{crystal_type}?" : crystal_type

          lines << "    getter #{attr_name} : #{type_annotation}"
        end

        lines.join("\n")
      end

      private def generate_validations_list : String
        return "" if attributes.empty?

        lines = [] of String
        attributes.each do |attr_name, attr_type|
          unless attr_type.ends_with?("?")
            lines << "    validate #{attr_name}, message: \"#{attr_name.capitalize} must be present.\", required: true"
          end
        end

        lines.join("\n")
      end

      private def generate_test_attributes : String
        return "" if attributes.empty?

        lines = [] of String
        attributes.each do |attr_name, attr_type|
          test_value = test_value_for_type(attr_type)
          lines << "        #{attr_name}: #{test_value},"
        end

        lines.join("\n")
      end

      private def test_value_for_type(type : String) : String
        case type.downcase.gsub("?", "")
        when "string", "text"
          "\"test_#{name}\""
        when "integer", "int"
          "42"
        when "big_integer", "bigint"
          "42_i64"
        when "float", "decimal"
          "3.14"
        when "boolean", "bool"
          "true"
        when "date", "datetime", "timestamp"
          "Time.utc"
        when "json"
          "{\"key\" => \"value\"}"
        when "uuid"
          "UUID.random"
        else
          "\"test_value\""
        end
      end
    end
  end
end
