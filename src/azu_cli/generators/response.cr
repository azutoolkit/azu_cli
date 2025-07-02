require "./base"

module AzuCLI
  module Generator
    class Response < Base
      getter attributes : Hash(String, String)
      getter template_name : String
      getter response_format : String

      def initialize(@name : String, @project_name : String, @attributes = Hash(String, String).new, @template_name = "", @response_format = "html", @force = false, @skip_tests = false)
        super(name, project_name, force, skip_tests)
        validate_name!
      end

      def generate!
        create_directories
        generate_response
        generate_template unless response_format == "json"
        generate_tests unless skip_tests

        puts "  📤 Generated #{class_name}Response".colorize(:green)
        show_response_usage_info
      end

      private def create_directories
        ensure_directory("src/responses")
        ensure_directory("public/templates/#{snake_case_name}") unless response_format == "json"
        ensure_directory("spec/responses") unless skip_tests
      end

      private def generate_response
        template_variables = {
          "attributes_list"    => generate_attributes_list,
          "constructor"        => generate_constructor,
          "render_method"      => generate_render_method,
          "data_method"        => generate_data_method,
          "response_helpers"   => generate_response_helpers,
        }

        copy_template(
          "generators/response/response.cr.ecr",
          "src/responses/#{snake_case_name}_response.cr",
          template_variables
        )
      end

      private def generate_template
        template_file = template_name.empty? ? "#{snake_case_name}.jinja" : template_name

        template_variables = {
          "template_data" => generate_template_data,
        }

        copy_template(
          "generators/response/response.jinja.ecr",
          "public/templates/#{snake_case_name}/#{template_file}",
          template_variables
        )
      end

      private def generate_tests
        template_variables = {
          "test_attributes"     => generate_test_attributes,
          "render_tests"        => generate_render_tests,
          "format_tests"        => generate_format_tests,
        }

        copy_template(
          "generators/response/response_spec.cr.ecr",
          "spec/responses/#{snake_case_name}_response_spec.cr",
          template_variables
        )
      end

      private def generate_attributes_list : String
        lines = [] of String

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

        attributes.each do |attr_name, attr_type|
          crystal_type = crystal_type(attr_type)
          nullable = attr_type.ends_with?("?")

          if nullable
            constructor_params << "@#{attr_name} : #{crystal_type}? = nil"
          else
            constructor_params << "@#{attr_name} : #{crystal_type}"
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

      private def generate_render_method : String
        case response_format.downcase
        when "json"
          generate_json_render_method
        when "html"
          generate_html_render_method
        when "xml"
          generate_xml_render_method
        else
          generate_html_render_method
        end
      end

      private def generate_json_render_method : String
        <<-CRYSTAL
        def render
          data.to_json
        end

        def content_type : String
          "application/json"
        end
        CRYSTAL
      end

      private def generate_html_render_method : String
        template_file = template_name.empty? ? "#{snake_case_name}.jinja" : template_name

        <<-CRYSTAL
        def render
          view template: "#{snake_case_name}/#{template_file}", data: data
        end

        def content_type : String
          "text/html"
        end
        CRYSTAL
      end

      private def generate_xml_render_method : String
        <<-CRYSTAL
        def render
          builder = XML::Builder.new
          builder.element("#{snake_case_name}") do
            data.each do |key, value|
              builder.element(key.to_s, value.to_s)
            end
          end
          builder.to_xml
        end

        def content_type : String
          "application/xml"
        end
        CRYSTAL
      end

      private def generate_data_method : String
        if attributes.empty?
          return <<-CRYSTAL
          def data
            {
              "status" => "success",
              "timestamp" => Time.utc.to_rfc3339
            }
          end
          CRYSTAL
        end

        data_items = [] of String
        attributes.each do |attr_name, _|
          data_items << "\"#{attr_name}\" => @#{attr_name}"
        end

        <<-CRYSTAL
        def data
          {
            #{data_items.join(",\n        ")},
            "timestamp" => Time.utc.to_rfc3339
          }
        end
        CRYSTAL
      end

      private def generate_response_helpers : String
        <<-CRYSTAL

        # HTTP status helpers
        def status_code : Int32
          200
        end

        def success? : Bool
          status_code >= 200 && status_code < 300
        end

        def headers : Hash(String, String)
          {
            "Content-Type" => content_type,
            "Cache-Control" => "no-cache"
          }
        end
        CRYSTAL
      end

      private def generate_template_data : String
        if attributes.empty?
          return "<!-- Template data will be available as: status, timestamp -->"
        end

        data_vars = attributes.keys.map { |attr| attr }.join(", ")
        "<!-- Template data available as: #{data_vars}, timestamp -->"
      end

      private def generate_test_attributes : String
        attr_values = [] of String

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

      private def generate_render_tests : String
        case response_format.downcase
        when "json"
          <<-CRYSTAL
          it "renders JSON response" do
            response = #{module_name}::#{class_name}Response.new(#{generate_example_params})
            rendered = response.render

            rendered.should be_a(String)
            JSON.parse(rendered).should be_a(JSON::Any)
          end

          it "has correct content type" do
            response = #{module_name}::#{class_name}Response.new(#{generate_example_params})
            response.content_type.should eq("application/json")
          end
          CRYSTAL
        when "xml"
          <<-CRYSTAL
          it "renders XML response" do
            response = #{module_name}::#{class_name}Response.new(#{generate_example_params})
            rendered = response.render

            rendered.should be_a(String)
            rendered.should contain("<?xml")
          end

          it "has correct content type" do
            response = #{module_name}::#{class_name}Response.new(#{generate_example_params})
            response.content_type.should eq("application/xml")
          end
          CRYSTAL
        else
          <<-CRYSTAL
          it "renders HTML template" do
            response = #{module_name}::#{class_name}Response.new(#{generate_example_params})

            # Test that render method returns template content
            response.should respond_to(:render)
          end

          it "has correct content type" do
            response = #{module_name}::#{class_name}Response.new(#{generate_example_params})
            response.content_type.should eq("text/html")
          end
          CRYSTAL
        end
      end

      private def generate_format_tests : String
        <<-CRYSTAL

        describe "status and headers" do
          it "returns correct status code" do
            response = #{module_name}::#{class_name}Response.new(#{generate_example_params})
            response.status_code.should eq(200)
            response.success?.should be_true
          end

          it "provides correct headers" do
            response = #{module_name}::#{class_name}Response.new(#{generate_example_params})
            headers = response.headers

            headers["Content-Type"].should eq(response.content_type)
            headers.should have_key("Cache-Control")
          end
        end

        describe "data method" do
          it "provides data for template rendering" do
            response = #{module_name}::#{class_name}Response.new(#{generate_example_params})
            data = response.data

            data.should be_a(Hash(String, String | Int32 | Int64 | Float64 | Bool | Time))
            data.should have_key("timestamp")
          end
        end
        CRYSTAL
      end

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
                  when "Time"
                    "Time.utc"
                  else
                    "\"example\""
                  end
          params << "#{attr_name}: #{value}"
        end

        params.join(", ")
      end

      private def show_response_usage_info
        puts
        puts "📤 Response Usage:".colorize(:yellow).bold
        puts "  1. Use in your endpoints:"
        puts "     struct MyEndpoint"
        puts "       include Azu::Endpoint(MyRequest, #{class_name}Response)"
        puts "       def call : #{class_name}Response"
        puts "         #{class_name}Response.new(#{generate_example_params})"
        puts "       end"
        puts "     end"
        puts
        puts "  2. Manual response creation:"
        puts "     response = #{class_name}Response.new(#{generate_example_params})"
        puts "     content = response.render"
        puts "     status = response.status_code"
        puts
        puts "💡 Response Features:".colorize(:blue).bold
        puts "  - Format: #{response_format.upcase}"
        puts "  - Content negotiation support"
        puts "  - Automatic data serialization"
        unless response_format == "json"
          puts "  - Template rendering with Jinja"
        end
        puts "  - HTTP status and header management"
        puts
        puts "📚 Learn more: https://azutopia.gitbook.io/azu/responses".colorize(:cyan)
      end
    end
  end
end
