require "topia"

module AzuCLI
  class Response
    include Builder

    ARGS        = "[name] [property:type] [property:type]"
    PATH        = "./src/responses"
    DESCRIPTION = <<-DESC
    Azu - Response Generator
    
    Responses is mostly an Azu implementation detail to enable more type-safe 
    definition

    Docs - https://azutopia.gitbook.io/azu/endpoints/response
    DESC

    def run
      name, fields = args[0], args[1..-1]
      class_name = "#{name.camelcase}#{PROGRAM}"
      path = "#{PATH}/#{name}_#{PROGRAM}.cr".downcase

      not_exists?(path) { template(path, name, fields) }
      success "Created #{PROGRAM} #{class_name}"
      exit 1
    end

    private def template(path, name, fields)
      File.open(path, "w") do |file|
        file.puts <<-CONTENT
        # Response Docs https://azutopia.gitbook.io/azu/endpoints/response
        module #{project_name.camelcase}
          struct #{name.camelcase}Response
            include #{PROGRAM}
        
            #{render_initialize(fields)}
        
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
