require "../core/abstract_generator"

module AzuCLI::Generator
  class ResponseGenerator < Core::AbstractGenerator
    property attributes : Hash(String, String)
    property response_type : String
    property format : String

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @attributes = options.attributes
      @response_type = options.custom_options["type"]? || "html"
      @format = options.custom_options["format"]? || @response_type
      super(name, project_name, options.force, options.skip_tests)
    end

    def generator_type : String
      "response"
    end

    def generate_files : Nil
      generate_response_file
      generate_template_file if @format == "html"
    end

    def create_directories : Nil
      super
      file_strategy.create_directory("src/responses")
      file_strategy.create_directory("public/templates/#{snake_case_name}") if @format == "html"
      file_strategy.create_directory("spec/responses") unless skip_tests
    end

    def generate_tests : Nil
      return if skip_tests
      test_variables = generate_test_variables
      create_file_from_template(
        "response/response_spec.cr.ecr",
        "spec/responses/#{snake_case_name}_spec.cr",
        test_variables,
        "response test"
      )
    end

    private def generate_response_file : Nil
      response_variables = generate_response_variables
      create_file_from_template(
        "response/response.cr.ecr",
        "src/responses/#{snake_case_name}.cr",
        response_variables,
        "response"
      )
    end

    private def generate_template_file : Nil
      return unless @format == "html"
      
      template_variables = generate_template_variables
      create_file_from_template(
        "response/response.jinja.ecr",
        "public/templates/#{snake_case_name}/#{snake_case_name}.jinja",
        template_variables,
        "template"
      )
    end

    private def generate_response_variables : Hash(String, String)
      default_template_variables.merge({
        "data_properties" => generate_data_properties,
        "render_method" => generate_render_method,
        "response_type" => @response_type,
        "format" => @format,
        "content_type" => get_content_type,
      })
    end

    private def generate_test_variables : Hash(String, String)
      default_template_variables.merge({
        "test_data" => generate_test_data,
        "response_type" => @response_type,
        "format" => @format,
      })
    end

    private def generate_template_variables : Hash(String, String)
      default_template_variables.merge({
        "template_data" => generate_template_data,
        "response_type" => @response_type,
      })
    end

    private def generate_data_properties : String
      return "" if attributes.empty?

      lines = [] of String
      attributes.each do |attr_name, attr_type|
        crystal_type_name = crystal_type(attr_type)
        lines << "    property #{attr_name} : #{crystal_type_name}"
      end

      lines.join("\n")
    end

    private def generate_render_method : String
      case @format
      when "json"
        generate_json_render
      when "xml"
        generate_xml_render
      when "html"
        generate_html_render
      else
        generate_default_render
      end
    end

    private def generate_json_render : String
      if attributes.empty?
        <<-CRYSTAL
        def render : String
          {
            "status" => "success",
            "timestamp" => Time.utc.to_rfc3339
          }.to_json
        end
        CRYSTAL
      else
        data_fields = attributes.keys.map { |attr| "\"#{attr}\" => @#{attr}" }.join(",\n        ")
        <<-CRYSTAL
        def render : String
          {
            #{data_fields},
            "timestamp" => Time.utc.to_rfc3339
          }.to_json
        end
        CRYSTAL
      end
    end

    private def generate_html_render : String
      <<-CRYSTAL
      def render : String
        data = {
          #{generate_template_data_hash}
        }
        template("#{snake_case_name}/#{snake_case_name}", data)
      end
      CRYSTAL
    end

    private def generate_xml_render : String
      <<-CRYSTAL
      def render : String
        builder = XML::Builder.new
        builder.element("#{snake_case_name}") do
          #{generate_xml_elements}
        end
        builder.to_s
      end
      CRYSTAL
    end

    private def generate_default_render : String
      <<-CRYSTAL
      def render : String
        "#{class_name} Response"
      end
      CRYSTAL
    end

    private def generate_template_data_hash : String
      if attributes.empty?
        "\"timestamp\" => Time.utc.to_rfc3339"
      else
        data_fields = attributes.keys.map { |attr| "\"#{attr}\" => @#{attr}" }
        data_fields << "\"timestamp\" => Time.utc.to_rfc3339"
        data_fields.join(",\n          ")
      end
    end

    private def generate_xml_elements : String
      if attributes.empty?
        "builder.element(\"timestamp\", Time.utc.to_rfc3339)"
      else
        lines = attributes.keys.map { |attr| "builder.element(\"#{attr}\", @#{attr})" }
        lines << "builder.element(\"timestamp\", Time.utc.to_rfc3339)"
        lines.join("\n          ")
      end
    end

    private def generate_test_data : String
      return "" if attributes.empty?

      test_values = attributes.map do |attr_name, attr_type|
        value = case crystal_type(attr_type).gsub("?", "")
                when "String"
                  "\"test_#{attr_name}\""
                when "Int32"
                  "42"
                when "Bool"
                  "true"
                else
                  "\"test_value\""
                end
        "#{attr_name}: #{value}"
      end.join(", ")

      test_values
    end

    private def generate_template_data : String
      if attributes.empty?
        "<!-- Template data: timestamp -->"
      else
        data_vars = attributes.keys.join(", ")
        "<!-- Template data: #{data_vars}, timestamp -->"
      end
    end

    private def get_content_type : String
      content_types = config.get_hash("response_types.#{@response_type}")
      content_types["content_type"]? || "text/html"
    end

    def success_message : String
      base_message = super
      "#{base_message} with #{@format} format"
    end

    def post_generation_tasks : Nil
      super
      puts
      puts "📄 Response Usage:".colorize(:yellow).bold
      puts "  1. Customize response rendering in src/responses/#{snake_case_name}.cr"
      puts "  2. Edit template file if using HTML format" if @format == "html"
      puts "  3. Use in your endpoints for structured responses"
    end
  end
end