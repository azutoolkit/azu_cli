require "json"

module AzuCLI
  module RouteListing
    # One route of the application, as the runner reports it.
    struct Entry
      include JSON::Serializable

      getter method : String
      getter path : String
      getter endpoint : String
      getter request : String
      getter response : String

      def initialize(@method : String, @path : String, @endpoint : String, @request : String = "", @response : String = "")
      end

      # The template helpers Azu registers for an endpoint route (`link_to_get_posts_index`, ...): the name
      # is built from the last two segments of the class name, like `Azu::Endpoint` does. The HEAD and OPTIONS routes
      # Azu adds, and routes that are not endpoints (WebSocket channels, plain handlers), register none.
      def helpers : Array(String)
        return [] of String if request.empty? || {"HEAD", "OPTIONS"}.includes?(method)

        verb = method.downcase
        resource = Entry.helper_resource(endpoint)
        names = ["link_to_#{verb}_#{resource}"]
        names << "form_for_#{verb}_#{resource}" unless verb == "get"
        names << "button_to_delete_#{resource}" if verb == "delete"
        names
      end

      def self.helper_resource(endpoint : String) : String
        parts = endpoint.split("::")
        name = parts.size > 1 ? parts.last(2).join("_") : parts.last
        name.underscore.gsub("_endpoint", "")
      end
    end
  end
end
