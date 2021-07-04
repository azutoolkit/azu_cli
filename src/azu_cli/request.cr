module AzuCLI
  class Request
    include Builder

    ARGS        = "-n User -p query:id:int"
    PATH        = "./src/requests"
    DESCRIPTION = <<-DESC
    #{bold "Azu - Request Generator"} - Generates a Request
    
      Requests are designed by contract in order to enforce correctness and type 
      safety

      Docs - https://azutopia.gitbook.io/azu/endpoints/requests
    DESC

    option name : String, "--name=Name", "-n Name", "Request name", ""
    option query : String, "--query=Name:Type", "-q Name:Type", "Request query properties", ""
    option path : String, "--path=Name:Type", "-p Name:Type", "Request path properties", ""
    option form : String, "--form=Name:Type", "-f Name:Type", "Request form properties", ""

    def run
      template_path = "#{PATH}/#{name}_#{PROGRAM}.cr".downcase

      not_exists?(template_path) do
        template(template_path)
      end

      success "Created #{PROGRAM} #{name.camelcase}#{PROGRAM} in #{template_path}"
      exit 1
    end

    private def template(template_path)
      query_params = query.split(" ")
      form_params = form.split(" ")

      File.open(template_path, "w") do |file|
        file.puts <<-CONTENT
        # Request Docs https://azutopia.gitbook.io/azu/endpoints/requests
        module #{project_name.camelcase}
          struct #{name.camelcase}#{PROGRAM}
            include #{PROGRAM}

            #{render_params(path)}
            #{render_params(query)}
            #{render_params(form)}
          end
        end
        CONTENT
      end
    end

    def render_params(kind)
      return if kind.empty?
      params = kind.split(" ")
      String.build do |s|
        s << render_field params
        s << "\n\t\t"
        s << render_validate params
      end
    end
  end
end
