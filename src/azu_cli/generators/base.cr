require "cadmium_inflector"
require "teeplate"

module AzuCLI
  module Generator
    # Base generator class that provides common functionality for all generators
    abstract class Base
      getter name : String
      getter project_name : String
      getter force : Bool
      getter skip_tests : Bool

      def initialize(@name : String, @project_name : String, @force = false, @skip_tests = false)
      end

      # Abstract method that subclasses must implement
      abstract def generate!

      # Helper methods for naming conventions
      def class_name : String
        classify(name)
      end

      def snake_case_name : String
        underscore(name)
      end

      def kebab_case_name : String
        snake_case_name.gsub("_", "-")
      end

      def plural_name : String
        pluralize(snake_case_name)
      end

      def plural_class_name : String
        classify(plural_name)
      end

      def module_name : String
        classify(project_name)
      end

      def camelcase_name : String
        camelize(name)
      end

      # String inflection helpers
      private def classify(str : String) : String
        str.split(/[-_\s]/).map(&.capitalize).join
      end

      private def underscore(str : String) : String
        str.gsub(/::/, '/')
          .gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
          .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
          .downcase
      end

      private def camelize(str : String) : String
        classified = classify(str)
        return classified if classified.empty?
        classified[0].downcase + classified[1..]
      end

      private def pluralize(str : String) : String
        # Simple pluralization rules
        case str
        when /s$/, /sh$/, /ch$/, /x$/, /z$/
          str + "es"
        when /[^aeiou]y$/
          str[0..-2] + "ies"
        when /f$/
          str[0..-2] + "ves"
        when /fe$/
          str[0..-3] + "ves"
        else
          str + "s"
        end
      end

      # File system helpers
      def ensure_directory(path : String)
        unless Dir.exists?(path)
          puts "  📁 Creating directory: #{path}".colorize(:blue)
          Dir.mkdir_p(path)
        end
      end

      def write_file(path : String, content : String, description : String = "")
        if File.exists?(path) && !force
          puts "  ⚠️  File exists: #{path} (use --force to overwrite)".colorize(:yellow)
          return false
        end

        ensure_directory(File.dirname(path))
        File.write(path, content)

        desc_text = description.empty? ? "" : " (#{description})"
        puts "  ✅ Created: #{path}#{desc_text}".colorize(:green)
        true
      end

      def copy_template(template_path : String, destination_path : String, variables : Hash(String, String) = {} of String => String)
        template_content = render_template(template_path, variables)
        write_file(destination_path, template_content)
      end

      def render_template(template_path : String, variables : Hash(String, String) = {} of String => String) : String
        full_template_path = File.join(__DIR__, "../templates", template_path)

        unless File.exists?(full_template_path)
          raise "Template not found: #{full_template_path}"
        end

        content = File.read(full_template_path)

        # Replace template variables
        all_variables = default_template_variables.merge(variables)
        all_variables.each do |key, value|
          content = content.gsub("{{#{key}}}", value)
        end

        content
      end

      def default_template_variables : Hash(String, String)
        {
          "name"              => name,
          "class_name"        => class_name,
          "snake_case_name"   => snake_case_name,
          "kebab_case_name"   => kebab_case_name,
          "plural_name"       => plural_name,
          "plural_class_name" => plural_class_name,
          "module_name"       => module_name,
          "camelcase_name"    => camelcase_name,
          "project_name"      => project_name,
          "project_module"    => module_name,
        }
      end

      # Validation helpers
      def validate_name!
        unless valid_name?(name)
          raise ArgumentError.new("Invalid name: #{name}. Must contain only letters, numbers, and underscores.")
        end
      end

      def valid_name?(name : String) : Bool
        /^[a-zA-Z][a-zA-Z0-9_]*$/.matches?(name)
      end

      # Crystal type mapping for attributes
      def crystal_type(type : String) : String
        case type.downcase
        when "string", "text"
          "String"
        when "integer", "int"
          "Int32"
        when "big_integer", "bigint"
          "Int64"
        when "float", "decimal"
          "Float64"
        when "boolean", "bool"
          "Bool"
        when "date"
          "Time"
        when "datetime", "timestamp"
          "Time"
        when "json"
          "JSON::Any"
        when "uuid"
          "UUID"
        else
          "String" # Default to String for unknown types
        end
      end

      # CQL type mapping for database
      def cql_type(type : String) : String
        case type.downcase
        when "string"
          "String"
        when "text"
          "Text"
        when "integer", "int"
          "Int32"
        when "big_integer", "bigint"
          "Int64"
        when "float", "decimal"
          "Float64"
        when "boolean", "bool"
          "Bool"
        when "date"
          "Date"
        when "datetime", "timestamp"
          "Time"
        when "json"
          "JSON"
        when "uuid"
          "UUID"
        else
          "String" # Default to String for unknown types
        end
      end

      # Generate test file helper
      def generate_test_file(test_path : String, test_content : String, component_type : String)
        return if skip_tests

        if write_file(test_path, test_content, "#{component_type} test")
          puts "    💡 Remember to run 'crystal spec #{test_path}' to test your #{component_type}".colorize(:blue)
        end
      end
    end
  end
end
