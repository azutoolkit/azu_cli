require "topia"

module AzuCLI
  # Adapter class to integrate our Command classes with Topia framework
  class TopiaAdapter(T) < Topia::Plugin

    def initialize(@command : T)
    end

    def run(input, args : Array(String))
      # Execute the command
      result = @command.run(input, args)
      result.to_s
    rescue ex : Exception
      Logger.exception(ex, "Command execution failed")
      ""
    end

    def on(event : String)
      # Handle Topia events if needed
    end
  end

  # Factory methods to create Topia-compatible plugins from our commands
  module TopiaFactory
    def self.wrap(command_class : T.class) : TopiaAdapter(T) forall T
      TopiaAdapter.new(command_class.new)
    end
  end
end
