require "teeplate"

module Generate
  # Project generator that creates a new Azu project from templates
  class Project < Teeplate::FileTree
    # Project configuration properties
    property project : String
    property module_name : String
    property author : String
    property email : String
    property license : String
    property project_type : String
    property database : String
    property test_framework : String
    property ci_setup : String
    property docker_support : Bool
    property git_init : Bool
    property include_example : Bool
    property github_name : String

    def initialize(@project : String, @module_name : String, @author : String, @email : String,
                   @license : String = "MIT", @project_type : String = "web",
                   @database : String = "postgresql", @test_framework : String = "spec",
                   @ci_setup : String = "GitHub Actions", @docker_support : Bool = false,
                   @git_init : Bool = true, @include_example : Bool = true)

      # Extract GitHub username from email or use author name
      @github_name = extract_github_name(@email, @author)

      # Set template directory to the project templates
      super("#{__DIR__}/../templates/project")
    end

    # Extract GitHub username from email or fallback to author name
    private def extract_github_name(email : String, author : String) : String
      if email.includes?("@")
        username = email.split("@")[0]
        # Clean up common email prefixes/suffixes
        username = username.gsub(/[^a-zA-Z0-9_-]/, "").downcase
        username.empty? ? author.downcase.gsub(/\s+/, "") : username
      else
        author.downcase.gsub(/\s+/, "")
      end
    end

    # Get database adapter name for dependencies
    def database_adapter : String
      case @database
      when "postgresql", "postgres", "pg"
        "pg"
      when "mysql"
        "mysql"
      when "sqlite", "sqlite3"
        "sqlite3"
      else
        "pg" # Default to PostgreSQL
      end
    end

    # Get database dependency for shard.yml
    def database_dependency : String
      case database_adapter
      when "pg"
        <<-DEPS
          pg:
            github: will/crystal-pg
        DEPS
      when "mysql"
        <<-DEPS
          mysql:
            github: crystal-lang/crystal-mysql
        DEPS
      when "sqlite3"
        <<-DEPS
          sqlite3:
            github: crystal-lang/crystal-sqlite3
        DEPS
      else
        <<-DEPS
          pg:
            github: will/crystal-pg
        DEPS
      end
    end

    # Get test framework dependency
    def test_dependency : String
      case @test_framework
      when "spec"
        "" # Built into Crystal
      when "minitest"
        <<-DEPS
          minitest:
            github: ysbaddaden/minitest.cr
        DEPS
      else
        ""
      end
    end

    # Check if project should include CI configuration
    def has_ci? : Bool
      @ci_setup != "None"
    end

    # Get CI workflow filename
    def ci_filename : String
      case @ci_setup
      when "GitHub Actions"
        "ci.yml"
      when "GitLab CI"
        ".gitlab-ci.yml"
      else
        ""
      end
    end

    # Check if it's a web project type
    def web_project? : Bool
      @project_type == "web"
    end

    # Check if it's an API project type
    def api_project? : Bool
      @project_type == "api"
    end

    # Check if it's a CLI project type
    def cli_project? : Bool
      @project_type == "cli"
    end

    # Get the main file extension based on project type
    def main_file : String
      case @project_type
      when "web"
        "server.cr"
      when "api"
        "api.cr"
      when "cli"
        "cli.cr"
      else
        "server.cr"
      end
    end

    # Get the binary name for targets
    def binary_name : String
      @project.downcase.gsub(/[^a-z0-9_]/, "_")
    end

    # Get example endpoint or component based on project type
    def example_component : String
      case @project_type
      when "web"
        "welcome endpoint with HTML page"
      when "api"
        "health check API endpoint"
      when "cli"
        "version and help commands"
      else
        "welcome endpoint"
      end
    end
  end
end
