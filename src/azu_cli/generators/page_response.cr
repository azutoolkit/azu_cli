require "teeplate"

module AzuCLI
  module Generate
    # PageResponse generator that creates Azu::Response structs for HTML pages
    class PageResponse < Teeplate::FileTree
      directory "#{__DIR__}/../templates/scaffold/src/pages"

      property name : String
      property fields : Hash(String, String)
      property snake_case_name : String

      def initialize(@name : String, @fields : Hash(String, String) = {} of String => String)
        @snake_case_name = @name.underscore
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
        # This is a stub; in a real generator, you might want to allow custom view data
        # For now, just output a comment and a basic structure
        <<-VIEWDATA
        # Customize the view data as needed
        data: {
          # "user" => { ... },
          # "posts" => posts.map { |post| { ... } },
          # ...
        }
        VIEWDATA
      end
    end
  end
end
