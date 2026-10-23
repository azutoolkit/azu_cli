require "teeplate"

module AzuCLI
  module Generate
    # One attribute of a resource, written `name:type[?][:modifier...]`: `title:string`,
    # `age:int32?`, `email:string:unique`, `owner_id:int64:ref:users`.
    # Modifiers: `unique` and `index` (column options), `required` (the default: columns are NOT NULL
    # unless the type ends in `?`) and `ref:<table>` (a foreign key).
    record Field, name : String, type : String do
      # Crystal words a name cannot be, and methods of Object, the CQL model and Azu::Request that a
      # getter would hide.
      RESERVED = %w(abstract alias annotation as asm begin break case class def do else elsif end ensure enum
        extend false for fun if in include instance_sizeof is_a lib macro module next nil of offsetof out
        pointerof private protected require rescue responds_to return select self sizeof struct super then
        true typeof uninitialized union unless until verbatim when while with yield
        errors error_messages attributes destroyed save touch hash object_id inspect to_s)
      MODIFIERS = %w(unique index required)
      # The model provides these columns itself.
      PROVIDED = %w(id created_at updated_at)

      # The columns declared by `name:type` attributes.
      def self.columns(attributes : Hash(String, String)) : Array(Field)
        attributes.map { |name, type| new(name, type) }.reject { |field| field.association? || PROVIDED.includes?(field.name) }
      end

      # The attributes the model provides itself and the generators therefore leave out.
      def self.provided(attributes : Hash(String, String)) : Array(String)
        attributes.keys.select { |name| PROVIDED.includes?(name) }
      end

      # Why `name` cannot be an attribute, if it cannot.
      def self.name_error(name : String) : String?
        if !name.matches?(/\A[a-z_][a-z0-9_]*\z/)
          "Invalid field name '#{name}': use lowercase letters, digits and underscores, not starting with a digit."
        elsif RESERVED.includes?(name)
          "Field name '#{name}' is a Crystal keyword or a method of the model; choose another."
        end
      end

      # Why the type of this attribute is not supported, if it is not.
      def type_error(supported_kinds : Array(String)) : String?
        return "Unsupported attribute type '#{kind}' for field '#{name}'. Supported types: #{supported_kinds.join(", ")}" unless supported_kinds.includes?(kind)

        unknown = modifiers.reject { |modifier| MODIFIERS.includes?(modifier) }
        return if unknown.empty? || (unknown.first == "ref" && unknown.size == 2 && unknown.last.matches?(/\A[a-z_][a-z0-9_]*\z/))
        "Unsupported modifier '#{unknown.join(":")}' for field '#{name}'. Supported: #{MODIFIERS.join(", ")}, ref:<table>"
      end

      def kind : String
        segments.first.chomp('?').downcase
      end

      def modifiers : Array(String)
        segments[1..]
      end

      def nilable? : Bool
        segments.first.ends_with?("?")
      end

      # `comments:has_many` declares an association, not a column.
      def association? : Bool
        {"has_many", "has_one"}.includes?(kind)
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
        when "String" then "text :#{name}#{options}"
        when "Bool"   then "boolean :#{name}, default: false#{options}"
        else               "column :#{name}, #{base_type}#{options}"
        end
      end

      # The CQL table DSL line that constrains a `user_id:references` or `:ref:users` column.
      def foreign_key : String?
        table = referenced_table
        "foreign_key [:#{name}], references: :#{table}, references_columns: [:id]" if table
      end

      # The HTML control that edits this field.
      def input : String
        if kind == "text"
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

      private def segments : Array(String)
        type.split(':')
      end

      private def referenced_table : String?
        if {"references", "belongs_to"}.includes?(kind)
          name.gsub(/_id$/, "").pluralize
        elsif (position = modifiers.index("ref"))
          modifiers[position + 1]?
        end
      end

      private def base_type : String
        case kind
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

      private def options : String
        options = [] of String
        options << "null: true" if nilable?
        options << "unique: true" if modifiers.includes?("unique")
        options << "index: true" if modifiers.includes?("index")
        options.empty? ? "" : ", #{options.join(", ")}"
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
      CRUD_ACTIONS = %w(index show new create edit update destroy)

      getter name : String
      getter action : String
      getter attributes : Hash(String, String)
      getter snake_case_name : String
      getter resource_singular : String
      getter resource_plural : String
      getter namespace : String
      getter app_module : String
      getter app_dir : String

      # Constants of Crystal, Azu (the app module includes it) and the generated code that a model of
      # this name would hide, or that inflect badly ("status" singularizes to "statu").
      RESERVED_NAMES = %w(Status Request Response Params Context Header Headers Handler Router Error Method
        Templates Configuration Channel Component Cache Endpoint Spark Helpers Environment Result Log
        Object Class Module Struct Enum Hash Array String Symbol Int Float Bool Nil Time File Dir IO Set
        Range Proc Tuple Value Exception Process Signal Path Random Math Mutex Fiber UUID JSON YAML URI
        HTTP CQL Azu App Validator Markup PubSub Routable Components Schema Template Param)

      # The singular of a resource name, whether `Post` or `Posts` was typed. The inflector's last rule turns
      # every trailing s into nothing (`Campus` into `campu`), so a name is taken for a plural only when it is
      # the plural of its own singular (`posts`, `people`, `categories`) and does not end like a singular
      # that ends in s (`us`, `is`, `ss`, `as`: campus, analysis, address, atlas). `Areas` is therefore typed `Area`.
      def self.singular(name : String) : String
        underscored = name.underscore
        candidate = underscored.singularize
        plural = candidate != underscored && candidate.pluralize == underscored && !underscored.matches?(/(us|is|ss|as)\z/)
        plural ? candidate : underscored
      end

      # The plural of a resource name: `Post`, `Posts` and `post` are all "posts".
      def self.plural(name : String) : String
        singular(name).pluralize
      end

      # Why `name` cannot be a resource, if it cannot.
      def self.name_error(name : String, app_module : String = Utils.project_module_name) : String?
        singular = singular(name)
        constants = [name.camelcase, singular.camelcase, singular.pluralize.camelcase]
        if !name.matches?(/\A[A-Za-z][A-Za-z0-9_]*\z/)
          "Invalid resource name '#{name}'. Must be a valid Crystal identifier."
        elsif singular == singular.pluralize
          "Resource name '#{name}' is the same in singular and plural, so its model and its routes would collide. Choose another name."
        elsif constants.any? { |constant| RESERVED_NAMES.includes?(constant) || constant == app_module }
          "Resource name '#{name}' would hide a constant the generated code uses. Choose another name."
        end
      end

      def initialize(@name : String, @action : String = "index", @attributes : Hash(String, String) = {} of String => String)
        @resource_singular = Resource.singular(@name)
        @snake_case_name = @resource_singular
        @resource_plural = @resource_singular.pluralize
        @namespace = @resource_plural.camelcase
        @app_module = Utils.project_module_name
        @app_dir = @app_module.underscore
      end

      def model_name : String
        @resource_singular.camelcase
      end

      def create_migration_name : String
        "create_#{@resource_plural}"
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
