require "../command"
require "./generate_optimized"

module AzuCLI::Commands
  # Generate command - creates various Azu components using optimized generators
  # Delegates to the new optimized generator system
  class Generate < Command
    command_name "generate"
    description "Generate Azu components using optimized configuration-driven generators"
    usage "generate <generator_type> <name> [options]"

    def execute(args : Hash(String, String | Array(String))) : String | Nil
      # Delegate to the optimized generate command
      optimized_command = GenerateOptimized.new
      optimized_command.execute(args)
    end

    def show_command_specific_help
      # Delegate to the optimized command's help
      optimized_command = GenerateOptimized.new
      optimized_command.show_command_specific_help
    end
  end
end
