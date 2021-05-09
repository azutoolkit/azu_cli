module AzuCLI
  class Request
    include Builder

    ARGS        = "[name] [query,form,path:property:type] [query,form,path:property:type]"
    PATH        = "./src/requests"
    DESCRIPTION = <<-DESC
    Azu - Request Generator
    
    Requests are designed by contract in order to enforce correctness and type 
    safe definitions

    Docs - https://azutopia.gitbook.io/azu/endpoints/requests
    DESC

    def run
      name, fields = args[0], args[1..-1]
      path = "#{PATH}/#{name}_#{PROGRAM}.cr".downcase
      not_exists?(path) { template(path, name, fields) }
      success "Created #{PROGRAM} #{name.camelcase}#{PROGRAM}"
      exit 1
    end

    private def template(path, name, fields)
      File.open(path, "w") do |file|
        file.puts <<-CONTENT
        # Request Docs https://azutopia.gitbook.io/azu/endpoints/requests
        module #{project_name.camelcase}
          struct #{name.camelcase}#{PROGRAM}
            include #{PROGRAM}

            #{render_field(fields)}
            #{render_validate(fields)}
          end
        end
        CONTENT
      end
    end
  end
end
