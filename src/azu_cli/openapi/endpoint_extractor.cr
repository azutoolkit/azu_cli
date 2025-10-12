require "../logger"

module AzuCLI
  module OpenAPI
    # Extracts endpoint information from Crystal code
    class EndpointExtractor
      getter project_path : String

      def initialize(@project_path : String = ".")
      end

      # Extract all endpoints from project
      def extract : Array(EndpointInfo)
        endpoints = [] of EndpointInfo

        endpoint_files.each do |file|
          endpoints.concat(extract_from_file(file))
        end

        endpoints
      end

      # Get all endpoint files
      private def endpoint_files : Array(String)
        Dir.glob(File.join(@project_path, "src/endpoints/**/*_endpoint.cr"))
      end

      # Extract endpoints from a single file
      private def extract_from_file(file : String) : Array(EndpointInfo)
        endpoints = [] of EndpointInfo
        content = File.read(file)

        # Simple regex-based extraction (can be improved with proper parser)
        # Looking for patterns like: get "/users/:id"

        # Extract struct definition
        if match = content.match(/struct\s+(\w+(?:::\w+)*Endpoint)/)
          struct_name = match[1]

          # Extract HTTP method and path
          http_methods = ["get", "post", "put", "patch", "delete", "head", "options"]
          http_methods.each do |method|
            if path_match = content.match(/#{method}\s+"([^"]+)"/)
              path = path_match[1]

              # Extract request and response types from include statement
              if include_match = content.match(/include\s+Azu::Endpoint\(([^,]+),\s*([^)]+)\)/)
                request_type = include_match[1].strip
                response_type = include_match[2].strip

                endpoints << EndpointInfo.new(
                  name: struct_name,
                  method: method,
                  path: path,
                  request_type: request_type,
                  response_type: response_type,
                  file: file
                )
              end
            end
          end
        end

        endpoints
      end

      # Endpoint information structure
      struct EndpointInfo
        property name : String
        property method : String
        property path : String
        property request_type : String
        property response_type : String
        property file : String

        def initialize(@name, @method, @path, @request_type, @response_type, @file)
        end
      end
    end
  end
end
