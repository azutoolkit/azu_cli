require "topia"

module AzuCLI
  # Adapter class to integrate our Command classes with Topia framework
  class TopiaAdapter(T) < Topia::Plugin

    def initialize(@command : T)
    end

    def run(input, args = [] of String)
      # Convert args to the format expected by our Command classes
      parsed_args = {} of String => String | Array(String)
      parsed_args["_positional"] = args

      # Execute the command
      result = @command.execute(parsed_args)
      result.to_s if result
    rescue ex : Exception
      STDERR.puts "Command execution failed: #{ex.message}"
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
