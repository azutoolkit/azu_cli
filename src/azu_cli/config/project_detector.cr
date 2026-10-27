module AzuCLI
  # Detects the project type (web, api or cli) from the files of the project
  class ProjectDetector
    @cached_type : String?

    def initialize(@project_path : String = ".")
    end

    # Detect project type (web, api, cli)
    def detect_type : String
      return @cached_type.not_nil! if @cached_type

      # Try to detect from structure
      if type = type_from_structure
        @cached_type = type
        return type
      end

      # Default to web
      @cached_type = "web"
      "web"
    end

    # Check if project is API-only
    def api_project? : Bool
      detect_type == "api"
    end

    # Check if project is web
    def web_project? : Bool
      detect_type == "web"
    end

    # Check if project is CLI
    def cli_project? : Bool
      detect_type == "cli"
    end

    # Detect type from project structure
    private def type_from_structure : String?
      # Check for web-specific files
      has_templates = Dir.exists?(File.join(@project_path, "public/templates"))
      has_pages = Dir.exists?(File.join(@project_path, "src/pages"))
      has_server = File.exists?(File.join(@project_path, "src/server.cr"))

      # Check for API-specific files
      has_api_file = File.exists?(File.join(@project_path, "src/api.cr"))
      has_openapi_config = File.exists?(File.join(@project_path, "config/openapi.yml"))
      has_api_config = File.exists?(File.join(@project_path, "config/api.yml"))

      # Check for CLI-specific files
      has_cli_file = File.exists?(File.join(@project_path, "src/cli.cr"))

      # Decision logic
      if has_api_file || (has_openapi_config && has_api_config)
        return "api"
      elsif has_cli_file && !has_server
        return "cli"
      elsif has_templates || has_pages
        return "web"
      end

      nil
    end
  end
end
