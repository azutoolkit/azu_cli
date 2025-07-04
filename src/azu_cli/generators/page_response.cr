require "teeplate"

module AzuCLI
  module Generate
    # PageResponse generator that creates Azu::Response structs and Jinja2 HTML templates for CRUD operations
    class PageResponse < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/pages"

      # Also generate Jinja2 HTML templates
      property template_generator : TemplateGenerator
      property name : String
      property fields : Hash(String, String)
      property snake_case_name : String
      property action : String
      property resource_plural : String
      property resource_singular : String

      def initialize(@name : String, @fields : Hash(String, String) = {} of String => String, @action : String = "index")
        @snake_case_name = @name.underscore
        @resource_singular = @name.downcase
        @resource_plural = @resource_singular + "s"
        @template_generator = TemplateGenerator.new(@name, @fields, @action)
      end

      def render(project_name : String)
        # Generate the Crystal page response struct
        super(project_name)
        # Generate the Jinja2 HTML template
        @template_generator.render(project_name)
      end

      # Convert name to page response struct name
      def struct_name : String
        @name.camelcase + "PageResponse"
      end

      # Get getter declarations
      def getter_declarations : String
        @fields.map { |name, type| "getter #{name} : #{crystal_type(type)}" }.join("\n  ")
      end

      # Get constructor parameters for fields
      def constructor_params : String
        @fields.map { |name, type| "@#{name} : #{crystal_type(type)}" }.join(", ")
      end

      # Get Crystal type for field
      def crystal_type(field_type : String) : String
        field_type
      end

      # Get view data hash for render method
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
          "#{@resource_plural}/index.html.j2"
        when "new"
          "#{@resource_plural}/new.html.j2"
        when "create"
          "#{@resource_plural}/create.html.j2"
        when "show"
          "#{@resource_plural}/show.html.j2"
        when "edit"
          "#{@resource_plural}/edit.html.j2"
        when "update"
          "#{@resource_plural}/update.html.j2"
        when "delete"
          "#{@resource_plural}/delete.html.j2"
        else
          "#{@resource_plural}/#{@action}.html.j2"
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
        headers = @fields.keys.map { |field| field.camelcase }
        headers.unshift("ID") unless headers.includes?("Id")
        headers.join("</th><th>")
      end

      # Get table row template for index page
      def table_row_template : String
        cells = @fields.keys.map { |field| "{{ #{@resource_singular}.#{field} }}" }
        cells.unshift("{{ #{@resource_singular}.id }}") unless @fields.keys.includes?("id")
        cells.join("</td><td>")
      end

      # Inner class for generating Jinja2 HTML templates
      class TemplateGenerator < Teeplate::FileTree
        directory "#{__DIR__}/../templates/scaffold/public/templates/pages"

        property name : String
        property fields : Hash(String, String)
        property action : String
        property snake_case_name : String
        property resource_plural : String
        property resource_singular : String

        def initialize(@name : String, @fields : Hash(String, String), @action : String)
          @snake_case_name = @name.underscore
          @resource_singular = @name.downcase
          @resource_plural = @resource_singular + "s"
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
end
