require "./endpoint_extractor"
require "./model_extractor"
require "./request_extractor"
require "./response_extractor"
require "../logger"

module AzuCLI
  module OpenAPI
    # Analyzes Crystal code to extract API structure
    class Analyzer
      getter project_path : String
      getter endpoint_extractor : EndpointExtractor
      getter model_extractor : ModelExtractor
      getter request_extractor : RequestExtractor
      getter response_extractor : ResponseExtractor

      def initialize(@project_path : String = ".")
        @endpoint_extractor = EndpointExtractor.new(@project_path)
        @model_extractor = ModelExtractor.new(@project_path)
        @request_extractor = RequestExtractor.new(@project_path)
        @response_extractor = ResponseExtractor.new(@project_path)
      end

      # Analyze the project and extract all information
      def analyze
        Logger.info("Analyzing project structure...")

        endpoints = @endpoint_extractor.extract
        models = @model_extractor.extract
        requests = @request_extractor.extract
        responses = @response_extractor.extract

        Logger.info("Found #{endpoints.size} endpoint(s)")
        Logger.info("Found #{models.size} model(s)")
        Logger.info("Found #{requests.size} request(s)")
        Logger.info("Found #{responses.size} response(s)")

        {endpoints: endpoints, models: models, requests: requests, responses: responses}
      end

      # Get all endpoint files
      def endpoint_files : Array(String)
        Dir.glob(File.join(@project_path, "src/endpoints/**/*.cr"))
      end

      # Get all model files
      def model_files : Array(String)
        Dir.glob(File.join(@project_path, "src/models/**/*.cr"))
      end

      # Get all request files
      def request_files : Array(String)
        @request_extractor.request_files
      end

      # Get all response files
      def response_files : Array(String)
        @response_extractor.response_files
      end
    end
  end
end
