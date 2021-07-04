require "topia"

module AzuCLI
  class Response
    include Builder

    ARGS        = "[name] [property:type] [property:type]"
    PATH        = "./src/responses"
    DESCRIPTION = <<-DESC
    #{bold "Azu - Response Generator"} - Generates a Request
    
      Responses is mostly an Azu implementation detail to enable more type-safe 
      definition

      Docs - https://azutopia.gitbook.io/azu/endpoints/response
    DESC

    option name : String, "--name=Name", "-n Name", "Request name", ""
    option props : String, "--props=Name:Type", "-p Name:Type", "Request properties", ""

    def run
      path = "#{PATH}/#{name}_#{PROGRAM}.cr".downcase
      not_exists?(path) { template(path) }
      success "Created #{PROGRAM} #{name.camelcase}#{PROGRAM} in #{path}"
      exit 1
    end

    private def template(path)
      File.open(path, "w") do |file|
        file.puts <<-CONTENT
        # Response Docs https://azutopia.gitbook.io/azu/endpoints/response
        module #{project_name.camelcase}
          struct #{name.camelcase}Response
            include #{PROGRAM}
        
            #{render_initialize(props.split(" "))}
        
            def render
              # Add your code here
              # You can render html, json, xml etc
            end
          end
        end
        CONTENT
      end
    end
  end
end
