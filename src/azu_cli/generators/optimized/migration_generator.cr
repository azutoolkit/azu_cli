require "../core/abstract_generator"

module AzuCLI::Generator
  # Optimized Migration Generator following SOLID principles
  class MigrationGenerator < Core::AbstractGenerator
    property attributes : Array(String)
    property migration_type : String

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @attributes = extract_attributes(options)
      @migration_type = detect_migration_type(name)
      super(name, project_name, options.force, options.skip_tests)
    end

    def generator_type : String
      "migration"
    end

    def generate_files : Nil
      generate_migration_file
    end

    def create_directories : Nil
      super
      migrations_dir = config.get("directories.source") || "src/db/migrations"
      file_strategy.create_directory(migrations_dir)
    end

    private def generate_migration_file : Nil
      timestamp = Time.utc.to_s("%Y%m%d%H%M%S")
      filename = "#{timestamp}_#{snake_case_name}.cr"
      output_path = File.join("src/db/migrations", filename)

      migration_variables = generate_migration_variables(timestamp.to_i64)

      create_file_from_template(
        "migration/migration.cr.ecr",
        output_path,
        migration_variables,
        "migration"
      )
    end

    private def generate_migration_variables(version : Int64) : Hash(String, String)
      default_template_variables.merge({
        "version" => version.to_s,
        "up_content" => generate_up_content,
        "down_content" => generate_down_content,
        "migration_type" => @migration_type,
      })
    end

    private def extract_attributes(options : Core::GeneratorOptions) : Array(String)
      options.additional_args.select { |arg| arg.includes?(":") }
    end

    private def detect_migration_type(name : String) : String
      lower_name = name.downcase
      migration_types = config.get_hash("migration_types")

      migration_types.each do |type, type_config|
        pattern = config.get("migration_types.#{type}.pattern")
        if pattern && lower_name.match(Regex.new(pattern.gsub("*", ".*")))
          return type
        end
      end

      "general"
    end

    private def generate_up_content : String
      schema_operations = config.get_hash("schema_operations")
      
      case @migration_type
      when "create_table"
        table_name = extract_table_name || "your_table"
        columns = generate_columns_from_attributes
        template = schema_operations["create_table"]? || ""
        template % {table_name: table_name, columns: columns}
      when "add_column"
        table_name = extract_table_name || "your_table"
        column_info = extract_column_info
        template = schema_operations["add_column"]? || ""
        template % column_info.merge({"table_name" => table_name})
      else
        generate_general_up_content
      end
    end

    private def generate_down_content : String
      case @migration_type
      when "create_table"
        table_name = extract_table_name || "your_table"
        "schema.#{table_name}.drop!"
      when "add_column"
        table_name = extract_table_name || "your_table"
        column_name = extract_column_name || "your_column"
        "schema.alter :#{table_name} do\n      drop_column :#{column_name}\n    end"
      else
        generate_general_down_content
      end
    end

    private def extract_table_name : String?
      lower_name = name.downcase
      
      if match = lower_name.match(/create_(.+)_table/)
        return match[1]
      elsif match = lower_name.match(/(?:add|remove)_.+_(?:to|from)_(.+)/)
        return match[1]
      end
      
      nil
    end

    private def extract_column_name : String?
      attributes.each do |attr|
        if attr.includes?(":")
          return attr.split(":", 2)[0]
        end
      end
      nil
    end

    private def extract_column_info : Hash(String, String)
      column_name = extract_column_name || "new_column"
      column_type = "String"
      column_options = "null: true"

      attributes.each do |attr|
        if attr.includes?(":")
          parts = attr.split(":", 2)
          if parts.size >= 2
            column_name = parts[0]
            raw_type = parts[1]
            column_type = crystal_type(raw_type)
            column_options = case raw_type.downcase
                            when "string", "text"
                              "null: true"
                            when "boolean", "bool"
                              "default: false"
                            else
                              "null: true"
                            end
          end
        end
      end

      {
        "column_name" => column_name,
        "column_type" => column_type,
        "options" => column_options
      }
    end

    private def generate_columns_from_attributes : String
      return "" if attributes.empty?

      lines = [] of String
      attributes.each do |attr|
        if attr.includes?(":")
          parts = attr.split(":", 2)
          if parts.size >= 2
            column_name = parts[0]
            raw_type = parts[1]
            crystal_type_name = crystal_type(raw_type)
            lines << "    column :#{column_name}, #{crystal_type_name}"
          end
        end
      end

      lines.join("\n")
    end

    private def generate_general_up_content : String
      "# Define your schema changes here"
    end

    private def generate_general_down_content : String
      "# Define how to rollback the changes"
    end

    def success_message : String
      base_message = super
      "#{base_message} of type '#{@migration_type}'"
    end

    def post_generation_tasks : Nil
      super
      puts
      puts "📋 Migration Usage:".colorize(:yellow).bold
      puts "  1. Edit the migration file to define your schema changes"
      puts "  2. Run 'azu db:migrate' to apply the migration"
      puts "  3. Run 'azu db:rollback' to undo changes if needed"
    end
  end
end