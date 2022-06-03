module AzuCLI
  class Endpoint
    include Builder
    ARGS        = "-n Users -m Post -p users"
    PATH        = "./src/endpoints"
    DESCRIPTION = <<-DESC
    #{bold "Azu - Endpoints"} - Generates an Endpoint

      The endpoint is the final stage of the request process. Each endpoint is 
      the location from which APIs can access the resources of your application 
      to carry out their function.
    
      Docs - https://azutopia.gitbook.io/azu/endpoints
    DESC

    option name : String, "--name=Name", "-n Name", "Endpoint name", ""
    option method : String, "--method=Post", "-m Post", "Http method", ""
    option route : String, "--route=some/example", "-r some/path", "Route path", ""

    def run
      validate
      file_path = path(name)

      not_exists?(file_path) do
        template(file_path, name, method, route, name, name)
      end

      success "Created #{PROGRAM} for #{name.colorize.underline} in #{file_path.colorize.underline}"
      exit 1
    end

    private def validate
      errors = [] of String

      errors << "Missing option: name" if name.empty?
      errors << "Missing option: method" if method.empty?
      errors << "Missing option: route" if route.empty?

      return if errors.empty?

      error errors.join("\n")
      exit 1
    end

    private def path(name)
      "#{PATH}/#{name}_#{PROGRAM}.cr".underscore
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
