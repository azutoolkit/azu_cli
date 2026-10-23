require "teeplate"

module AzuCLI
  module Generate
    # WebSocket channel generator: an `Azu::Channel` served at `/<name>` whose clients all receive
    # every message any of them sends.
    class Channel < Teeplate::FileTree
      directory "#{__DIR__}/../templates/channel"
      OUTPUT_DIR = "."

      getter name : String
      getter snake_case_name : String
      getter camel_case_name : String
      getter app_module : String

      # Why `name` cannot name a channel, if it cannot.
      def self.name_error(name : String) : String?
        return if name.matches?(/\A[A-Za-z][A-Za-z0-9_]*\z/)
        "Invalid channel name '#{name}'. Use letters, digits and underscores, starting with a letter."
      end

      def initialize(@name : String)
        @snake_case_name = @name.underscore
        @camel_case_name = @name.camelcase
        @app_module = Utils.project_module_name
      end

      def route : String
        "/#{@snake_case_name}"
      end
    end
  end
end
