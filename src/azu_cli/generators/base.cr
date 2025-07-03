require "teeplate"
require "file_utils"

module AzuCLI
  module Generators
    # Base class for all generators implementing the Template Method pattern
    # This class defines the skeleton of the generation algorithm
    abstract class Base < Teeplate::FileTree
      getter output_dir : String
      getter name : String

      def initialize(@name : String, @output_dir : String = "src")
        validate_name!
      end

      # Template method defining the generation algorithm
      def generate!
        validate_preconditions!
        prepare_output_directory!
        output_path = build_output_path
        render_template
        post_generation_hook
        output_path
      end

      # Abstract methods to be implemented by subclasses
      abstract def build_output_path : String
      abstract def template_directory : String

      # Hook methods that can be overridden by subclasses
      protected def validate_preconditions!
        # Default implementation - can be overridden
      end

      protected def prepare_output_directory!
        output_path = build_output_path
        FileUtils.mkdir_p(File.dirname(output_path))
      end

      protected def render_template
        # Use Teeplate's render method to generate files
        render(File.dirname(build_output_path))
      end

      protected def post_generation_hook
        # Default implementation - can be overridden
      end

      protected def validate_name!
        raise ArgumentError.new("Name cannot be empty") if @name.empty?
        raise ArgumentError.new("Name must be a valid identifier") unless valid_identifier?(@name)
      end

      # Utility methods for common naming conventions
      protected def name_camelcase
        @name.camelcase
      end

      protected def name_snakecase
        @name.underscore
      end

      protected def name_pluralized
        # Simple pluralization - can be enhanced with a proper pluralization library
        @name.ends_with?("s") ? @name : @name + "s"
      end

      protected def name_kebabcase
        @name.gsub(/[A-Z]/, "-\\0").downcase.lstrip("-")
      end

      private def valid_identifier?(name : String) : Bool
        # Check if name is a valid Crystal identifier
        name.matches?(/^[a-zA-Z_][a-zA-Z0-9_]*$/)
      end
    end
  end
end
