require "./resource"

module AzuCLI
  module Generate
    # Service generator: the business logic of one write action. The request contract has already
    # validated the input, so a service saves (or deletes) the record and returns it.
    class Service < Resource
      directory "#{__DIR__}/../templates/scaffold/src/services"
      OUTPUT_DIR = "./src/services"
      ACTIONS    = %w(create update destroy)

      def service_class_name : String
        "#{action_class}Service"
      end

      def request_type : String
        "#{@namespace}::#{action_class}Request"
      end

      def assignments : String
        fields.map { |field| "#{field.name}: request.#{field.name}" }.join(", ")
      end
    end
  end
end
