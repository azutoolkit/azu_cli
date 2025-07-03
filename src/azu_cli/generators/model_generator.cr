require "./base"

module AzuCLI
  module Generators
    # Type aliases for better readability and maintainability
    alias AttributeDefinition = NamedTuple(name: String, type: String, nullable: Bool)
    alias AssociationDefinition = NamedTuple(type: String, name: String, model: String, foreign_key: String)
    alias ValidationDefinition = NamedTuple(field: String, rules: Array(String))

    # Strategy pattern for handling different types of model configurations
    struct ModelConfiguration
      getter attributes : Array(AttributeDefinition)
      getter associations : Array(AssociationDefinition)
      getter validations : Array(ValidationDefinition)

      def initialize(@attributes : Array(AttributeDefinition) = [] of AttributeDefinition,
                     @associations : Array(AssociationDefinition) = [] of AssociationDefinition,
                     @validations : Array(ValidationDefinition) = [] of ValidationDefinition)
      end

      def has_attributes?
        !@attributes.empty?
      end

      def has_associations?
        !@associations.empty?
      end

      def has_validations?
        !@validations.empty?
      end
    end

    class ModelGenerator < Base
      directory "#{__DIR__}/../templates/generators/model"

      # Instance variables expected by Teeplate from template scanning
      @model_name : String
      @model_name_camelcase : String
      @model_name_pluralized : String
      @attributes : Array(AttributeDefinition)
      @associations : Array(AssociationDefinition)
      @validations : Array(ValidationDefinition)

      getter configuration : ModelConfiguration

      def initialize(model_name : String,
                     attributes : Array(AttributeDefinition) = [] of AttributeDefinition,
                     associations : Array(AssociationDefinition) = [] of AssociationDefinition,
                     validations : Array(ValidationDefinition) = [] of ValidationDefinition,
                     output_dir : String = "src",
                     generate_specs : Bool = true)
        super(model_name, output_dir, generate_specs)
        @configuration = ModelConfiguration.new(attributes, associations, validations)
        @model_name = model_name
        @model_name_camelcase = model_name.camelcase
        @model_name_pluralized = model_name.ends_with?("s") ? model_name : model_name + "s"
        @attributes = attributes
        @associations = associations
        @validations = validations
      end

      def template_directory : String
        "#{__DIR__}/../templates/generators/model"
      end

      def build_output_path : String
        File.join(@output_dir, "models", "#{@name}.cr")
      end

      # Override spec template name to match our template
      protected def spec_template_name : String
        "#{model_name}_spec.cr.ecr"
      end

      # Template methods for accessing model properties
      def model_name_camelcase
        @model_name_camelcase
      end

      def model_name_pluralized
        @model_name_pluralized
      end

      def model_name
        @model_name
      end

      # Delegation methods for configuration
      def attributes
        @attributes
      end

      def associations
        @associations
      end

      def validations
        @validations
      end

      # Validation methods
      protected def validate_preconditions!
        super
        validate_attributes!
        validate_associations!
        validate_validations!
      end

      private def validate_attributes!
        @configuration.attributes.each do |attr|
          raise ArgumentError.new("Attribute name cannot be empty") if attr[:name].empty?
          raise ArgumentError.new("Attribute type cannot be empty") if attr[:type].empty?
        end
      end

      private def validate_associations!
        @configuration.associations.each do |assoc|
          raise ArgumentError.new("Association name cannot be empty") if assoc[:name].empty?
          raise ArgumentError.new("Association model cannot be empty") if assoc[:model].empty?
        end
      end

      private def validate_validations!
        @configuration.validations.each do |validation|
          raise ArgumentError.new("Validation field cannot be empty") if validation[:field].empty?
          raise ArgumentError.new("Validation rules cannot be empty") if validation[:rules].empty?
        end
      end
    end
  end
end
