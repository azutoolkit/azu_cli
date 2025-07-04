require "teeplate"

module AzuCLI
  module Generate
    # Contract generator that creates contract structs for request validation
    class Contract < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/contracts"
      OUTPUT_DIR = "./src/contracts"

      getter project : String
      getter resource : String
      getter action : String
      getter fields : FieldCollection
      getter snake_case_name : String
      getter camelcase_name : String

      def initialize(@project : String, @resource : String, @action : String, attributes : Hash(String, String))
        @snake_case_name = @resource.underscore
        @camelcase_name = @resource.camelcase
        @fields = FieldCollection.new(attributes)
      end

      def self.generate_for_scaffold(project : String, resource : String, actions : Array(String), attributes : Hash(String, String))
        actions.each do |action|
          generator = new(project, resource, action, attributes)
          Dir.mkdir_p(OUTPUT_DIR) unless Dir.exists?(OUTPUT_DIR)
          generator.render(OUTPUT_DIR)
        end
      end

      # Field collection helper class
      class FieldCollection
        getter common_fields : Array(Field)
        getter references : Array(Field)
        getter id : Field

        def initialize(attributes : Hash(String, String))
          @common_fields = [] of Field
          @references = [] of Field
          @id = Field.new("id", "Int64", "Primary64")

          attributes.each do |name, type|
            case type.downcase
            when "reference", "belongs_to"
              @references << Field.new(name, crystal_type(type), type)
            else
              @common_fields << Field.new(name, crystal_type(type), type)
            end
          end
        end

        private def crystal_type(attr_type : String) : String
          case attr_type.downcase
          when "string", "text"
            "String"
          when "int32", "integer"
            "Int32"
          when "int64"
            "Int64"
          when "float32"
            "Float32"
          when "float64", "float"
            "Float64"
          when "bool", "boolean"
            "Bool"
          when "time", "datetime"
            "Time"
          when "date"
            "Date"
          when "json"
            "JSON::Any"
          when "reference", "belongs_to"
            "Int64"
          else
            "String"
          end
        end
      end

      # Field helper class
      class Field
        getter field_name : String
        getter cr_type : String
        getter original_type : String

        def initialize(@field_name : String, @cr_type : String, @original_type : String)
        end
      end
    end
  end
end
