require "./base"

module AzuCLI
  module Plugins
    # External plugin for loading plugins from external sources
    class ExternalPlugin < Base
      property config : Hash(String, String)

      def initialize(@name : String, @config : Hash(String, String))
        description = @config["description"]? || "External plugin: #{@name}"
        version = @config["version"]? || "1.0.0"
        super(@name, description, version)
      end

      def on_load
        Logger.info("External plugin #{@name} v#{@version} loaded")
        Logger.debug("Plugin config: #{@config}")
      end

      def before_command(command : Commands::Base, args : Array(String))
        # External plugins can override this to add custom behavior
        if hook = @config["before_command"]?
          execute_hook(hook, command, args)
        end
      end

      def after_command(command : Commands::Base, result : Commands::Result)
        # External plugins can override this to add custom behavior
        if hook = @config["after_command"]?
          execute_hook(hook, command, result)
        end
      end

      def on_error(command : Commands::Base, error : Exception)
        # External plugins can override this to add custom behavior
        if hook = @config["on_error"]?
          execute_hook(hook, command, error)
        end
      end

      private def execute_hook(hook : String, *args)
        # This would execute external plugin hooks
        # For now, just log the hook execution
        Logger.debug("Executing external plugin hook: #{hook}")
      end

      # Get plugin configuration
      def get_config(key : String, default : String = "") : String
        @config[key]? || default
      end

      # Check if plugin has specific configuration
      def has_config?(key : String) : Bool
        @config.has_key?(key)
      end
    end
  end
end
