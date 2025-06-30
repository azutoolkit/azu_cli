require "./base"

module AzuCLI
  module Generator
    class Middleware < Base
      def initialize(@name : String, @project_name : String, @force = false, @skip_tests = false)
        super(name, project_name, force, skip_tests)
        validate_name!
      end

      def generate!
        create_directories
        generate_middleware
        generate_tests unless skip_tests

        puts "  📝 Generated #{class_name} middleware".colorize(:green)
      end

      private def create_directories
        ensure_directory("src/middleware")
        ensure_directory("spec/middleware") unless skip_tests
      end

      private def generate_middleware
        copy_template(
          "generators/middleware/middleware.cr.ecr",
          "src/middleware/#{snake_case_name}.cr"
        )
      end

      private def generate_tests
        copy_template(
          "generators/middleware/middleware_spec.cr.ecr",
          "spec/middleware/#{snake_case_name}_spec.cr"
        )
      end
    end
  end
end
