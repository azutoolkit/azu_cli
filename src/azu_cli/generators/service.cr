require "teeplate"

module AzuCLI
  module Generate
    # Service generator for business logic
    class Service < Teeplate::FileTree
      directory "#{__DIR__}/../templates/service"
      OUTPUT_DIR = "./src/services"

      property name : String
      property methods : Hash(String, String)
      property snake_case_name : String
      property camel_case_name : String

      def initialize(@name : String, @methods : Hash(String, String) = {} of String => String)
        @snake_case_name = @name.underscore
        @camel_case_name = @name.camelcase
      end

      # Generate method definitions
      def method_definitions : String
        if @methods.empty?
          <<-METHODS
              # TODO: Add service methods here
              # Example:
              # def create(params : Hash) : YourModel
              #   # Service logic
              #   YourModel.create(params)
              # end
          METHODS
        else
          @methods.map do |method_name, return_type|
            <<-METHOD
                def #{method_name}(params : Hash) : #{return_type}
                  # TODO: Implement #{method_name} logic
                  raise NotImplementedError.new("#{method_name} not implemented")
                end
            METHOD
          end.join("\n\n")
        end
      end

      # Check if service has dependencies
      def has_dependencies? : Bool
        true # Services typically have dependencies
      end

      # Generate dependency injection parameters
      def dependency_params : String
        # Common dependencies
        "@repository : #{@camel_case_name}Repository"
      end

      # Generate example usage
      def usage_example : String
        <<-EXAMPLE
          # Usage example:
          #
          #   repository = #{@camel_case_name}Repository.new
          #   service = #{@camel_case_name}Service.new(repository)
          #   result = service.create(params)
        EXAMPLE
      end
    end
  end
end
