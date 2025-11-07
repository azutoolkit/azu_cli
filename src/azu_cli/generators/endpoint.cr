require "teeplate"
require "ecr"
require "./action"

module AzuCLI
  module Generate
    # Endpoint generator that creates Azu::Endpoint structs
    class Endpoint
      OUTPUT_DIR = "./src/endpoints"

      property name : String
      property actions : Array(String)
      property action : String = ""
      property endpoint_type : String # "api" or "web"
      property snake_case_name : String
      property resource_plural : String
      property resource_singular : String
      property module_name : String
      property fields : Hash(String, String)
      property scaffold : Bool

      def initialize(@name : String, @actions : Array(String) = [] of String, @endpoint_type : String = "api", @scaffold : Bool = false, module_name : String? = nil)
        @snake_case_name = @name.underscore
        @resource_plural = @name.downcase.singularize.pluralize
        @resource_singular = @name.downcase.singularize
        # Get module name from parameter or project
        @module_name = module_name || get_project_module_name
        @fields = {} of String => String
        @actions = ["index"] if @actions.empty? # Ensure at least one action
      end

      # Get project module name from shard.yml
      private def get_project_module_name : String
        return "App" unless File.exists?("./shard.yml")
        shard_yml = YAML.parse(File.read("./shard.yml"))
        project_name = shard_yml["name"].as_s
        project_name.split(/[-_]/).map(&.capitalize).join
      rescue
        "App"
      end

      # Convert name to endpoint struct name (nested under resource module)
      def endpoint_struct_name : String
        "#{@name.camelcase}::#{@name.camelcase}Endpoint"
      end

      # Get the request/response types based on endpoint type (nested under resource module)
      def request_type : String
        "#{@name.camelcase}::#{@name.camelcase}Request"
      end

      def response_type : String
        @endpoint_type == "api" ? "#{@name.camelcase}::#{@name.camelcase}Response" : "#{@name.camelcase}::#{@name.camelcase}Page"
      end

      # Get HTTP verb for action
      def http_verb(action : String) : String
        case action.downcase
        when "index", "show", "new", "edit"
          "get"
        when "create"
          "post"
        when "update"
          "patch"
        when "destroy", "delete"
          "delete"
        else
          "get"
        end
      end

      # Get path for action
      def action_path(action : String) : String
        base_path = "/#{@resource_plural}"
        case action.downcase
        when "index"
          base_path
        when "new"
          "#{base_path}/new"
        when "create"
          base_path
        when "show"
          "#{base_path}/:id"
        when "edit"
          "#{base_path}/:id/edit"
        when "update"
          "#{base_path}/:id"
        when "destroy", "delete"
          "#{base_path}/:id"
        else
          base_path
        end
      end

      # Get full path for action
      def full_path(action : String) : String
        action_path(action)
      end

      # Get scaffold components to generate
      def scaffold_components : Array(String)
        return [] of String unless @scaffold

        components = [] of String

        if @endpoint_type == "api"
          components << "request"
          components << "response"
        else
          components << "request"
          components << "page"
        end

        components
      end

      # Check if endpoint has actions
      def has_actions? : Bool
        !@actions.empty?
      end

      # Get actions to use (actions are always required)
      def effective_actions : Array(String)
        @actions
      end

      # Override render to create one file per action
      def render(output_dir : String, force : Bool = false, interactive : Bool = true, list : Bool = false, color : Bool = false)
        # Create the resource subdirectory (use plural form per memory)
        resource_dir = File.join(output_dir, @resource_plural)
        Dir.mkdir_p(resource_dir) unless Dir.exists?(resource_dir)

        @actions.each do |action|
          # Generate endpoint file directly using the specific template
          generate_endpoint_file(resource_dir, action, force)
        end
      end

      # Generate individual endpoint file using specific template
      private def generate_endpoint_file(output_dir : String, action : String, force : Bool = false)
        output_file = File.join(output_dir, "#{@resource_singular}_#{action}_endpoint.cr")

        return if File.exists?(output_file) && !force

        # Generate simple endpoint content directly
        content = generate_endpoint_content(action)

        File.write(output_file, content)
      end

      # Generate endpoint content directly
      private def generate_endpoint_content(action : String) : String
        case action.downcase
        when "index"
          generate_index_endpoint_content
        when "show"
          generate_show_endpoint_content
        when "create"
          generate_create_endpoint_content
        when "update"
          generate_update_endpoint_content
        when "destroy"
          generate_destroy_endpoint_content
        when "new"
          generate_new_endpoint_content
        when "edit"
          generate_edit_endpoint_content
        else
          generate_index_endpoint_content
        end
      end

      private def generate_index_endpoint_content : String
        <<-CRYSTAL
