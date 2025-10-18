require "teeplate"

module AzuCLI
  module Generate
    # Project generator that creates a new Azu project from templates
    class Project < Teeplate::FileTree
      directory "#{__DIR__}/../templates/project"
      OUTPUT_DIR = "./"

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
      property include_joobq : Bool
      property github_name : String

      def initialize(@project : String, @module_name : String, @author : String, @email : String,
                     @license : String = "MIT", @project_type : String = "web",
                     @database : String = "postgresql", @test_framework : String = "spec",
                     @ci_setup : String = "GitHub Actions", @docker_support : Bool = false,
                     @git_init : Bool = true, @include_example : Bool = true, @include_joobq : Bool = true)
        # Extract GitHub username from email or use author name
        @github_name = extract_github_name(@email, @author)
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

      def database_adapter_uri_prefix : String
        case @database
        when "postgresql", "postgres", "pg"
          "postgresql"
        when "mysql"
          "mysql"
        when "sqlite", "sqlite3"
          "sqlite3"
        else
          "postgresql"
        end
      end

      def database_env_url : String
        case @database
        when "postgresql", "postgres", "pg"
          "postgresql://localhost/#{@project}_\#{config.env.downcase}"
        when "mysql"
          "mysql://localhost/#{@project}_\#{config.env.downcase}"
        when "sqlite", "sqlite3"
          "sqlite3://./db/#{@project}_\#{config.env.downcase}.db"
        else
          "postgresql://localhost/#{@project}_\#{config.env.downcase}"
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

      # Check if JoobQ should be included
      def has_joobq? : Bool
        @include_joobq && (@project_type == "web" || @project_type == "api")
      end

      # Generate schema class name from project name
      # Examples: "blog" → "BlogDB", "my_blog" → "MyBlogDB"
      def schema_name : String
        @module_name + "DB"
      end

      # Generate schema symbol from project name
      # Examples: "blog" → "blog_db", "my_blog" → "my_blog_db"
      def schema_symbol : String
        @project.downcase + "_db"
      end

      # Override filter method to conditionally exclude files based on project type
      def filter(entries)
        entries.reject do |entry|
          path = entry.path.to_s

          # Skip JoobQ-related files if not included
          if !has_joobq?
            next true if path.ends_with?("jobs.yml.ecr") ||
                         path.ends_with?("joobq.cr.ecr") ||
                         path.ends_with?("worker.cr.ecr") ||
                         path.ends_with?(".gitkeep.ecr")
          end

          # Skip web-specific files for API projects
          if api_project?
            next true if path.includes?("public/templates/") && !path.includes?("swagger-ui.html")
            next true if path.ends_with?("server.cr.ecr")
            next true if path.includes?("pages/welcome/")
            next true if path.includes?("public/assets/css/") && !path.ends_with?("cover.css")
            next true if path.includes?("public/assets/js/")
          end

          # Skip API-specific files for web/cli projects
          if !api_project?
            next true if path.includes?("endpoints/health/")
            next true if path.includes?("endpoints/api/")
            next true if path.includes?("public/api/")
            next true if path.ends_with?("openapi.yml.ecr")
            next true if path.ends_with?("api.yml.ecr")
            next true if path.ends_with?("api.cr.ecr")
          end

          # Skip server.cr for API projects (they use api.cr instead)
          if api_project? && path.ends_with?("server.cr.ecr")
            next true
          end

          false
        end
      end
    end
  end
end
