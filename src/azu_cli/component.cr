module AzuCLI
  class Component
    include Helpers
    include Base
    PATH = "./src/components"
    ARGS = "[name] [firld:type] [field:type]"
    DESCRIPTION = <<-DESC
    Azu - Spark Components
    
    Generates a Spark Component

    Spark Components decompose response content into small independent contexts 
    that can be lazily loaded.

    Docs - https://azutopia.gitbook.io/azu/spark-1#spark-components-overview
    DESC
    
    def run
      name, fields = args[0], args[1..-1]
      announce "Generating #{name.camelcase}#{PROGRAM}"
      template(name, fields)
      announce "Done: Generating #{name.camelcase}#{PROGRAM}"
      true
    rescue e
      error "Component generation failed! #{e.message}"
    end

    private def template(name, fields)
      File.open("#{PATH}/#{name}_#{PROGRAM}.cr".downcase, "w") do |file|
        file.puts <<-CONTENT
        class #{name.camelcase}#{PROGRAM}
          include Azu::Component
        
          #{render_initialize(fields)}
        
          def mount
            every(5.seconds) { refresh }
          end
        
          def content
            # ... your html markup ...
          end
        end
        CONTENT
      end
    end
  end
end
