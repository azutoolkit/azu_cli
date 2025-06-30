require "./base"

module AzuCLI
  module Generator
    class Model < Base
      getter attributes : Hash(String, String)

      def initialize(@name : String, @project_name : String, @attributes = Hash(String, String).new, @force = false, @skip_tests = false)
        super(name, project_name, force, skip_tests)
        validate_name!
      end

      def generate!
        create_directories
        generate_model
        generate_tests unless skip_tests

        puts "  📝 Generated #{class_name} model with #{attributes.size} attribute(s)".colorize(:green)
      end

      private def create_directories
        ensure_directory("src/models")
        ensure_directory("spec/models") unless skip_tests
      end

      private def generate_model
        template_vars = {
          "attributes_list" => generate_attributes_list,
          "table_name" => plural_name,
        }

        copy_template(
          "generators/model/model.cr.ecr",
          "src/models/#{snake_case_name}.cr",
          template_vars
        )
      end

      private def generate_tests
        template_vars = {
          "attributes_list" => generate_test_attributes,
        }

        copy_template(
          "generators/model/model_spec.cr.ecr",
          "spec/models/#{snake_case_name}_spec.cr",
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

          lines << "  property #{attr_name} : #{type_annotation}"
        end

        lines.join("\n")
      end

      private def generate_test_attributes : String
        return "" if attributes.empty?

        lines = [] of String
        attributes.each do |attr_name, attr_type|
          test_value = test_value_for_type(attr_type)
          lines << "      #{attr_name}: #{test_value},"
        end

        lines.join("\n")
      end

      private def test_value_for_type(type : String) : String
        case type.downcase.gsub("?", "")
        when "string", "text"
          "\"Test #{class_name}\""
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
