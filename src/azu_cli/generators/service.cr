require "./base"

module AzuCLI
  module Generator
    class Service < Base
      getter methods : Array(String)

      def initialize(@name : String, @project_name : String, @methods = [] of String, @force = false, @skip_tests = false)
        super(name, project_name, force, skip_tests)
        validate_name!
      end

      def generate!
        create_directories
        generate_service
        generate_tests unless skip_tests

        puts "  📝 Generated #{class_name} service".colorize(:green)
      end

      private def create_directories
        ensure_directory("src/services")
        ensure_directory("spec/services") unless skip_tests
      end

      private def generate_service
        template_vars = {
          "methods_list" => generate_methods_list,
        }

        copy_template(
          "generators/service/service.cr.ecr",
          "src/services/#{snake_case_name}.cr",
          template_vars
        )
      end

      private def generate_tests
        template_vars = {
          "methods_list" => generate_test_methods,
        }

        copy_template(
          "generators/service/service_spec.cr.ecr",
          "spec/services/#{snake_case_name}_spec.cr",
          template_vars
        )
      end

      private def generate_methods_list : String
        return default_service_methods if methods.empty?

        lines = [] of String
        methods.each do |method_name|
          lines << generate_method_definition(method_name)
        end

        lines.join("\n\n")
      end

      private def generate_test_methods : String
        test_methods = methods.empty? ? ["call"] : methods

        lines = [] of String
        test_methods.each do |method_name|
          lines << generate_test_method(method_name)
        end

        lines.join("\n\n")
      end

      private def default_service_methods : String
        generate_method_definition("call")
      end

      private def generate_method_definition(method_name : String) : String
        <<-CRYSTAL
        # #{method_name.capitalize} service method
        def #{method_name}
          log_operation("#{method_name} called")

          # TODO: Implement #{method_name} logic
          # Return success or failure result
          success("#{method_name} completed successfully")
        rescue ex : Exception
          handle_error(ex, "#{method_name} operation failed")
        end
        CRYSTAL
      end

      private def generate_test_method(method_name : String) : String
        <<-CRYSTAL
        describe "##{method_name}" do
          it "implements #{method_name} logic" do
            service = #{module_name}::#{class_name}.new
            result = service.#{method_name}

            result[:success].should be_true
            result[:error].should be_nil
          end

          it "handles errors in #{method_name}" do
            service = #{module_name}::#{class_name}.new
            # Test error scenarios
          end
        end
        CRYSTAL
      end
    end
  end
end
