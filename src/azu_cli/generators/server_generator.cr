require "./base"

module AzuCLI
  module Generators
    # Strategy pattern for handling server configuration
    struct ServerConfiguration
      getter handlers : Array(String)

      # Default handlers based on Azu documentation
      DEFAULT_HANDLERS = [
        "RequestId",
        "Rescuer",
        "Logger"
      ]

      def initialize(@handlers : Array(String) = DEFAULT_HANDLERS)
        @handlers = @handlers.empty? ? DEFAULT_HANDLERS : @handlers
      end

      def has_handlers?
        !@handlers.empty?
      end

      def custom_handlers?
        @handlers != DEFAULT_HANDLERS
      end
    end

    class ServerGenerator < Base
      directory "#{__DIR__}/../templates/generators/server"

      # Instance variables expected by Teeplate from template scanning
      @app_name : String
      @app_name_camelcase : String
      @handlers : Array(String)

      getter configuration : ServerConfiguration

      def initialize(app_name : String,
                     handlers : Array(String) = ServerConfiguration::DEFAULT_HANDLERS,
                     output_dir : String = ".")
        super(app_name, output_dir)
        @configuration = ServerConfiguration.new(handlers)
        @app_name = app_name
        @app_name_camelcase = app_name.camelcase
        @handlers = @configuration.handlers
      end

      def template_directory : String
        "#{__DIR__}/../templates/generators/server"
      end

      def build_output_path : String
        File.join(@output_dir, "server.cr")
      end

      # Template methods for accessing server properties
      def app_name_camelcase
        @app_name_camelcase
      end

      def app_name
        @app_name
      end

      # Delegation methods for configuration
      def handlers
        @handlers
      end

      def has_custom_handlers?
        @configuration.custom_handlers?
      end

      # Validation methods
      protected def validate_preconditions!
        super
        validate_handlers!
      end

      private def validate_handlers!
        @configuration.handlers.each do |handler|
          raise ArgumentError.new("Handler name cannot be empty") if handler.empty?
          raise ArgumentError.new("Handler must be a valid class name") unless valid_class_name?(handler)
        end
      end

      private def valid_class_name?(name : String) : Bool
        # Check if name is a valid Crystal class name (PascalCase)
        name.matches?(/^[A-Z][a-zA-Z0-9_]*$/)
      end
    end
  end
end
