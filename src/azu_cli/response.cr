require "topia"

module AzuCLI
  class Response
    include Helpers
    include Base

    ARGS = "[name] [property:type] [property:type]"
    PATH = "./src/responses"
    DESCRIPTION = <<-DESC
    Azu - Response
    
    Responses is mostly an Azu implementation detail to enable more type-safe 
    definition

    Docs - https://azutopia.gitbook.io/azu/endpoints/response
    DESC
    
    def run
      name, fields = args[0], args[1..-1]
      class_name = "#{name.camelcase}#{PROGRAM}"
      announce "Generating #{class_name}"
      template(name, fields)
      announce "Done: Generating #{class_name}"
      true
    rescue e
      error "Response generation failed! #{e.message}"
    end

    private def template(name, fields)
      File.open("#{PATH}/#{name}_#{PROGRAM}.cr".downcase, "w") do |file|
        file.puts <<-CONTENT
        class #{name.camelcase}#{PROGRAM}
          include Azu::#{PROGRAM}
          #{render_initialize(fields)}
        end
        CONTENT
      end
    end
  end
end
