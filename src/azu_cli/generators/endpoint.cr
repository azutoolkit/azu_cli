require "./resource"
require "./navigation"

module AzuCLI
  module Generate
    # Endpoint generator: the Azu::Endpoint of one CRUD action. A "web" endpoint renders a page
    # (or redirects with 303 after a write); an "api" endpoint answers with JSON.
    class Endpoint < Resource
      directory "#{__DIR__}/../templates/scaffold/src/endpoints"
      OUTPUT_DIR = "./src/endpoints"
      ACTIONS    = CRUD_ACTIONS

      getter endpoint_type : String

      def initialize(name : String, action : String, @endpoint_type : String = "web")
        super(name, action)
      end

      def api? : Bool
        @endpoint_type == "api"
      end

      def render(out_dir : String, force : Bool = false, interactive : Bool = false, list : Bool = false, color : Bool = false)
        super
        if !api? && @action == "index"
          Navigation.register(File.expand_path("../..", out_dir), @resource_plural.split('_').map(&.capitalize).join(' '), route)
        end
      end

      def verb : String
        case @action
        when "create"  then "post"
        when "update"  then "patch"
        when "destroy" then "delete"
        else                "get"
        end
      end

      def route : String
        base = "/#{@resource_plural}"
        case @action
        when "new"                       then "#{base}/new"
        when "show", "update", "destroy" then "#{base}/:id"
        when "edit"                      then "#{base}/:id/edit"
        else                                  base
        end
      end

      def request_type : String
        "#{@namespace}::#{action_class}Request"
      end

      # Reads answer with a page (or JSON response); writes redirect (web) or answer with the record.
      def response_type : String
        case @action
        when "destroy"          then "Azu::Response::Empty"
        when "create", "update" then api? ? "#{@namespace}::ShowResponse" : "Azu::Response::Empty"
        else                         "#{@namespace}::#{action_class}#{api? ? "Response" : "Page"}"
        end
      end

      # Finds the record of a member route or answers 404. The id comes from the typed request, except
      # for an update: its JSON body does not carry the id of the path.
      def find_record : String
        id = @action == "update" ? %(params["id"].to_i64? || 0) : "#{@action}_request.id"
        "#{model_name}.find?(#{id}) || raise Azu::Response::NotFound.new(context.request.path)"
      end
    end
  end
end
