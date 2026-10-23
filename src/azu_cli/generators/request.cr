require "./resource"

module AzuCLI
  module Generate
    # Request generator: the Azu::Request contract of one action. Create and update carry the
    # resource's fields and validate them (an update carries them optionally); show, edit and destroy carry the id of the record.
    class Request < Resource
      directory "#{__DIR__}/../templates/scaffold/src/requests"
      OUTPUT_DIR = "./src/requests"
      ACTIONS    = CRUD_ACTIONS

      def request_struct_name : String
        "#{action_class}Request"
      end

      def id? : Bool
        {"show", "edit", "destroy"}.includes?(@action)
      end

      def fields? : Bool
        {"create", "update"}.includes?(@action)
      end

      # Strings must be present unless they are optional.
      def validated_fields : Array(Field)
        fields.select { |field| field.string? && !field.nilable? }
      end

      def update? : Bool
        @action == "update"
      end

      # An update changes what it carries (PATCH): every field is optional, a given string must not be blank.
      def type_of(field : Field) : String
        update? ? "#{field.crystal_type.chomp('?')}?" : field.crystal_type
      end

      def default_of(field : Field) : String
        field.bool? && !field.nilable? && !update? ? " = false" : ""
      end

      def validation : String
        update? ? "given: true" : "presence: true"
      end

      # The `given` predicate is rendered once, with the first update.
      def rendered_file_entries
        file_entries.reject { |entry| File.basename(entry.path) == "predicates.cr" && !update? }
      end
    end
  end
end
