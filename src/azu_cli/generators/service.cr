require "./resource"

module AzuCLI
  module Generate
    # Service generator: the business logic of one write action. The request contract has already
    # validated the input, so a service saves (or deletes) the record and returns it.
    class Service < Resource
      directory "#{__DIR__}/../templates/scaffold/src/services"
      OUTPUT_DIR = "./src/services"
      ACTIONS    = %w(create update destroy)

      getter? broadcast : Bool

      def initialize(name : String, action : String = "create", attributes = {} of String => String, @broadcast : Bool = false)
        super(name, action, attributes)
      end

      def service_class_name : String
        "#{action_class}Service"
      end

      def request_type : String
        "#{@namespace}::#{action_class}Request"
      end

      # Each field an update request carries, set on the record.
      def changes : Array(String)
        fields.map { |field| "request.#{field.name}.try { |value| record.#{field.name} = value }" }
      end

      def assignments : String
        fields.map { |field| "#{field.name}: request.#{field.name}" }.join(", ")
      end
    end
  end
end
