require "./resource"

module AzuCLI
  module Generate
    # Page generator: the HTML response of one read action. Its Jinja template lives where
    # `Azu::Templates::Renderable#page_path` looks for it (`public/templates/<app>/<resources>/`),
    # see `Template`.
    class Page < Resource
      directory "#{__DIR__}/../templates/scaffold/src/pages"
      OUTPUT_DIR = "./src/pages"
      ACTIONS    = %w(index show new edit)

      def page_struct_name : String
        "#{action_class}Page"
      end
    end

    # Response generator: the JSON response of one read action of an API resource.
    class Response < Resource
      directory "#{__DIR__}/../templates/scaffold/src/responses"
      OUTPUT_DIR = "./src/responses"
      ACTIONS    = %w(index show)

      def response_struct_name : String
        "#{action_class}Response"
      end
    end
  end
end
