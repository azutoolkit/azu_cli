require "./resource"

module AzuCLI
  module Generate
    # Model generator that creates CQL::ActiveRecord::Model classes. Validation lives in the
    # request contracts (Azu::Request), so the model only declares columns and associations.
    class Model < Resource
      directory "#{__DIR__}/../templates/scaffold/src/models"
      OUTPUT_DIR = "./src/models"

      getter timestamps : Bool
      getter database : String
      getter id_type : String
      getter generate_migration : Bool

      def initialize(name : String, attributes : Hash(String, String), @timestamps : Bool = true,
                     @database : String = "AppDB", @id_type : String = "Int64", @generate_migration : Bool = true)
        super(name, "model", attributes)
        @database = Utils.detect_schema_info[0] if @database == "AppDB"
      end

      def table_name : String
        resource_plural
      end

      def associations : Array(String)
        @attributes.compact_map { |name, type| association_for(Field.new(name, type)) }
      end

      def constructor_params : String
        fields.map { |field| "@#{field.name} : #{field.crystal_type}" }.join(", ")
      end

      def include_statement : String
        "include CQL::ActiveRecord::Model(#{@id_type})"
      end

      def db_context_declaration : String
        "db_context #{@database}, :#{table_name}"
      end

      def rendered_file_entries
        file_entries
      end

      # Renders the model, then its create-table migration next to it (`src/db/migrations`).
      def render(output_path : String, force : Bool = false, interactive : Bool = true, list : Bool = false, color : Bool = false)
        super(output_path, force: force, interactive: interactive, list: list, color: color)
        return unless @generate_migration

        migrations_dir = File.join(File.dirname(output_path), "db", "migrations")
        migration = Migration.new(create_migration_name, @attributes, @timestamps, @id_type, table_name)
        migration.render(migrations_dir, force: force, interactive: interactive, list: list, color: color)
      end

      private def association_for(field : Field) : String?
        case field.kind
        when "references", "belongs_to"
          relation = field.name.gsub(/_id$/, "")
          "belongs_to :#{relation}, #{relation.camelcase}, foreign_key: :#{field.name}"
        when "has_many"
          "has_many :#{field.name}, #{field.name.singularize.camelcase}, foreign_key: :#{@snake_case_name}_id"
        when "has_one"
          "has_one :#{field.name}, #{field.name.camelcase}, foreign_key: :#{@snake_case_name}_id"
        end
      end
    end
  end
end
