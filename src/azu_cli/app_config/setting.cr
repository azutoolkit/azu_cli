require "json"

module AzuCLI
  module AppConfig
    # One setting of the application, as the runner reports it: `server.port = 4000`.
    struct Setting
      include JSON::Serializable

      getter section : String
      getter key : String
      getter value : String

      def initialize(@section : String, @key : String, @value : String)
      end
    end
  end
end
