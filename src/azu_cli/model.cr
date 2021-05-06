module AzuCLI
  class Model
    include Topia::Plugin
    include Helpers
    PATH = "./src/models"
    getter spinner : Topia::Spinner = Topia::Spinner.new("Waiting...")

    def run(input, params)
      model_name = params.first
      file_name = "#{model_name}.cr".underscore.downcase

      return false if exists? model_name

      File.open("#{PATH}/#{file_name}", "w") do |file|
        file.puts content(params)
      end

      true
    end

    def on(event : String)
    end

    private def exists?(model_name)
      msg = "A model file `xxxx__#{model_name.underscore}` already exists"
      target = "#{PATH}/*__#{model_name}.cr".underscore.downcase

      raise Topia::Error.new msg if Dir[target.underscore.downcase].any?
    end

    private def content(params : Array(String))
      return empty_template(params) if params.size == 1
      filled_template(params)
    end

    private def empty_template(params : Array(String))
      name = params.first
      class_name = "#{name.camelcase}"

      <<-CONTENT
      class #{class_name}
        include Clear::Model
        primary_key
      end
      CONTENT
    end

    private def filled_template(params : Array(String))
      model_name, columns = params.first, params[1..-1]
      class_name = model_name.camelcase

      <<-CONTENT
      class #{model_name.camelcase}
        include Clear::Model
        self.table = "#{model_name.underscore}s"

        with_serial_pkey
                
        #{render_columns(columns)}
        timestamps
      end
      CONTENT
    end

    private def render_columns(columns : Array(String))
      String.build do |str|
        columns.each do |col|
          name, type = col.split(":").map(&.underscore)
          type ||= "string"
          type = CLEAR_TYPE_MAPPING[type]? || type
          str << case name
          when "belongs_to" then %Q(belongs_to #{type.underscore} : #{type.camelcase})
          when "has_one"    then %Q(has_one #{type.underscore} : #{type.camelcase})
          when "has_many"   then %Q(has_many #{type.underscore}s : #{type.camelcase})
          when "has_many_through"
            model, through = type.split(":")
            %Q(has_many #{model.underscore}s : #{model.camelcase}, through: #{model.underscore}s)
          else
            %Q(column #{name} : #{type.camelcase})
          end
          str << "\n\t"
        end
      end
    end
  end
end
