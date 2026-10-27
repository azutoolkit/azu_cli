require "yaml"

module AzuCLI
  # Detects the project type (web, api or cli) from the files of the project
  class ProjectDetector
    @cached_type : String?

    def initialize(@project_path : String = ".")
    end

    # Detect project type (web, api, cli)
    def detect_type : String
      return @cached_type.not_nil! if @cached_type

      # A generated project names its type in the main target of shard.yml: web and api projects have the
      # same files (src/server.cr and src/api.cr are in both), so the files cannot tell them apart.
      if type = type_from_shard
        @cached_type = type
        return type
      end

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

    # The type from the main target of shard.yml: src/api.cr is an API, src/server.cr a web app.
    private def type_from_shard : String?
      path = File.join(@project_path, "shard.yml")
      return nil unless File.exists?(path)

      targets = YAML.parse(File.read(path))["targets"]?.try(&.as_h?) || return nil
      mains = targets.values.compact_map { |target| target.as_h?.try(&.[YAML::Any.new("main")]?).try(&.as_s?) }
      return "api" if mains.includes?("src/api.cr")
      return "web" if mains.includes?("src/server.cr")

      nil
    rescue YAML::ParseException
      nil
    end

    # Detect type from project structure
    private def type_from_structure : String?
      # Check for web-specific files
      has_templates = Dir.exists?(File.join(@project_path, "public/templates"))
      has_pages = Dir.exists?(File.join(@project_path, "src/pages"))
      has_server = File.exists?(File.join(@project_path, "src/server.cr"))

      # Without a shard.yml target to go by: src/api.cr on its own is an API
      has_api_file = File.exists?(File.join(@project_path, "src/api.cr"))

      # Check for CLI-specific files
      has_cli_file = File.exists?(File.join(@project_path, "src/cli.cr"))

      # Decision logic
      if has_api_file && !has_server
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
