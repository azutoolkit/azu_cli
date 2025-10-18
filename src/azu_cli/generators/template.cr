require "teeplate"

module AzuCLI
  module Generate
    # Inner class for generating Jinja2 HTML templates
    class Template < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/public/templates"
      OUTPUT_DIR = "./public/templates"

      property name : String
      property fields : Hash(String, String)
      property action : String
      property snake_case_name : String
      property resource_plural : String
      property resource_singular : String
      property module_name : String
      property module_path : String
      property resource : String

      def initialize(@name : String, @fields : Hash(String, String), @action : String, @module_name : String = "App")
        @snake_case_name = @name.underscore
        @resource_singular = @name.downcase.singularize
        @resource_plural = @resource_singular.pluralize
        @resource = @snake_case_name
        @module_path = calculate_module_path
      end

      # Calculate module path from class name for template directory structure
      private def calculate_module_path : String
        # Extract module path from full class name
        # Blog::Post::IndexPage → "blog/post"
        parts = @module_name.split("::")
        if parts.size > 1
          parts[0..-1].map(&.underscore).join("/")
        else
          @snake_case_name
        end
      end

      # Get template filename for the action
      def template_filename : String
        "#{@action}_page.jinja"
      end

      # Get full template path matching Azu framework expectations
      def template_path : String
        "#{@module_path}/#{template_filename}"
      end

      # Override render to create proper directory structure
      def render(output_dir : String, force : Bool = false, interactive : Bool = true, list : Bool = false, color : Bool = false)
        # Create the full module path directory
        full_path = File.join(output_dir, @module_path)
        Dir.mkdir_p(full_path) unless Dir.exists?(full_path)

        # Use Teeplate's render method with the correct output directory
        super(full_path, force: force, interactive: interactive, list: list, color: color)
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
    end
  end
end
