require "../logger"

module AzuCLI
  module OpenAPI
    # Extracts request/contract information from Crystal code
    class RequestExtractor
      getter project_path : String

      def initialize(@project_path : String = ".")
      end

      # Extract all requests from project
      def extract : Array(RequestInfo)
        requests = [] of RequestInfo

        request_files.each do |file|
          if request_info = extract_from_file(file)
            requests << request_info
          end
        end

        requests
      end

      # Get all request files
      def request_files : Array(String)
        files = [] of String
        files.concat(Dir.glob(File.join(@project_path, "src/requests/**/*.cr")))
        files.concat(Dir.glob(File.join(@project_path, "src/contracts/**/*.cr")))
        files
      end

      # Extract request from a single file
      private def extract_from_file(file : String) : RequestInfo?
        content = File.read(file)

        # Extract struct/class definition with Azu::Request or Azu::Contract
        # Look for struct/class name first, then check if it includes Azu::Request or Azu::Contract
        if struct_match = content.match(/(?:struct|class)\s+([A-Za-z_][A-Za-z0-9_:]*)/)
          name = struct_match[1]

          # Check if this struct/class includes Azu::Request or Azu::Contract
          if content.includes?("include Azu::Request") || content.includes?("include Azu::Contract")
            properties = extract_properties(content)

            return RequestInfo.new(
              name: name,
              properties: properties,
              file: file
            )
          end
        end

        nil
      end

      # Extract properties from request content
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

      # Request information structure
      struct RequestInfo
        property name : String
        property properties : Hash(String, String)
        property file : String

        def initialize(@name, @properties, @file)
        end
      end
    end
  end
end
