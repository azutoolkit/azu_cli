require "teeplate"
require "ecr"
require "./action"

module AzuCLI
  module Generate
    # Endpoint generator that creates Azu::Endpoint structs
    class Endpoint < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/endpoints"
      OUTPUT_DIR = "./src/endpoints"

      property name : String
      property actions : Array(String)
      property action : String = ""
      property endpoint_type : String # "api" or "web"
      property snake_case_name : String
      property resource_plural : String
      property resource_singular : String
      property module_name : String
      property fields : Hash(String, String)
      property scaffold : Bool

      def initialize(@name : String, @actions : Array(String) = [] of String, @endpoint_type : String = "api", @scaffold : Bool = false, module_name : String? = nil)
        @snake_case_name = @name.underscore
        @resource_plural = @name.downcase.singularize.pluralize
        @resource_singular = @name.downcase.singularize
        # Get module name from parameter or project
        @module_name = module_name || get_project_module_name
        @fields = {} of String => String
        @actions = ["index"] if @actions.empty? # Ensure at least one action
      end

      # Get project module name from shard.yml
      private def get_project_module_name : String
        return "App" unless File.exists?("./shard.yml")
        shard_yml = YAML.parse(File.read("./shard.yml"))
        project_name = shard_yml["name"].as_s
        project_name.split(/[-_]/).map(&.capitalize).join
      rescue
        "App"
      end

      # Convert name to endpoint struct name
      def endpoint_struct_name : String
        @name.camelcase + "Endpoint"
      end

      # Get the request/response types based on endpoint type
      def request_type : String
        "#{@name.camelcase}Request"
      end

      def response_type : String
        @endpoint_type == "api" ? "#{@name.camelcase}Response" : "#{@name.camelcase}Page"
      end

      # Get HTTP verb for action
      def http_verb(action : String) : String
        case action.downcase
        when "index", "show", "new", "edit"
          "get"
        when "create"
          "post"
        when "update"
          "patch"
        when "destroy", "delete"
          "delete"
        else
          "get"
        end
      end

      # Get path for action
      def action_path(action : String) : String
        base_path = "/#{@resource_plural}"
        case action.downcase
        when "index"
          base_path
        when "new"
          "#{base_path}/new"
        when "create"
          base_path
        when "show"
          "#{base_path}/:id"
        when "edit"
          "#{base_path}/:id/edit"
        when "update"
          "#{base_path}/:id"
        when "destroy", "delete"
          "#{base_path}/:id"
        else
          base_path
        end
      end

      # Get full path for action
      def full_path(action : String) : String
        action_path(action)
      end

      # Get scaffold components to generate
      def scaffold_components : Array(String)
        return [] of String unless @scaffold

        components = [] of String

        if @endpoint_type == "api"
          components << "request"
          components << "response"
        else
          components << "request"
          components << "page"
        end

        components
      end

      # Check if endpoint has actions
      def has_actions? : Bool
        !@actions.empty?
      end

      # Get actions to use (actions are always required)
      def effective_actions : Array(String)
        @actions
      end

      # Override render to create one file per action
      def render(output_dir : String, force : Bool = false, interactive : Bool = true, list : Bool = false, color : Bool = false)
        # Create the resource subdirectory (use plural form per memory)
        resource_dir = File.join(output_dir, @resource_plural)
        Dir.mkdir_p(resource_dir) unless Dir.exists?(resource_dir)

        @actions.each do |action|
          # Generate endpoint file directly using the specific template
          generate_endpoint_file(resource_dir, action, force)
        end
      end

      # Generate individual endpoint file using specific template
      private def generate_endpoint_file(output_dir : String, action : String, force : Bool = false)
        template_file = "#{__DIR__}/../templates/scaffold/src/endpoints/{{snake_case_name}}_#{action}_endpoint.cr.ecr"
        output_file = File.join(output_dir, "#{@resource_singular}_#{action}_endpoint.cr")

        return if File.exists?(output_file) && !force

        # Read and process the template
        template_content = File.read(template_file)

        # Simple template variable replacement
        content = template_content
          .gsub("{{snake_case_name}}", @snake_case_name)
          .gsub("{{action}}", action)
          .gsub("<%= @module_name %>", @module_name)
          .gsub("<%= @name.camelcase %>", @name.camelcase)
          .gsub("<%= @action.camelcase %>", action.camelcase)
          .gsub("<%= @endpoint_type == \"api\" ? \"Response\" : \"Page\" %>", @endpoint_type == "api" ? "Response" : "Page")
          .gsub("<%= @endpoint_type == \"api\" ? \"Response\" : \"Page\" %>", @endpoint_type == "api" ? "Response" : "Page")
          .gsub("<%= @resource_singular %>", @resource_singular)
          .gsub("<%= @resource_plural %>", @resource_plural)
          .gsub("<%= @scaffold %>", @scaffold.to_s)
          .gsub("<%= action_path %>", action_path(action))
          .gsub("<%= request_params %>", request_params_for_action(action))
          .gsub("<%= http_verb_action %>", http_verb(action))

        File.write(output_file, content)
      end

      # Get request parameters for specific action
      private def request_params_for_action(action : String) : String
        case action.downcase
        when "create", "update"
          return "" if @fields.empty?
          @fields.keys.map { |field| "@request.#{field}" }.join(", ")
        else
          ""
        end
      end
    end
  end
end
