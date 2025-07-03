require "./base"

module AzuCLI
  module Generators
    # Project types supported by the README generator
    enum ProjectType
      Library
      CLI
      Web
      Service

      def to_s(io : IO) : Nil
        case self
        when .library?
          io << "library"
        when .cli?
          io << "cli"
        when .web?
          io << "web"
        when .service?
          io << "service"
        end
      end

      def self.from_string(type : String) : ProjectType
        case type.downcase
        when "library", "lib"
          Library
        when "cli", "command", "tool"
          CLI
        when "web", "webapp", "website"
          Web
        when "service", "api", "microservice"
          Service
        else
          raise ArgumentError.new("Unsupported project type: #{type}. Supported: library, cli, web, service")
        end
      end
    end

    # Configuration for README generation
    struct ReadmeConfiguration
      getter project_name : String
      getter description : String
      getter github_user : String
      getter license : String
      getter crystal_version : String
      getter authors : Array(String)
      getter features : Array(String)
      getter project_type : ProjectType
      getter database : String
      getter has_badges : Bool
      getter has_api_docs : Bool
      getter has_roadmap : Bool
      getter roadmap_items : Array(String)
      getter has_acknowledgments : Bool
      getter acknowledgments : Array(String)
      getter has_support_info : Bool
      getter support_info : String

      def initialize(@project_name : String,
                     @description : String = "A Crystal project",
                     @github_user : String = "your-github-user",
                     @license : String = "MIT",
                     @crystal_version : String = ">= 1.16.0",
                     @authors : Array(String) = ["Your Name <your@email.com>"],
                     @features : Array(String) = default_features,
                     @project_type : ProjectType = ProjectType::Library,
                     @database : String = "none",
                     @has_badges : Bool = true,
                     @has_api_docs : Bool = true,
                     @has_roadmap : Bool = false,
                     @roadmap_items : Array(String) = [] of String,
                     @has_acknowledgments : Bool = false,
                     @acknowledgments : Array(String) = [] of String,
                     @has_support_info : Bool = false,
                     @support_info : String = "")
      end

      def database_display_name : String
        case @database.downcase
        when "postgresql", "postgres", "pg"
          "PostgreSQL"
        when "mysql"
          "MySQL"
        when "sqlite", "sqlite3"
          "SQLite"
        else
          @database.capitalize
        end
      end

      def self.default_features
        [
          "🚀 Fast and efficient",
          "📦 Easy to install and use",
          "🔧 Well tested and documented",
          "💎 Built with Crystal"
        ]
      end
    end

    class ReadmeGenerator < Base
      directory "#{__DIR__}/../templates/generators/readme"

      # Instance variables expected by Teeplate from template scanning
      @project_name : String
      @project_name_title : String
      @project_name_kebabcase : String
      @project_name_snakecase : String
      @project_name_camelcase : String
      @description : String
      @github_user : String
      @license : String
      @crystal_version : String
      @authors : Array(String)
      @features : Array(String)
      @project_type : String
      @database : String
      @database_display_name : String
      @has_badges : Bool
      @has_api_docs : Bool
      @has_roadmap : Bool
      @roadmap_items : Array(String)
      @has_acknowledgments : Bool
      @acknowledgments : Array(String)
      @has_support_info : Bool
      @support_info : String

      getter configuration : ReadmeConfiguration

      def initialize(project_name : String,
                     output_dir : String = ".",
                     generate_specs : Bool = false, # README doesn't need specs
                     description : String = "A Crystal project",
                     github_user : String = "your-github-user",
                     license : String = "MIT",
                     crystal_version : String = ">= 1.16.0",
                     authors : Array(String) = ["Your Name <your@email.com>"],
                     features : Array(String) = [] of String,
                     project_type : String | ProjectType = ProjectType::Library,
                     database : String = "none",
                     has_badges : Bool = true,
                     has_api_docs : Bool = true,
                     has_roadmap : Bool = false,
                     roadmap_items : Array(String) = [] of String,
                     has_acknowledgments : Bool = false,
                     acknowledgments : Array(String) = [] of String,
                     has_support_info : Bool = false,
                     support_info : String = "")
        super(project_name, output_dir, generate_specs)

                # Convert string project type to enum if needed
        type = project_type.is_a?(String) ? ProjectType.from_string(project_type) : project_type

        # Use default features if none provided
        final_features = features.empty? ? ReadmeConfiguration.default_features : features

        @configuration = ReadmeConfiguration.new(
          project_name, description, github_user, license, crystal_version,
          authors, final_features, type, database, has_badges, has_api_docs,
          has_roadmap, roadmap_items, has_acknowledgments, acknowledgments,
          has_support_info, support_info
        )

        @project_name = project_name
        @project_name_title = format_title(project_name)
        @project_name_kebabcase = name_kebabcase
        @project_name_snakecase = name_snakecase
        @project_name_camelcase = name_camelcase
        @description = description
        @github_user = github_user
        @license = license
        @crystal_version = crystal_version
        @authors = authors
        @features = final_features
        @project_type = type.to_s
        @database = database
        @database_display_name = @configuration.database_display_name
        @has_badges = has_badges
        @has_api_docs = has_api_docs
        @has_roadmap = has_roadmap
        @roadmap_items = roadmap_items
        @has_acknowledgments = has_acknowledgments
        @acknowledgments = acknowledgments
        @has_support_info = has_support_info
        @support_info = support_info
      end

      def template_directory : String
        "#{__DIR__}/../templates/generators/readme"
      end

      def build_output_path : String
        File.join(@output_dir, "README.md")
      end

      # Override spec template - README doesn't need specs
      protected def generate_spec_file!
        # No spec file for README.md
      end

      # Template methods for accessing README properties
      def project_name
        @project_name
      end

      def project_name_title
        @project_name_title
      end

      def project_name_kebabcase
        @project_name_kebabcase
      end

      def project_name_snakecase
        @project_name_snakecase
      end

      def project_name_camelcase
        @project_name_camelcase
      end

      def description
        @description
      end

      def github_user
        @github_user
      end

      def license
        @license
      end

      def crystal_version
        @crystal_version
      end

      def authors
        @authors
      end

      def features
        @features
      end

      def project_type
        @project_type
      end

      def database
        @database
      end

      def database_display_name
        @database_display_name
      end

      def has_badges?
        @has_badges
      end

      def has_api_docs?
        @has_api_docs
      end

      def has_roadmap?
        @has_roadmap
      end

      def roadmap_items
        @roadmap_items
      end

      def has_acknowledgments?
        @has_acknowledgments
      end

      def acknowledgments
        @acknowledgments
      end

      def has_support_info?
        @has_support_info
      end

      def support_info
        @support_info
      end

      # Helper methods for template
      def author_github_url(author : String) : String
        # Extract GitHub username from author info or use default
        if author.includes?("github.com")
          # Extract from existing GitHub URL
          author.match(/github\.com\/([^)]+)/).try(&.[1]) || @github_user
        else
          # Use the part before < as username, fallback to configured user
          username = author.split('<').first.strip.downcase.gsub(/\s+/, "-")
          "https://github.com/#{username}"
        end
      end

      def author_role(author : String) : String
        # Determine role based on position in authors array
        return "creator and maintainer" if author == @authors.first
        "contributor"
      end

      # Format project name as title (handle various naming conventions)
      private def format_title(name : String) : String
        # Convert snake_case, kebab-case, or camelCase to Title Case
        name.gsub(/[-_]/, " ")
            .split(" ")
            .map(&.capitalize)
            .join(" ")
      end

      # Validation methods
      protected def validate_preconditions!
        super
        validate_readme_configuration!
      end

      private def validate_readme_configuration!
        raise ArgumentError.new("Description cannot be empty") if @description.empty?
        raise ArgumentError.new("GitHub user cannot be empty") if @github_user.empty?
        raise ArgumentError.new("License cannot be empty") if @license.empty?
        raise ArgumentError.new("Crystal version cannot be empty") if @crystal_version.empty?
        raise ArgumentError.new("Authors cannot be empty") if @authors.empty?

        @authors.each do |author|
          raise ArgumentError.new("Author cannot be empty") if author.empty?
        end

        validate_github_user!
        validate_features!
      end

      private def validate_github_user!
        # Basic GitHub username validation
        unless @github_user.matches?(/^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?$/)
          raise ArgumentError.new("Invalid GitHub username format: #{@github_user}")
        end
      end

      private def validate_features!
        @features.each do |feature|
          raise ArgumentError.new("Feature cannot be empty") if feature.empty?
        end
      end

      protected def post_generation_hook
        super
        AzuCLI::Logger.info("Generated comprehensive README.md for #{@project_name}")
        AzuCLI::Logger.info("Project type: #{@project_type}")
        AzuCLI::Logger.info("Don't forget to customize the content for your specific project!")
      end
    end
  end
end
