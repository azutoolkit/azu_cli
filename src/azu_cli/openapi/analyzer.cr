require "./endpoint_extractor"
require "./model_extractor"
require "../logger"

module AzuCLI
  module OpenAPI
    # Analyzes Crystal code to extract API structure
    class Analyzer
      getter project_path : String
      getter endpoint_extractor : EndpointExtractor
      getter model_extractor : ModelExtractor

      def initialize(@project_path : String = ".")
        @endpoint_extractor = EndpointExtractor.new(@project_path)
        @model_extractor = ModelExtractor.new(@project_path)
      end

      # Analyze the project and extract all information
      def analyze
        Logger.info("Analyzing project structure...")

        endpoints = @endpoint_extractor.extract
        models = @model_extractor.extract

        Logger.info("Found #{endpoints.size} endpoint(s)")
        Logger.info("Found #{models.size} model(s)")

        {endpoints: endpoints, models: models}
      end

      # Get all endpoint files
      def endpoint_files : Array(String)
        Dir.glob(File.join(@project_path, "src/endpoints/**/*.cr"))
      end

      # Get all model files
      def model_files : Array(String)
        Dir.glob(File.join(@project_path, "src/models/**/*.cr"))
      end
    end
  end
end
