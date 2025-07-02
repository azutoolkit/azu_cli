module AzuCLI
  module Middleware
    # Base middleware class for cross-cutting concerns
    abstract class Base
      # Called before command execution
      def before(command : Commands::Base, args : Array(String))
        # Override in subclasses
      end

      # Called after command execution
      def after(command : Commands::Base, result : Commands::Result)
        # Override in subclasses
      end

      # Called when an error occurs
      def error(command : Commands::Base, error : Exception)
        # Override in subclasses
      end
    end
  end
end