module #{@module_name}::#{@name.camelcase}
  struct IndexEndpoint
    include Azu::Endpoint(#{@name.camelcase}::IndexRequest, #{@name.camelcase}::Index#{@endpoint_type == "api" ? "Response" : "Page"})

    get "#{action_path("index")}"

    def call : #{@name.camelcase}::Index#{@endpoint_type == "api" ? "Response" : "Page"}
      result = IndexService.new.call

      if result.success?
        #{@resource_plural} = result.data.not_nil!
        #{@name.camelcase}::Index#{@endpoint_type == "api" ? "Response" : "Page"}.new(#{@resource_plural}: #{@resource_plural})
      else
        # Handle error - return empty list with error message
        #{@name.camelcase}::Index#{@endpoint_type == "api" ? "Response" : "Page"}.new(#{@resource_plural}: [] of #{@name.camelcase}::#{@name.camelcase})
      end
    end
  end
end
CRYSTAL
      end

      private def generate_show_endpoint_content : String
        <<-CRYSTAL
module #{@module_name}::#{@name.camelcase}
  struct ShowEndpoint
    include Azu::Endpoint(#{@name.camelcase}::ShowRequest, #{@name.camelcase}::Show#{@endpoint_type == "api" ? "Response" : "Page"})

    get "#{action_path("show")}"

    def call : #{@name.camelcase}::Show#{@endpoint_type == "api" ? "Response" : "Page"}
      id = show_request.id
      result = ShowService.new.call(id)

      if result.success?
        #{@resource_singular} = result.data.not_nil!
        #{@name.camelcase}::Show#{@endpoint_type == "api" ? "Response" : "Page"}.new(#{@resource_singular}: #{@resource_singular})
      else
        #{@endpoint_type == "api" ? "error(\"Not found\", 404, [\"#{@name.camelcase} not found\"])" : "redirect to: \"/#{@resource_plural}\""}
      end
    end
  end
end
CRYSTAL
      end

      private def generate_create_endpoint_content : String
        <<-CRYSTAL
module #{@module_name}::#{@name.camelcase}
  struct CreateEndpoint
    include Azu::Endpoint(#{@name.camelcase}::CreateRequest, #{@name.camelcase}::Create#{@endpoint_type == "api" ? "Response" : "Page"})

    post "#{action_path("create")}"

    def call : #{@name.camelcase}::Create#{@endpoint_type == "api" ? "Response" : "Page"}
      result = CreateService.new.call(create_request)

      if result.success?
        #{@resource_singular} = result.data.not_nil!
        #{@endpoint_type == "api" ? "#{@name.camelcase}::CreateResponse.new(#{@resource_singular}: #{@resource_singular})" : "redirect to: \"/#{@resource_plural}/\#{#{@resource_singular}.id}\""}
      else
        #{@endpoint_type == "api" ? "error(\"Validation failed\", 422, result.errors)" : "redirect to: \"/#{@resource_plural}/new\""}
      end
    end
  end
end
CRYSTAL
      end

      private def generate_update_endpoint_content : String
        <<-CRYSTAL
module #{@module_name}::#{@name.camelcase}
  struct UpdateEndpoint
    include Azu::Endpoint(#{@name.camelcase}::UpdateRequest, #{@name.camelcase}::Update#{@endpoint_type == "api" ? "Response" : "Page"})

    patch "#{action_path("update")}"

    def call : #{@name.camelcase}::Update#{@endpoint_type == "api" ? "Response" : "Page"}
      id = update_request.id
      result = UpdateService.new.call(id, update_request)

      if result.success?
        #{@resource_singular} = result.data.not_nil!
        #{@endpoint_type == "api" ? "#{@name.camelcase}::UpdateResponse.new(#{@resource_singular}: #{@resource_singular})" : "redirect to: \"/#{@resource_plural}/\#{#{@resource_singular}.id}\""}
      else
        #{@endpoint_type == "api" ? "error(\"Validation failed\", 422, result.errors)" : "redirect to: \"/#{@resource_plural}/\#{id}/edit\""}
      end
    end
  end
end
CRYSTAL
      end

      private def generate_destroy_endpoint_content : String
        <<-CRYSTAL
module #{@module_name}::#{@name.camelcase}
  struct DestroyEndpoint
    include Azu::Endpoint(#{@name.camelcase}::DestroyRequest, #{@name.camelcase}::Destroy#{@endpoint_type == "api" ? "Response" : "Page"})

    delete "#{action_path("destroy")}"

    def call : #{@name.camelcase}::Destroy#{@endpoint_type == "api" ? "Response" : "Page"}
      id = destroy_request.id
      result = DestroyService.new.call(id)

      if result.success?
        #{@endpoint_type == "api" ? "#{@name.camelcase}::DestroyResponse.new(success: true)" : "redirect to: \"/#{@resource_plural}\""}
      else
        #{@endpoint_type == "api" ? "error(\"Not found\", 404, [\"#{@name.camelcase} not found\"])" : "redirect to: \"/#{@resource_plural}\""}
      end
    end
  end
end
CRYSTAL
      end

      private def generate_new_endpoint_content : String
        <<-CRYSTAL
module #{@module_name}::#{@name.camelcase}
  struct NewEndpoint
    include Azu::Endpoint(#{@name.camelcase}::NewRequest, #{@name.camelcase}::New#{@endpoint_type == "api" ? "Response" : "Page"})

    get "#{action_path("new")}"

    def call : #{@name.camelcase}::New#{@endpoint_type == "api" ? "Response" : "Page"}
      # Render form page
      #{@name.camelcase}::New#{@endpoint_type == "api" ? "Response" : "Page"}.new
    end
  end
end
CRYSTAL
      end

      private def generate_edit_endpoint_content : String
        <<-CRYSTAL
module #{@module_name}::#{@name.camelcase}
  struct EditEndpoint
    include Azu::Endpoint(#{@name.camelcase}::EditRequest, #{@name.camelcase}::Edit#{@endpoint_type == "api" ? "Response" : "Page"})

    get "#{action_path("edit")}"

    def call : #{@name.camelcase}::Edit#{@endpoint_type == "api" ? "Response" : "Page"}
      id = edit_request.id
      result = ShowService.new.call(id)

      if result.success?
        #{@resource_singular} = result.data.not_nil!
        #{@name.camelcase}::Edit#{@endpoint_type == "api" ? "Response" : "Page"}.new(#{@resource_singular}: #{@resource_singular})
      else
        #{@endpoint_type == "api" ? "error(\"Not found\", 404, [\"#{@name.camelcase} not found\"])" : "redirect to: \"/#{@resource_plural}\""}
      end
    end
  end
end
CRYSTAL
      end

      # Get request parameters for specific action
      private def request_params_for_action(action : String) : String
        case action.downcase
        when "create", "update"
          return "" if @fields.empty?
          @fields.keys.map { |field| "@request.#{field}" }.join(", ")
        else
          ""
        end
      end
    end
  end
end
