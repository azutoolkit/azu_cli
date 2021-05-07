require "topia"

module AzuCLI
  class Response
    include Base

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
      announce "Created #{PROGRAM} #{class_name}"
      exit 1
    end

    private def template(path, name, fields)
      File.open(path, "w") do |file|
        file.puts <<-CONTENT
        class #{name.camelcase}
          include Azu::#{PROGRAM}
          #{render_initialize(fields)}
        end
        CONTENT
      end
    end
  end
end
