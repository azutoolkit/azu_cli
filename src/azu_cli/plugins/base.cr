module AzuCLI
  module Plugins
    # Base plugin class for all Azu CLI plugins
    abstract class Base
      property name : String
      property description : String
      property version : String
      property enabled : Bool

      def initialize(@name : String, @description : String = "", @version : String = "1.0.0")
        @enabled = true
      end

      # Called when plugin is loaded
      def on_load
        Logger.info("Plugin #{@name} v#{@version} loaded")
      end

      # Called when plugin is unloaded
      def on_unload
        Logger.info("Plugin #{@name} unloaded")
      end

      # Called before command execution
      def before_command(command : Commands::Base, args : Array(String))
        # Override in subclasses
      end

      # Called after command execution
      def after_command(command : Commands::Base, result : Commands::Result)
        # Override in subclasses
      end

      # Called when an error occurs
      def on_error(command : Commands::Base, error : Exception)
        # Override in subclasses
      end

      # Get plugin information
      def info : Hash(String, String)
        {
          "name"        => @name,
          "description" => @description,
          "version"     => @version,
          "enabled"     => @enabled.to_s,
        }
      end

      # Enable the plugin
      def enable
        @enabled = true
        Logger.info("Plugin #{@name} enabled")
      end

      # Disable the plugin
      def disable
        @enabled = false
        Logger.info("Plugin #{@name} disabled")
      end

      # Check if plugin is enabled
      def enabled? : Bool
        @enabled
      end
    end
  end
end
