module AzuCLI
  module Generate
    # Single action endpoint generator for Teeplate
    class ActionEndpoint < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/endpoints"

      property name : String
      property action : String
      property endpoint_type : String
      property snake_case_name : String
      property resource_plural : String

      def initialize(@name : String, @action : String, @endpoint_type : String, @snake_case_name : String)
        @resource_plural = @name.downcase.singularize.pluralize
      end

      def name_action : String
        "#{@name.camelcase}#{@action.camelcase}"
      end

      # Convert name to endpoint struct name for this action
      def endpoint_struct_name : String
        "#{name_action}Endpoint"
      end

      # Get the request/response or contract/page types based on endpoint type
      def request_type : String
        @endpoint_type == "api" ? "#{name_action}Request" : "#{name_action}Contract"
      end

      def response_type : String
        @endpoint_type == "api" ? "#{name_action}Response" : "#{name_action}Page"
      end

      # Get HTTP verb for this action as a variable
      def http_verb_action : String
        case @action.downcase
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

      # Get path for this action
      def action_path : String
        base_path = "/#{@resource_plural}"
        case @action.downcase
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
      def full_path : String
        action_path
      end
    end
  end
end
