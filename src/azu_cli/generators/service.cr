require "teeplate"

module AzuCLI
  module Generate
    # Service generator for business logic with CRUD actions
    class Service < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/services"
      OUTPUT_DIR = "./src/services"

      property name : String
      property action : String
      property attributes : Hash(String, String)
      property snake_case_name : String
      property module_name : String
      property resource_plural : String

      def initialize(@name : String, @action : String = "create", @attributes : Hash(String, String) = {} of String => String)
        @snake_case_name = @name.underscore
        @module_name = @name.camelcase
        @resource_plural = @snake_case_name.pluralize
      end

      def model_class : String
        "#{@module_name}::#{@module_name}Model"
      end

      def service_class_name : String
        "#{@action.camelcase}Service"
      end

      # Generate parameter list from attributes
      def param_list : String
        params = [] of String
        @attributes.each do |field, type|
          crystal_type = crystal_type(type)
          params << "#{field} : #{crystal_type}"
        end
        params.join(", ")
      end

      # Generate constructor parameters for model
      def constructor_params : String
        params = [] of String
        @attributes.each do |field, type|
          params << "#{field}: #{field}"
        end
        params.join(", ")
      end

      # Generate update parameters hash
      def update_params : String
        params = [] of String
        @attributes.each do |field, type|
          params << "#{field}: #{field}"
        end
        "{#{params.join(", ")}}"
      end

      # Get Crystal type for attribute
      def crystal_type(attr_type : String) : String
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
        when "email"
          "String"
        when "url"
          "String"
        when "json"
          "JSON::Any"
        when "uuid"
          "UUID"
        else
          "String" # Default to String for unknown types
        end
      end

      # Override render to generate one file per action + Result concern
      def render(output_dir : String, force : Bool = false, interactive : Bool = true, list : Bool = false, color : Bool = false)
        # Create resource subdirectory
        resource_dir = File.join(output_dir, @snake_case_name)
        Dir.mkdir_p(resource_dir) unless Dir.exists?(resource_dir)

        # Generate Result concern (only once, check if exists)
        generate_result_concern(output_dir, force)

        # Generate action-specific service
        generate_service_file(resource_dir, force)
      end

      # Helper method to generate Result concern directly
      def generate_result_concern(output_dir : String, force : Bool = false)
        result_file = File.join(output_dir, "result.cr")
        return if File.exists?(result_file) && !force

        result_content = <<-CRYSTAL
module Services
  # Result object for service operations
  class Result(T)
    property success : Bool
    property data : T?
    property errors : CQL::ActiveRecord::Validations::Errors

    def initialize(@success : Bool, @data : T? = nil, @errors : CQL::ActiveRecord::Validations::Errors = CQL::ActiveRecord::Validations::Errors.new)
    end

    def self.success(data : T) : Result(T)
      new(success: true, data: data)
    end

    def self.failure(errors : CQL::ActiveRecord::Validations::Errors) : Result(T)
      new(success: false, errors: errors)
    end

    def success? : Bool
      @success
    end

    def failure? : Bool
      !@success
    end
  end
end
CRYSTAL

        File.write(result_file, result_content)
      end

      # Helper method to generate service files directly
      def generate_service_file(output_dir : String, force : Bool = false)
        service_file = File.join(output_dir, "#{@action}_service.cr")
        return if File.exists?(service_file) && !force

        service_content = case @action
        when "create"
          generate_create_service_content
        when "index"
          generate_index_service_content
        when "show"
          generate_show_service_content
        when "update"
          generate_update_service_content
        when "destroy"
          generate_destroy_service_content
        else
          ""
        end

        File.write(service_file, service_content)
      end

      def generate_create_service_content : String
        <<-CRYSTAL
require "../result"

module #{@module_name}
  class CreateService
    def call(#{param_list}) : Services::Result(#{model_class})
      #{@snake_case_name} = #{model_class}.new(#{constructor_params})

      if #{@snake_case_name}.save
        Services::Result.success(#{@snake_case_name})
      else
        Services::Result.failure(#{@snake_case_name}.errors)
      end
    end
  end
end
CRYSTAL
      end

      def generate_index_service_content : String
        <<-CRYSTAL
require "../result"

module #{@module_name}
  class IndexService
    def call : Services::Result(Array(#{model_class}))
      records = #{model_class}.all
      Services::Result.success(records.to_a)
    end
  end
end
CRYSTAL
      end

      def generate_show_service_content : String
        <<-CRYSTAL
require "../result"

module #{@module_name}
  class ShowService
    def call(id : UUID | Int64) : Services::Result(#{model_class})
      #{@snake_case_name} = #{model_class}.find(id)
      Services::Result.success(#{@snake_case_name})
    rescue CQL::RecordNotFound
      errors = CQL::ActiveRecord::Validations::Errors.new
      errors << CQL::ActiveRecord::Validations::Error.new(:base, "Record not found")
      Services::Result(#{model_class}).failure(errors)
    end
  end
end
CRYSTAL
      end

      def generate_update_service_content : String
        <<-CRYSTAL
require "../result"

module #{@module_name}
  class UpdateService
    def call(id : UUID | Int64, #{param_list}) : Services::Result(#{model_class})
      #{@snake_case_name} = #{model_class}.find(id)

      if #{@snake_case_name}.update(#{update_params})
        Services::Result.success(#{@snake_case_name})
      else
        Services::Result.failure(#{@snake_case_name}.errors)
      end
    rescue CQL::RecordNotFound
      errors = CQL::ActiveRecord::Validations::Errors.new
      errors << CQL::ActiveRecord::Validations::Error.new(:base, "Record not found")
      Services::Result(#{model_class}).failure(errors)
    end
  end
end
CRYSTAL
      end

      def generate_destroy_service_content : String
        <<-CRYSTAL
require "../result"

module #{@module_name}
  class DestroyService
    def call(id : UUID | Int64) : Services::Result(#{model_class})
      #{@snake_case_name} = #{model_class}.find(id)

      if #{@snake_case_name}.delete
        Services::Result.success(#{@snake_case_name})
      else
        Services::Result.failure(#{@snake_case_name}.errors)
      end
    rescue CQL::RecordNotFound
      errors = CQL::ActiveRecord::Validations::Errors.new
      errors << CQL::ActiveRecord::Validations::Error.new(:base, "Record not found")
      Services::Result(#{model_class}).failure(errors)
    end
  end
end
CRYSTAL
      end
    end
  end
end
