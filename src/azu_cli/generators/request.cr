require "./resource"

module AzuCLI
  module Generate
    # Request generator: the Azu::Request contract of one action. Create and update carry the
    # resource's fields and validate them; show, edit and destroy carry the id of the record.
    class Request < Resource
      directory "#{__DIR__}/../templates/scaffold/src/requests"
      OUTPUT_DIR = "./src/requests"

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

      def rendered_file_entries
        file_entries
      end
    end
  end
end
