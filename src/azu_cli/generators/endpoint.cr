require "./base"

module AzuCLI
  module Generator
    class Endpoint < Base
      getter actions : Array(String)
      getter skip_routes : Bool

      def initialize(@name : String, @project_name : String, @actions = ["index"], @force = false, @skip_tests = false, @skip_routes = false)
        super(name, project_name, force, skip_tests)
        validate_name!
      end

      def generate!
        create_directories
        generate_contracts
        generate_pages
        generate_endpoints
        generate_tests unless skip_tests

        puts "  📝 Generated #{actions.size} action(s) for #{class_name} endpoint".colorize(:green)
      end

      private def create_directories
        ensure_directory("src/endpoints/#{snake_case_name}")
        ensure_directory("src/contracts/#{snake_case_name}")
        ensure_directory("src/pages/#{snake_case_name}")
        ensure_directory("spec/endpoints") unless skip_tests
      end

      private def generate_contracts
        actions.each do |action|
          template_vars = {
            "action" => action,
            "action_class" => classify(action),
          }

          copy_template(
            "generators/endpoint/#{action}_contract.cr.ecr",
            "src/contracts/#{snake_case_name}/#{action}_contract.cr",
            template_vars
          )
        end
      end

      private def generate_pages
        actions.each do |action|
          template_vars = {
            "action" => action,
            "action_class" => classify(action),
          }

          copy_template(
            "generators/endpoint/#{action}_page.cr.ecr",
            "src/pages/#{snake_case_name}/#{action}_page.cr",
            template_vars
          )
        end
      end

      private def generate_endpoints
        actions.each do |action|
          template_vars = {
            "action" => action,
            "action_class" => classify(action),
            "http_method" => http_method_for_action(action),
            "route_path" => route_path_for_action(action),
          }

          copy_template(
            "generators/endpoint/#{action}_endpoint.cr.ecr",
            "src/endpoints/#{snake_case_name}/#{action}_endpoint.cr",
            template_vars
          )
        end
      end

      private def generate_tests
        actions.each do |action|
          template_vars = {
            "action" => action,
            "action_class" => classify(action),
          }

          copy_template(
            "generators/endpoint/endpoint_spec.cr.ecr",
            "spec/endpoints/#{snake_case_name}/#{action}_endpoint_spec.cr",
            template_vars
          )
        end
      end

      private def http_method_for_action(action : String) : String
        case action
        when "index", "show", "new", "edit"
          "get"
        when "create"
          "post"
        when "update"
          "put"
        when "destroy"
          "delete"
        else
          "get"
        end
      end

      private def route_path_for_action(action : String) : String
        case action
        when "index"
          "/#{plural_name}"
        when "show"
          "/#{plural_name}/:id"
        when "new"
          "/#{plural_name}/new"
        when "create"
          "/#{plural_name}"
        when "edit"
          "/#{plural_name}/:id/edit"
        when "update"
          "/#{plural_name}/:id"
        when "destroy"
          "/#{plural_name}/:id"
        else
          "/#{plural_name}/#{action}"
        end
      end
    end
  end
end
