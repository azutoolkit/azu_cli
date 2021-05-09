module AzuCLI
  class Endpoint
    include Base

    ARGS        = "name path request response"
    PATH        = "./src/endpoints"
    DESCRIPTION = <<-DESC
    Azu - Endpoints

    Generates an Endpoint

    The endpoint is the final stage of the request process. Each endpoint is the 
    location from which APIs can access the resources of your application to 
    carry out their function.
    
    Docs - https://azutopia.gitbook.io/azu/endpoints

    Command Arguments Definition:
      - *name: corresponds to the crystal class_name for the endpoint
      - *path: url path for the endpoint eg. `/users/:id`
      - *request: name of the request object eq. `UserDetailsRequest`
      - *response: name of the response object eq. `UsersShowPage`

      * - Required fields
    DESC

    def run
      name, route, request, response = args[0], args[1], args[2], args[3]
      method, path = route.split(":/")
      file_path = "#{PATH}/#{name}_#{PROGRAM}.cr".downcase

      not_exists?(file_path) do
        template(file_path, name, method, path, request, response)
      end

      success "Created #{PROGRAM}: #{file_path}"
      exit 1
    end

    private def template(file_path, name, method, path, request, response)
      File.open(file_path, "w") do |file|
        file.puts <<-CONTENT
        # Endpoint Docs https://azutopia.gitbook.io/azu/endpoints
        module #{project_name.camelcase}
          class #{name.camelcase}#{PROGRAM}
            include Endpoint(#{request.camelcase}Request, #{response.camelcase}Response)
        
            #{method.downcase} "/#{path.downcase}"
        
            def call : #{response.camelcase}Response
              #{response.camelcase}Response.new
            end
          end
        end
        CONTENT
      end
    end
  end
end
