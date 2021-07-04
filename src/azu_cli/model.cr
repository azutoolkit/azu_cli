module AzuCLI
  class Model
    include Builder

    PATH        = "./src/models"
    ARGS        = "-m User -p first_name:varchar -r has_many:Post"
    DESCRIPTION = <<-DESC
    #{bold "Azu - Clear Model"} - Generates a Clear model and migration
      
      For a list of available field types for the type parameter, refer to the
      api documentation below

      Docs: https://clear.gitbook.io/project/model/column-types

      #{underline "Defining Relations"}

      Relationships can be define using the following syntax. 

      e.g.
        - belongs_to:user
        - has_one:user
        - has_many:users
        - has_many_through:posts:user_posts
    DESC

    option model : String, "--model=Model", "-m Model", "Name for the migrarion", ""
    option properties : String, "--props=Name:Type", "-p Name:Type", "Model properties [Name:Type ...]", ""
    option relations : String, "--rel=Relation:Model", "-r Relation:Model", "Table Columns [Name:Type ...]", ""

    def run
      path = "#{PATH}/#{model}.cr".underscore.downcase
      File.open(path, "w") do |file|
        file.puts content
      end
      success "Created #{PROGRAM} for #{model} in #{path}"
      exit 1
    end

    private def content
      props = properties.split(" ")
      return empty_template if properties.empty?
      filled_template
    end

    private def empty_template
      class_name = "#{model.camelcase}"

      <<-CONTENT
      # Model Docs - https://clear.gitbook.io/project/model/column-types
      module #{Shard.name.camelcase}
        class #{class_name}
          include Clear::Model
          primary_key
        end
      end
      CONTENT
    end

    private def filled_template
      class_name = "#{model.camelcase}"

      <<-CONTENT
      # Model Docs - https://clear.gitbook.io/project/model/column-types
      module #{Shard.name.camelcase}
        class #{class_name}
          include Clear::Model
          self.table = "#{model.underscore.pluralize}"

          #{render_relationships}
          
          primary_key
          #{render_properties}
          timestamps
        end
      end
      CONTENT
    end

    private def render_properties
      props = properties.split(" ")

      property_builder props do |name, type|
        %Q(column #{name} : #{type.camelcase})
      end
    end

    private def render_relationships
      rels = relations.split(" ")
      property_builder rels do |rel, type|
        case rel
        when "belongs_to" then %Q(belongs_to #{type.underscore} : #{type.camelcase})
        when "has_one"    then %Q(has_one #{type.underscore} : #{type.camelcase})
        when "has_many"   then %Q(has_many #{type.underscore.pluralize} : #{type.camelcase})
        when "has_many_through"
          model, through = type.split(":")
          %Q(has_many #{model.underscore.pluralize} : #{model.camelcase}, through: #{model.underscore.pluralize})
        else
          error "Unsupported relationship"
        end
      end
    end

    private def property_builder(props : Array(String))
      String.build do |str|
        props.each do |col|
          name, type = col.split(":").map(&.underscore)
          type ||= "string"
          type = CLEAR_TYPE_MAPPING[type]? || type
          str << yield name, type
        end
      end
    end
  end
end
