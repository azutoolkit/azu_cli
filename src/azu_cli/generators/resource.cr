require "teeplate"

module AzuCLI
  module Generate
    # One attribute of a resource (`title:string`) and how each layer spells it.
    record Field, name : String, type : String do
      # The model provides these columns itself.
      PROVIDED = %w(id created_at updated_at)

      # The columns declared by `name:type` attributes.
      def self.columns(attributes : Hash(String, String)) : Array(Field)
        attributes.map { |name, type| new(name, type) }.reject { |field| field.association? || PROVIDED.includes?(field.name) }
      end

      def nilable? : Bool
        type.ends_with?("?")
      end

      # `comments:has_many` declares an association, not a column.
      def association? : Bool
        {"has_many", "has_one"}.includes?(type.downcase)
      end

      def crystal_type : String
        nilable? ? "#{base_type}?" : base_type
      end

      def string? : Bool
        base_type == "String"
      end

      def bool? : Bool
        base_type == "Bool"
      end

      # The CQL table DSL line that declares this column.
      def column : String
        case base_type
        when "String" then "text :#{name}#{null_option}"
        when "Bool"   then "boolean :#{name}, default: false#{null_option}"
        else               "column :#{name}, #{base_type}#{null_option}"
        end
      end

      # The CQL table DSL line that constrains a `user_id:references` column to the target's id.
      def foreign_key : String?
        return unless {"references", "belongs_to"}.includes?(type.downcase)
        "foreign_key [:#{name}], references: :#{name.gsub(/_id$/, "").pluralize}, references_columns: [:id]"
      end

      # The HTML control that edits this field.
      def input : String
        if type.chomp('?').downcase == "text"
          "textarea"
        elsif bool?
          "checkbox"
        elsif {"Int32", "Int64", "Float32", "Float64"}.includes?(base_type)
          "number"
        else
          "text"
        end
      end

      def label : String
        name.tr("_", " ").capitalize
      end

      private def base_type : String
        case type.chomp('?').downcase
        when "int32", "integer"                  then "Int32"
        when "int64", "references", "belongs_to" then "Int64"
        when "float32"                           then "Float32"
        when "float64", "float"                  then "Float64"
        when "bool", "boolean"                   then "Bool"
        when "time", "datetime"                  then "Time"
        when "date"                              then "Date"
        when "json"                              then "JSON::Any"
        when "uuid"                              then "UUID"
        else                                          "String"
        end
      end

      private def null_option : String
        nilable? ? ", null: true" : ""
      end
    end

    # What every generator of one resource action shares, so the layers agree on one scheme.
    # For `Post` in project `blog`:
    #
    #   model        class Post                                  src/models/post.cr
    #   web layers   Blog::Posts::<Action><Layer>                src/<layer>s/posts/<action>_<layer>.cr
    #   templates    public/templates/blog/posts/<action>_page.jinja (where `Renderable#page_path` looks)
    #
    # Teeplate substitutes `{{name}}` in template paths with the instance variable `@name`.
    abstract class Resource < Teeplate::FileTree
      getter name : String
      getter action : String
      getter attributes : Hash(String, String)
      getter snake_case_name : String
      getter resource_singular : String
      getter resource_plural : String
      getter namespace : String
      getter app_module : String
      getter app_dir : String

      def initialize(@name : String, @action : String = "index", @attributes : Hash(String, String) = {} of String => String)
        @snake_case_name = @name.underscore
        @resource_singular = @snake_case_name.singularize
        @resource_plural = @resource_singular.pluralize
        @namespace = @resource_plural.camelcase
        @app_module = Utils.project_module_name
        @app_dir = @app_module.underscore
      end

      def model_name : String
        @name.camelcase
      end

      def action_class : String
        @action.camelcase
      end

      def fields : Array(Field)
        Field.columns(@attributes)
      end

      # Only the template of this generator's action: `<action>_<layer>.cr` (or `.jinja`).
      def rendered_file_entries
        file_entries.select { |entry| File.basename(entry.path).starts_with?("#{@action}_") }
      end
    end
  end
end
