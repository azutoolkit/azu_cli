module AzuCLI
  class Request
    include Base

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
        class #{name.camelcase}#{PROGRAM}
          include Azu::#{PROGRAM}

          #{render_field(fields)}
        end
        CONTENT
      end
    end
  end
end
