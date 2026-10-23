require "./resource"

module AzuCLI
  module Generate
    # Template generator: the Jinja template of one page. New and edit share the `_form` partial.
    # The path `public/templates/<app>/<resources>/<action>_page.jinja` is what
    # `Azu::Templates::Renderable#page_path` derives from the page's class name.
    class Template < Resource
      directory "#{__DIR__}/../templates/scaffold/public/templates"
      OUTPUT_DIR = "./public/templates"

      def rendered_file_entries
        file_entries.select do |entry|
          basename = File.basename(entry.path)
          basename.starts_with?("#{@action}_") || (basename == "_form.jinja" && {"new", "edit"}.includes?(@action))
        end
      end

      def title : String
        action_class == "Index" ? @namespace : "#{action_class} #{model_name}"
      end
    end
  end
end
