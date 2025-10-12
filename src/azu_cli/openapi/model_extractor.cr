require "../logger"

module AzuCLI
  module OpenAPI
    # Extracts model information from Crystal code
    class ModelExtractor
      getter project_path : String

      def initialize(@project_path : String = ".")
      end

      # Extract all models from project
      def extract : Array(ModelInfo)
        models = [] of ModelInfo

        model_files.each do |file|
          if model_info = extract_from_file(file)
            models << model_info
          end
        end

        models
      end

      # Get all model files
      private def model_files : Array(String)
        Dir.glob(File.join(@project_path, "src/models/**/*.cr"))
      end

      # Extract model from a single file
      private def extract_from_file(file : String) : ModelInfo?
        content = File.read(file)

        # Extract struct/class definition
        if match = content.match(/(?:struct|class)\s+(\w+)/)
          name = match[1]
          properties = extract_properties(content)

          return ModelInfo.new(
            name: name,
            properties: properties,
            file: file
          )
        end

        nil
      end

      # Extract properties from model content
      private def extract_properties(content : String) : Hash(String, String)
        properties = {} of String => String

        # Match property definitions: property name : Type
        content.scan(/property\s+(\w+)\s*:\s*([^\n]+)/) do |match|
          prop_name = match[1]
          prop_type = match[2].strip
          properties[prop_name] = prop_type
        end

        # Match getter definitions: getter name : Type
        content.scan(/getter\s+(\w+)\s*:\s*([^\n]+)/) do |match|
          prop_name = match[1]
          prop_type = match[2].strip
          properties[prop_name] ||= prop_type
        end

        properties
      end

      # Model information structure
      struct ModelInfo
        property name : String
        property properties : Hash(String, String)
        property file : String

        def initialize(@name, @properties, @file)
        end
      end
    end
  end
end
