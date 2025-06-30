require "./base"

module AzuCLI
  module Generator
    class Page < Base
      getter template_vars : Hash(String, String)

      def initialize(@name : String, @project_name : String, @template_vars = Hash(String, String).new, @force = false, @skip_tests = false)
        super(name, project_name, force, skip_tests)
        validate_name!
      end

      def generate!
        create_directories
        generate_page
        generate_template
        generate_tests unless skip_tests

        puts "  📝 Generated #{class_name} page".colorize(:green)
      end

      private def create_directories
        ensure_directory("src/pages")
        ensure_directory("public/templates/#{snake_case_name}")
        ensure_directory("spec/pages") unless skip_tests
      end

      private def generate_page
        template_variables = {
          "template_vars_list" => generate_template_vars_list,
          "render_data"        => generate_render_data,
        }

        copy_template(
          "generators/page/page.cr.ecr",
          "src/pages/#{snake_case_name}.cr",
          template_variables
        )
      end

      private def generate_template
        copy_template(
          "generators/page/page.jinja.ecr",
          "public/templates/#{snake_case_name}/index.jinja"
        )
      end

      private def generate_tests
        copy_template(
          "generators/page/page_spec.cr.ecr",
          "spec/pages/#{snake_case_name}_spec.cr"
        )
      end

      private def generate_template_vars_list : String
        return "" if template_vars.empty?

        lines = [] of String
        template_vars.each do |var_name, var_type|
          crystal_type = crystal_type(var_type)
          lines << "      def initialize(@#{var_name} : #{crystal_type})"
        end

        lines.join("\n")
      end

      private def generate_render_data : String
        return "{}" if template_vars.empty?

        data_items = [] of String
        template_vars.each do |var_name, _|
          data_items << "\"#{var_name}\" => @#{var_name}"
        end

        "{\n        #{data_items.join(",\n        ")}\n      }"
      end
    end
  end
end
