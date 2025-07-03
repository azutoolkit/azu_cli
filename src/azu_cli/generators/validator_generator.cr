require "./base"

module AzuCLI
  module Generators
    # Strategy pattern for handling validator configuration
    struct ValidatorConfiguration
      getter model_name : String

      def initialize(@model_name : String)
      end

      def has_model?
        !@model_name.empty?
      end

      def model_name_camelcase
        @model_name.camelcase
      end

      def model_name_snakecase
        @model_name.underscore
      end
    end

    class ValidatorGenerator < Base
      directory "#{__DIR__}/../templates/generators/validator"

      # Instance variables expected by Teeplate from template scanning
      @validator_name : String
      @validator_name_camelcase : String
      @model_name_camelcase : String

      getter configuration : ValidatorConfiguration

      def initialize(validator_name : String,
                     model_name : String,
                     output_dir : String = "src")
        super(validator_name, output_dir)
        @configuration = ValidatorConfiguration.new(model_name)
        @validator_name = validator_name
        @validator_name_camelcase = validator_name.camelcase
        @model_name_camelcase = model_name.camelcase
      end

      def template_directory : String
        "#{__DIR__}/../templates/generators/validator"
      end

      def build_output_path : String
        File.join(@output_dir, "validators", "#{@name}.cr")
      end

      # Template methods for accessing validator properties
      def validator_name_camelcase
        @validator_name_camelcase
      end

      def validator_name
        @validator_name
      end

      # Delegation methods for configuration
      def model_name
        @configuration.model_name
      end

      def model_name_camelcase
        @model_name_camelcase
      end

      def model_name_snakecase
        @configuration.model_name_snakecase
      end

      # Validation methods
      protected def validate_preconditions!
        super
        validate_model_name!
      end

      private def validate_model_name!
        raise ArgumentError.new("Model name cannot be empty") if @configuration.model_name.empty?
        raise ArgumentError.new("Model name must be a valid identifier") unless valid_identifier?(@configuration.model_name)
      end

      private def valid_identifier?(name : String) : Bool
        # Check if name is a valid Crystal identifier
        name.matches?(/^[a-zA-Z_][a-zA-Z0-9_]*$/)
      end
    end
  end
end
