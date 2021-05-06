module AzuCLI
  class Request
    include Helpers
    include Base

    ARGS        = "[name] [query,form,path:property:type] [query,form,path:property:type]"
    PATH        = "./src/requests"
    DESCRIPTION = <<-DESC
    Azu - Requests
    
    Requests are designed by contract in order to enforce correctness and type 
    safe definitions

    Docs - https://azutopia.gitbook.io/azu/endpoints/requests
    DESC

    @@class_name : String = self.name.split("::").last

    def run
      name, fields = args[0], args[1..-1]
      announce "Generating #{name.camelcase}#{@@class_name}"
      template(name, fields)
      announce "Done: Generating #{name.camelcase}#{@@class_name}"
      true
    rescue e
      error "Request generation failed! #{e.message}"
    end

    private def template(name, fields)
      File.open("#{PATH}/#{name}_#{@@class_name}.cr".downcase, "w") do |file|
        file.puts <<-CONTENT
        class #{name.camelcase}#{@@class_name}
          include Azu::#{@@class_name}

          #{render_field(fields)}
        end
        CONTENT
      end
    end
  end
end
