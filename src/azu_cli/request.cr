module AzuCLI
  class Request
    include Topia::Plugin
    include Helpers

    PATH = "./src/requests"
    @@class_name : String = self.name.split("::").last

    def run(input, params)
      name, fields = params
      announce "Generating #{name.camelcase}#{@@class_name}"
      template(name, fields)
      announce "Done: Generating #{name.camelcase}#{@@class_name}"
      true
    end

    def on(event : String)
    end

    private def template(name, fields)
      File.open("#{PATH}/#{name}_#{@@class_name}.cr".downcase, "w") do |file|
        file.puts <<-CONTENT
        class #{name.camelcase}#{@@class_name}
          include Azu::#{@@class_name}

          #{render_field(fields.split(/\s/))}
        end
        CONTENT
      end
    end
  end
end
