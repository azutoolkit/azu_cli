module AzuCLI
  class Model
    include Builder

    PATH        = "./src/models"
    ARGS        = "model_name property:psqltype property:psqltype ..."
    DESCRIPTION = <<-DESC
    Azu - Clear Model Generator

    Generates a Clear model and migration. If only the `model_name` is provided 
    will generate an empty model and migration.

    Docs: https://clear.gitbook.io/project/model/column-types

    Command Arguments Definition

      - *model_name: name for the migration eg. `UpdatePrimaryKeyType`
      - property: name of the model fields to create and the postgres type eg.
        first_name:varchar

      * - Required fields
    
    Associations

      Models associations can be define using the following syntax. 

      Eg.
        - belongs_to:user
        - has_one:user
        - has_many:users
        - has_many_through:posts:user_posts

    DESC

    def run
      model_name = args.first
      path = "#{PATH}/#{model_name}.cr".underscore.downcase
      File.open(path, "w") do |file|
        file.puts content(args)
      end
      success "Created #{PROGRAM}: #{path}"
    end

    private def content(params : Array(String))
      return empty_template(params) if params.size == 1
      filled_template(params)
    end

    private def empty_template(params : Array(String))
      name = params.first
      class_name = "#{name.camelcase}"

      <<-CONTENT
      # Model Docs - https://clear.gitbook.io/project/model/column-types
      module #{Shard.name.camelcase}
        class #{class_name}
          include Clear::Model
        end
      end
      
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
      # Model Docs - https://clear.gitbook.io/project/model/column-types
      module #{project_name.camelcase}
        class #{class_name}
          include Clear::Model
          self.table = "#{model_name.underscore}s"

          primary_key
                  
          #{render_columns(columns)}
          timestamps
        end
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
