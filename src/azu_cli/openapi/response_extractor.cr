require "../logger"

module AzuCLI
  module OpenAPI
    # Extracts response/page information from Crystal code
    class ResponseExtractor
      getter project_path : String

      def initialize(@project_path : String = ".")
      end

      # Extract all responses from project
      def extract : Array(ResponseInfo)
        responses = [] of ResponseInfo

        response_files.each do |file|
          if response_info = extract_from_file(file)
            responses << response_info
          end
        end

        responses
      end

      # Get all response files
      def response_files : Array(String)
        files = [] of String
        files.concat(Dir.glob(File.join(@project_path, "src/pages/**/*.cr")))
        files.concat(Dir.glob(File.join(@project_path, "src/responses/**/*.cr")))
        files
      end

      # Extract response from a single file
      private def extract_from_file(file : String) : ResponseInfo?
        content = File.read(file)

        # Extract struct/class definition with Azu::Response or Azu::Page
        # Look for struct/class name first, then check if it includes Azu::Response or Azu::Page
        if struct_match = content.match(/(?:struct|class)\s+([A-Za-z_][A-Za-z0-9_:]*)/)
          name = struct_match[1]

          # Check if this struct/class includes Azu::Response or Azu::Page
          if content.includes?("include Azu::Response") || content.includes?("include Azu::Page")
            properties = extract_properties(content)

            return ResponseInfo.new(
              name: name,
              properties: properties,
              file: file
            )
          end
        end

        nil
      end

      # Extract properties from response content
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

      # Response information structure
      struct ResponseInfo
        property name : String
        property properties : Hash(String, String)
        property file : String

        def initialize(@name, @properties, @file)
        end
      end
    end
  end
end
