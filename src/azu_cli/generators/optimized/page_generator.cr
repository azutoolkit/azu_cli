require "../core/abstract_generator"

module AzuCLI::Generator
  class PageGenerator < Core::AbstractGenerator
    property template_vars : Hash(String, String)
    property page_type : String
    property template_engine : String

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @template_vars = options.attributes
      @page_type = options.custom_options["type"]? || "dynamic"
      @template_engine = options.custom_options["engine"]? || "jinja"
      super(name, project_name, options.force, options.skip_tests)
    end

    def generator_type : String
      "page"
    end

    def generate_files : Nil
      generate_page_file
      generate_template_file
    end

    def create_directories : Nil
      super
      file_strategy.create_directory("src/pages")
      file_strategy.create_directory("public/templates/#{snake_case_name}")
      file_strategy.create_directory("spec/pages") unless skip_tests
    end

    def generate_tests : Nil
      return if skip_tests

      test_variables = generate_test_variables
      create_file_from_template(
        "page/page_spec.cr.ecr",
        "spec/pages/#{snake_case_name}_spec.cr",
        test_variables,
        "page test"
      )
    end

    private def generate_page_file : Nil
      page_variables = generate_page_variables
      create_file_from_template(
        "page/page.cr.ecr",
        "src/pages/#{snake_case_name}.cr",
        page_variables,
        "page"
      )
    end

    private def generate_template_file : Nil
      extension = config.get("template_engines.#{@template_engine}.extension") || ".jinja"
      template_file = "#{snake_case_name}#{extension}"
      
      template_variables = generate_template_variables
      create_file_from_template(
        "page/page.jinja.ecr",
        "public/templates/#{snake_case_name}/#{template_file}",
        template_variables,
        "template"
      )
    end

    private def generate_page_variables : Hash(String, String)
      default_template_variables.merge({
        "template_vars_list" => generate_template_vars_list,
        "render_data" => generate_render_data,
        "page_type" => @page_type,
        "template_engine" => @template_engine,
      })
    end

    private def generate_test_variables : Hash(String, String)
      default_template_variables.merge({
        "test_data" => generate_test_data,
        "page_type" => @page_type,
      })
    end

    private def generate_template_variables : Hash(String, String)
      default_template_variables.merge({
        "template_data" => generate_template_data,
        "page_type" => @page_type,
      })
    end

    private def generate_template_vars_list : String
      return "" if template_vars.empty?

      lines = [] of String
      template_vars.each do |var_name, var_type|
        crystal_type_name = crystal_type(var_type)
        lines << "      def initialize(@#{var_name} : #{crystal_type_name})"
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

    private def generate_test_data : String
      return "" if template_vars.empty?

      test_values = template_vars.map do |var_name, var_type|
        value = case crystal_type(var_type).gsub("?", "")
                when "String"
                  "\"test_#{var_name}\""
                when "Int32"
                  "42"
                when "Bool"
                  "true"
                else
                  "\"test_value\""
                end
        "#{var_name}: #{value}"
      end.join(", ")

      test_values
    end

    private def generate_template_data : String
      if template_vars.empty?
        "<!-- Template data will be available as: status, timestamp -->"
      else
        data_vars = template_vars.keys.join(", ")
        "<!-- Template data available as: #{data_vars}, timestamp -->"
      end
    end

    def success_message : String
      base_message = super
      "#{base_message} with #{template_vars.size} variable(s) using #{@template_engine}"
    end

    def post_generation_tasks : Nil
      super
      puts
      puts "📄 Page Usage:".colorize(:yellow).bold
      puts "  1. Customize the page content in src/pages/#{snake_case_name}.cr"
      puts "  2. Edit the template file in public/templates/#{snake_case_name}/"
      puts "  3. Include the page in your endpoints"
    end
  end
end