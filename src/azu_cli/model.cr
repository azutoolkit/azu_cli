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
    option properties : Array(String), "-p Name:Type", "Model properties [Name:Type ...]" { properties << v }
    option relations : Array(String), "-r Relation:Model", "Table Columns [Name:Type ...]" { relations << v }

    def run
      name = model.underscore
      table = name.pluralize
      path = "#{PATH}/#{model}.cr".underscore
      file_name = "#{migration_id}__#{name}.cr"
      check_path = "#{Migration::PATH}/*__#{name}.cr"
      migration_path = "#{Migration::PATH}/#{file_name}"

      File.open(path, "w") do |file|
        file.puts content
      end

      not_exists?(check_path) do
        File.open(migration_path, "w") do |file|
          file.puts MigrationGenerator.content(name, table, properties)
        end
      end

      `crystal tool format`

      success "Created #{PROGRAM} for #{model} in #{path}"
      success "Created Migration for #{name} in #{migration_path}"
      exit
    end

    private def migration_id
      Time.local.to_unix.to_s.rjust(10, '0')
    end

    private def content
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
      return if properties.empty?
      property_builder properties do |name, type|
        %Q(column #{name} : #{type.camelcase})
      end
    end

    private def render_relationships
      return if relations.empty?
      property_builder relations do |rel, type|
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
          str << "\n"
        end
      end
    end
  end
end
