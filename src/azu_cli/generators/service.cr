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

      # Get the full nested module name for the service
      def full_module_name : String
        "#{@module_name}::#{@module_name}"
      end

      def service_class_name : String
        "#{@action.camelcase}Service"
      end

      def camel_case_name : String
        @module_name
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

      # Determine ID type based on database configuration or default to Int64
      def id_type : String
        # Check if database.yml exists and has uuid primary keys configured
        if File.exists?("config/database.yml")
          begin
            db_config = YAML.parse(File.read("config/database.yml"))
            if db_config.dig?("default", "primary_key_type").try(&.to_s) == "uuid"
              return "UUID"
            end
          rescue
            # Fall through to default
          end
        end

        # Check shard.yml for UUID-related dependencies or settings
        if File.exists?("./shard.yml")
          begin
            shard_content = File.read("./shard.yml")
            # If project uses UUID in dependencies or name, assume UUID IDs
            if shard_content.includes?("uuid") || shard_content.includes?("UUID")
              return "UUID"
            end
          rescue
            # Fall through to default
          end
        end

        # Default to Int64 for maximum compatibility
        "Int64"
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

    # Transform the data if successful, otherwise return the same result
    def map(&block : T -> U) : Result(U) forall U
      if success?
        begin
          Result(U).success(block.call(data.not_nil!))
        rescue ex
          errors = CQL::ActiveRecord::Validations::Errors.new
          errors << CQL::ActiveRecord::Validations::Error.new(:base, "Transformation error: \#{ex.message}")
          Result(U).failure(errors)
        end
      else
        Result(U).failure(errors)
      end
    end

    # Chain operations that return Results
    def flat_map(&block : T -> Result(U)) : Result(U) forall U
      if success?
        block.call(data.not_nil!)
      else
        Result(U).failure(errors)
      end
    end

    # Get error messages as a single string
    def error_messages : String
      errors.map { |error| "\#{error.field}: \#{error.message}" }.join(", ")
    end

    # Get error messages as an array
    def error_messages_array : Array(String)
      errors.map { |error| error.message }
    end

    # Check if result has any errors
    def has_errors? : Bool
      !errors.empty?
    end

    # Get the data or raise an exception if failed
    def data! : T
      if success?
        data.not_nil!
      else
        raise "Cannot access data from failed result: \#{error_messages}"
      end
    end

    # Get the data or return a default value
    def data_or(default : T) : T
      success? ? data.not_nil! : default
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
      Log.info { "Creating new #{@snake_case_name}" }

      #{@snake_case_name} = #{model_class}.new(#{constructor_params})

      if #{@snake_case_name}.save
        Log.info { "Successfully created \#{@snake_case_name} with ID: \#{#{@snake_case_name}.id}" }
        Services::Result.success(#{@snake_case_name})
      else
        Log.warn { "Failed to create \#{@snake_case_name}: \#{#{@snake_case_name}.errors.to_a.map(&.message).join(", ")}" }
        Services::Result.failure(#{@snake_case_name}.errors)
      end
    rescue ex
      Log.error(exception: ex) { "Error creating \#{@snake_case_name}" }
      errors = CQL::ActiveRecord::Validations::Errors.new
      errors << CQL::ActiveRecord::Validations::Error.new(:base, "An unexpected error occurred: \#{ex.message}")
      Services::Result.failure(errors)
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
      Log.info { "Fetching all #{@snake_case_name.pluralize}" }

      records = #{model_class}.all
      Log.info { "Successfully fetched \#{records.size} \#{@snake_case_name.pluralize}" }
      Services::Result.success(records.to_a)
    rescue ex
      Log.error(exception: ex) { "Error fetching \#{@snake_case_name.pluralize}" }
      errors = CQL::ActiveRecord::Validations::Errors.new
      errors << CQL::ActiveRecord::Validations::Error.new(:base, "An unexpected error occurred: \#{ex.message}")
      Services::Result.failure(errors)
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
    def call(id : #{id_type}) : Services::Result(#{model_class})
      Log.info { "Fetching #{@snake_case_name} with ID: \#{id}" }

      #{@snake_case_name} = #{model_class}.find(id)
      Log.info { "Successfully found \#{@snake_case_name}" }
      Services::Result.success(#{@snake_case_name})
    rescue CQL::RecordNotFound
      Log.warn { "\#{@snake_case_name.camelcase} with ID \#{id} not found" }
      errors = CQL::ActiveRecord::Validations::Errors.new
      errors << CQL::ActiveRecord::Validations::Error.new(:base, "Record not found")
      Services::Result.failure(errors)
    rescue ex
      Log.error(exception: ex) { "Error fetching \#{@snake_case_name} with ID \#{id}" }
      errors = CQL::ActiveRecord::Validations::Errors.new
      errors << CQL::ActiveRecord::Validations::Error.new(:base, "An unexpected error occurred: \#{ex.message}")
      Services::Result.failure(errors)
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
    def call(id : #{id_type}, #{param_list}) : Services::Result(#{model_class})
      Log.info { "Updating #{@snake_case_name} with ID: \#{id}" }

      #{@snake_case_name} = #{model_class}.find(id)

      if #{@snake_case_name}.update(#{update_params})
        Log.info { "Successfully updated \#{@snake_case_name} with ID: \#{id}" }
        Services::Result.success(#{@snake_case_name})
      else
        Log.warn { "Failed to update \#{@snake_case_name}: \#{#{@snake_case_name}.errors.to_a.map(&.message).join(", ")}" }
        Services::Result.failure(#{@snake_case_name}.errors)
      end
    rescue CQL::RecordNotFound
      Log.warn { "\#{@snake_case_name.camelcase} with ID \#{id} not found" }
      errors = CQL::ActiveRecord::Validations::Errors.new
      errors << CQL::ActiveRecord::Validations::Error.new(:base, "Record not found")
      Services::Result.failure(errors)
    rescue ex
      Log.error(exception: ex) { "Error updating \#{@snake_case_name} with ID \#{id}" }
      errors = CQL::ActiveRecord::Validations::Errors.new
      errors << CQL::ActiveRecord::Validations::Error.new(:base, "An unexpected error occurred: \#{ex.message}")
      Services::Result.failure(errors)
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
    def call(id : #{id_type}) : Services::Result(#{model_class})
      Log.info { "Destroying #{@snake_case_name} with ID: \#{id}" }

      #{@snake_case_name} = #{model_class}.find(id)

      if #{@snake_case_name}.delete
        Log.info { "Successfully destroyed \#{@snake_case_name} with ID: \#{id}" }
        Services::Result.success(#{@snake_case_name})
      else
        Log.warn { "Failed to destroy \#{@snake_case_name}: \#{#{@snake_case_name}.errors.to_a.map(&.message).join(", ")}" }
        Services::Result.failure(#{@snake_case_name}.errors)
      end
    rescue CQL::RecordNotFound
      Log.warn { "\#{@snake_case_name.camelcase} with ID \#{id} not found" }
      errors = CQL::ActiveRecord::Validations::Errors.new
      errors << CQL::ActiveRecord::Validations::Error.new(:base, "Record not found")
      Services::Result.failure(errors)
    rescue ex
      Log.error(exception: ex) { "Error destroying \#{@snake_case_name} with ID \#{id}" }
      errors = CQL::ActiveRecord::Validations::Errors.new
      errors << CQL::ActiveRecord::Validations::Error.new(:base, "An unexpected error occurred: \#{ex.message}")
      Services::Result.failure(errors)
    end
  end
end
CRYSTAL
      end
    end
  end
end
