module AzuCLI
  class Endpoint
    include Helpers
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

    @@class_name : String = self.name.split("::").last

    def run
      name, route, request, response = args[0], args[1], args[2], args[3]
      method, path = route.split(":/")

      announce "Generating #{name.camelcase}#{@@class_name}"
      template(name, method, path, request, response)
      announce "Generating #{name.camelcase}#{@@class_name}"

      true
    rescue e
      error "Endpoint generation failed! #{e.message}"
    end

    private def template(name, method, path, request, response)
      File.open("#{PATH}/#{name}_#{@@class_name}.cr".downcase, "w") do |file|
        file.puts <<-CONTENT
        class #{name.camelcase}#{@@class_name}
          include Azu::Endpoint(#{request.camelcase}, #{response.camelcase})
          
          #{method.downcase} "/#{path.downcase}"
    
          def call : #{response.camelcase}
          end
        end
        CONTENT
      end
    end
  end
end
