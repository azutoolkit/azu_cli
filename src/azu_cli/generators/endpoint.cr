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
      property endpoint_type : String # "api" or "web"
      property snake_case_name : String
      property resource_plural : String
      property scaffold : Bool

      def initialize(@name : String, @actions : Array(String) = [] of String, @endpoint_type : String = "api", @scaffold : Bool = false)
        @snake_case_name = @name.underscore
        @resource_plural = @name.downcase.singularize.pluralize
        @actions = ["index"] if @actions.empty? # Ensure at least one action
      end

      # Convert name to endpoint struct name
      def endpoint_struct_name : String
        @name.camelcase + "Endpoint"
      end

      # Get the request/response or contract/page types based on endpoint type
      def request_type : String
        @endpoint_type == "api" ? "#{@name.camelcase}Request" : "#{@name.camelcase}Contract"
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
          components << "contract"
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
        # Create the resource subdirectory
        resource_dir = File.join(output_dir, @resource_plural)
        Dir.mkdir_p(resource_dir) unless Dir.exists?(resource_dir)

        @actions.each do |action|
          # Create a temporary generator for this action
          action_generator = ActionEndpoint.new(@name, action, @endpoint_type, @snake_case_name)
          action_generator.render(resource_dir, force: force, interactive: interactive, list: list, color: color)
        end
      end

      # Generate endpoint file content for a single action
      private def generate_endpoint_content(context : Hash(String, String)) : String
        <<-ENDPOINT
        struct #{context["endpoint_struct_name"]}
          include Azu::Endpoint(#{context["request_type"]}, #{context["response_type"]})

          #{context["http_verb"]} "#{context["full_path"]}"

          def #{context["action"].downcase} : #{context["response_type"]}
            # TODO: Implement #{context["action"].downcase} action
            # Example:
            # #{context["snake_case_name"]} = #{context["name"].camelcase}Service.#{context["action"].downcase}(request)
            # #{context["response_type"]}.new(#{context["snake_case_name"]})
            #{context["response_type"]}.new
          end
        end
        ENDPOINT
      end
    end
  end
end
