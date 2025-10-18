require "./base"

module AzuCLI
  module Plugins
    # Generator plugin for code generation functionality
    class GeneratorPlugin < Base
      def initialize
        super("generator", "Code generation plugin for Azu CLI", "1.0.0")
      end

      def before_command(command : Commands::Base, args : Array(String))
        return unless command.name == "generate"

        # Validate generator arguments
        validate_generator_args(args)
      end

      def after_command(command : Commands::Base, result : Commands::Result)
        return unless command.name == "generate"

        if result.success?
          Logger.info("Code generation completed successfully")
        else
          Logger.error("Code generation failed: #{result.error}")
        end
      end

      def on_error(command : Commands::Base, error : Exception)
        return unless command.name == "generate"

        Logger.error("Generator plugin error: #{error.message}")
      end

      private def validate_generator_args(args : Array(String))
        if args.empty?
          raise ArgumentError.new("Generator type is required. Use: azu generate <type> <name>")
        end

        generator_type = args[0]

        # Allow help and version flags to pass through
        return if generator_type.starts_with?("--help") || generator_type.starts_with?("--version") || generator_type.starts_with?("-h")

        valid_types = ["model", "endpoint", "service", "request", "contract", "page", "migration", "scaffold", "component", "middleware", "validator", "channel", "handler", "response", "template", "job", "mailer", "auth", "authentication", "validate"]

        unless valid_types.includes?(generator_type)
          raise ArgumentError.new("Invalid generator type: #{generator_type}. Valid types: #{valid_types.join(", ")}")
        end

        # Validate command doesn't require a name
        if args.size < 2 && generator_type != "validate"
          raise ArgumentError.new("Generator name is required. Use: azu generate #{generator_type} <name>")
        end
      end

      # Get available generator types
      def available_generators : Array(String)
        [
          "model - Generate CQL model with migrations",
          "endpoint - Generate REST endpoint with contracts and pages",
          "service - Generate service layer with business logic",
          "contract - Generate validation contracts",
          "page - Generate view pages with templates",
          "job - Generate background jobs",
          "middleware - Generate HTTP middleware",
          "migration - Generate database migrations",
          "scaffold - Generate complete CRUD resource",
          "component - Generate reusable components",
          "channel - Generate WebSocket channels",
          "handler - Generate request handlers",
          "request - Generate request objects",
          "response - Generate response objects",
          "validator - Generate custom validators",
        ]
      end
    end
  end
end
