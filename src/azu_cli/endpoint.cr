module AzuCLI
  class Endpoint
    include Topia::Plugin
    include Helpers

    PATH = "./src/endpoints"
    @@class_name : String = self.name.split("::").last

    def run(input, params)
      name, route, request, response = params
      method, path = route.split(":/")

      announce "Generating #{name.camelcase}#{@@class_name}"
      template(name, method, path, request, response)
      announce "Generating #{name.camelcase}#{@@class_name}"

      true
    end

    def on(event : String)
    end

    private def template(name, method, path, request, response)
      File.open("#{PATH}/#{name}_#{@@class_name}.cr".downcase, "w") do |file|
        file.puts <<-CONTENT
        class #{name.camelcase}#{@@class_name}
          include Azu::Endpoint(#{request.camelcase}, #{response.camelcase})
          
          #{method.downcase} "/#{path.downcase}"
    
          def call : #{response.camelcase}
          end
        end
        CONTENT
      end
    end
  end
end
