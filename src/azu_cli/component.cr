module AzuCLI
  class Component
    include Builder

    PATH        = "./src/components"
    ARGS        = "-n User -p first_name:String"
    DESCRIPTION = <<-DESC
    #{bold "Azu - Spark Components"} - Generates a Spark component

      Spark Components decompose response content into small independent 
      contexts that can be lazily loaded.

      Docs - https://azutopia.gitbook.io/azu/spark-1#spark-components-overview
    DESC

    option name : String, "--name=Name", "-n Name", "Component name", ""
    option props : String, "--props=Name:Type", "-p Name:Type", "Component properties", ""

    def run
      validate

      not_exists?(path) do
        generate path, name, props.split(" ")

        success "Created #{PROGRAM} for #{name.colorize.underline} in #{path.colorize.underline}"
        exit 1
      end
    end

    private def path
      "#{PATH}/#{name}_#{PROGRAM}.cr".downcase
    end

    private def validate
      return unless name.nil? || name.empty?
      error "Missing option: name"
      exit 1
    end

    private def generate(path : String, name : String, fields : Array(String))
      File.open(path, "w") do |file|
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
