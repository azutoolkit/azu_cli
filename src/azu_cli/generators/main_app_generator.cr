require "./base"

module AzuCLI
  module Generators
    class MainAppGenerator < Base
      directory "#{__DIR__}/../templates/generators/main_app"

      # Instance variables expected by Teeplate from template scanning
      @app_name : String
      @app_name_camelcase : String

      def initialize(app_name : String, output_dir : String = "src")
        super(app_name, output_dir)
        @app_name = app_name
        @app_name_camelcase = app_name.camelcase
      end

      def template_directory : String
        "#{__DIR__}/../templates/generators/main_app"
      end

      def build_output_path : String
        File.join(@output_dir, "#{@name}.cr")
      end

      # Template method for accessing app name in camelcase
      def app_name_camelcase
        @app_name_camelcase
      end

      # Template method for accessing app name
      def app_name
        @app_name
      end
    end
  end
end
