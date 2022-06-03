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
    option props : Array(String), "-p Name:Type", "Request properties" { props << v }

    def run
      template_path = "#{PATH}/#{name}_#{PROGRAM}.cr".underscore

      not_exists?(template_path) do
        template(template_path)
      end

      success "Created #{PROGRAM} #{name.camelcase}#{PROGRAM} in #{template_path}"
      exit 1
    end

    private def template(template_path)
      File.open(template_path, "w") do |file|
        file.puts <<-CONTENT
        # Request Docs https://azutopia.gitbook.io/azu/endpoints/requests
        module #{project_name.camelcase}
          struct #{name.camelcase}#{PROGRAM}
            include #{PROGRAM}

            #{render_params(props)}
          end
        end
        CONTENT
      end
    end

    def render_params(kind : Array(String))
      return if kind.empty?

      String.build do |s|
        s << render_field kind
        s << "\n\t\t"
        s << render_validate kind
      end
    end
  end
end
