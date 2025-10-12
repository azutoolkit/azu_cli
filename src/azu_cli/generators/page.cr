require "teeplate"

module AzuCLI
  module Generate
    # Page generator that creates Azu::Response structs for both Web and API projects
    class Page < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/response"
      OUTPUT_DIR = "./src/pages" # Default to pages, but can be overridden

      # Also generate Jinja2 HTML templates for web projects
      property template_generator : Template
      property name : String
      property fields : Hash(String, String)
      property snake_case_name : String
      property action : String
      property resource_plural : String
      property resource_singular : String
      property resource : String # For template naming compatibility
      property module_name : String
      property generate_template : Bool = true
      property project_type : String = "web" # "web" or "api"
      property from_type : String?

      def initialize(@name : String, @fields : Hash(String, String) = {} of String => String, @action : String = "index", @project_type : String = "web", @from_type : String? = nil)
        @snake_case_name = @name.underscore
        @resource_singular = @name.downcase.singularize
        @resource_plural = @resource_singular.pluralize
        @resource = @snake_case_name # For template naming compatibility
        # Get module name from project
        @module_name = get_project_module_name
        @template_generator = Template.new(@name, @fields, @action)
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

      # Filter which template files to render based on project type
      def filter(entries)
        entries.select do |entry|
          # For API projects, only render the JSON template
          if @project_type == "api"
            entry.path.includes?("_json.cr.ecr")
          else
            # For web projects, only render the page template
            entry.path.includes?("_page.cr.ecr")
          end
        end
      end

      def render(output_dir : String, force : Bool = false, interactive : Bool = true, list : Bool = false, color : Bool = false)
        # Use Teeplate's render method
        super(output_dir, force: force, interactive: interactive, list: list, color: color)

        # Generate the Jinja2 HTML template only for web projects
        if @project_type == "web" && @generate_template
          @template_generator.render("#{output_dir}/../public")
        end
      end

      # Get the appropriate output directory based on project type
      # All pages/responses are generated in ./src/pages directory
      def self.output_dir_for_type(project_type : String) : String
        "./src/pages"
      end

      # Convert name to page response struct name based on project type
      def struct_name : String
        case @project_type
        when "api"
          @name.camelcase + @action.camelcase + "JSON"
        else # web (default)
          @name.camelcase + @action.camelcase + "Page"
        end
      end

      # Check if this is a web project
      def web_type : Bool
        @project_type == "web"
      end

      # Check if this is an API project
      def api_type : Bool
        @project_type == "api"
      end

      # Get getter declarations
      def getter_declarations : String
        @fields.map { |name, type| "getter #{name} : #{crystal_type(type)}" }.join("\n  ")
      end

      # Get constructor parameters for fields
      def constructor_params : String
        @fields.map { |name, type| "@#{name} : #{crystal_type(type)}" }.join(", ")
      end

      # Get assignments from source type (e.g., User)
      def assignments_from_source : String
        return "" unless @from_type
        @fields.map { |name, _| "@#{name} = #{from_var}.#{name}" }.join("\n    ")
      end

      # Get the variable name for the source type
      def from_var : String
        @from_type.try(&.underscore) || "source"
      end

      # Get Crystal type for field
      def crystal_type(field_type : String) : String
        case field_type.downcase
        when "string"
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
        when "string?"
          "String?"
        when "int32?"
          "Int32?"
        when "int64?"
          "Int64?"
        when "float64?"
          "Float64?"
        when "bool?"
          "Bool?"
        else
          "String"
        end
      end

      # Get render method based on project type
      def render_method : String
        case @project_type
        when "api"
          "def render\n    to_json\n  end"
        else # web (default)
          "def render\n    view #{view_data_hash}\n  end"
        end
      end

      # Get view data hash for render method (web projects only)
      def view_data_hash : String
        case @action
        when "index"
          "#{@resource_plural}: #{@resource_plural}"
        when "show", "edit"
          "#{@resource_singular}: #{@resource_singular}"
        when "new"
          "form: form"
        else
          "data: {}"
        end
      end

      # Get template path for the action
      def template_path : String
        case @action
        when "index"
          "#{@resource_plural}/index.jinja"
        when "new"
          "#{@resource_plural}/new.jinja"
        when "create"
          "#{@resource_plural}/create.jinja"
        when "show"
          "#{@resource_plural}/show.jinja"
        when "edit"
          "#{@resource_plural}/edit.jinja"
        when "update"
          "#{@resource_plural}/update.jinja"
        when "delete"
          "#{@resource_plural}/delete.jinja"
        else
          "#{@resource_plural}/#{@action}.jinja"
        end
      end

      # Get page title for the action
      def page_title : String
        case @action
        when "index"
          "#{@name.camelcase} List"
        when "new"
          "New #{@name.camelcase}"
        when "create"
          "Create #{@name.camelcase}"
        when "show"
          "#{@name.camelcase} Details"
        when "edit"
          "Edit #{@name.camelcase}"
        when "update"
          "Update #{@name.camelcase}"
        when "delete"
          "Delete #{@name.camelcase}"
        else
          "#{@action.camelcase} #{@name.camelcase}"
        end
      end

      # Get form action URL
      def form_action : String
        case @action
        when "new"
          "/#{@resource_plural}"
        when "edit"
          "/#{@resource_plural}/{{ #{@resource_singular}.id }}"
        else
          "/#{@resource_plural}"
        end
      end

      # Get form method
      def form_method : String
        case @action
        when "new"
          "POST"
        when "edit"
          "PATCH"
        else
          "POST"
        end
      end

      # Get field type for HTML input
      def html_input_type(field_type : String) : String
        case field_type.downcase
        when "email"
          "email"
        when "password"
          "password"
        when "int32", "int64", "float32", "float64"
          "number"
        when "bool"
          "checkbox"
        when "time"
          "datetime-local"
        when "text"
          "textarea"
        else
          "text"
        end
      end

      # Get field label
      def field_label(field_name : String) : String
        field_name.camelcase
      end

      # Get field placeholder
      def field_placeholder(field_name : String) : String
        "Enter #{field_name.downcase.gsub('_', ' ')}"
      end

      # Check if field is required
      def field_required?(field_name : String) : Bool
        !["id", "created_at", "updated_at"].includes?(field_name)
      end

      # Get Bootstrap form classes
      def form_classes : String
        "needs-validation"
      end

      # Get table headers for index page
      def table_headers : String
        headers = @fields.keys.map(&.camelcase)
        headers.unshift("ID") unless headers.includes?("Id")
        headers.join("</th><th>")
      end

      # Get table row template for index page
      def table_row_template : String
        cells = @fields.keys.map { |field| "{{ #{@resource_singular}.#{field} }}" }
        cells.unshift("{{ #{@resource_singular}.id }}") unless @fields.keys.includes?("id")
        cells.join("</td><td>")
      end
    end
  end
end
