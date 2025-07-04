require "teeplate"

module AzuCLI
  module Generate
    # Endpoint generator that creates Azu::Endpoint structs
    class Endpoint < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/endpoints"

      property name : String
      property actions : Array(String)
      property endpoint_type : String # "api" or "web"
      property snake_case_name : String
      property scaffold : Bool

      def initialize(@name : String, @actions : Array(String) = [] of String, @endpoint_type : String = "api", @scaffold : Bool = false)
        @snake_case_name = @name.underscore
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
        base_path = "/#{@snake_case_name}"
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

      # Get API prefix for paths
      def api_prefix : String
        @endpoint_type == "api" ? "/api" : ""
      end

      # Get full path with API prefix
      def full_path(action : String) : String
        "#{api_prefix}#{action_path(action)}"
      end

      # Generate endpoint methods for each action
      def endpoint_methods : String
        methods = [] of String

        @actions.each do |action|
          verb = http_verb(action)
          path = full_path(action)
          method_name = action.downcase

          methods << <<-METHOD
                        #{verb} "#{path}"

                        def #{method_name} : #{response_type}
                          # TODO: Implement #{method_name} action
                          # Example:
                          # #{@snake_case_name} = #{@name.camelcase}Service.#{method_name}(request)
                          # #{response_type}.new(#{@snake_case_name})
                          #{response_type}.new
                        end
                      METHOD
        end

        methods.join("\n\n")
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

      # Get default actions if none provided
      def default_actions : Array(String)
        ["index", "show", "create", "update", "destroy"]
      end

      # Get actions to use (default or provided)
      def effective_actions : Array(String)
        @actions.empty? ? default_actions : @actions
      end
    end
  end
end
