require "./base"

module AzuCLI
  module Commands
    # Init command for initializing Azu in existing projects
    class Init < Base
      def initialize
        super("init", "Initialize Azu in existing project")
      end

      def execute : Result
        parse_args(get_args)

        Logger.info("Initializing Azu in current project...")

        # Check if we're in a valid project directory
        unless valid_project_directory?
          return error("Not in a valid Crystal project directory. Run this command from your project root.")
        end

        # Create basic project structure
        create_project_structure

        Logger.info("✅ Azu initialized successfully!")
        success("Azu initialized in current project")
      end

      private def valid_project_directory? : Bool
        File.exists?("shard.yml")
      end

      private def create_project_structure
        Logger.info("Creating project structure...")

        # Create basic directories
        directories = [
          "src/models",
          "src/endpoints",
          "src/services",
          "src/pages",
          "src/middleware",
          "src/validators",
          "src/channels",
          "src/handlers",
          "src/requests",
          "src/responses",
          "src/components",
          AzuCLI::Config::Paths::MIGRATIONS,
          "spec/models",
          "spec/endpoints",
          "spec/services",
          "public/templates",
          "public/assets",
        ]

        directories.each do |dir|
          Dir.mkdir_p(dir)
        end
      end

      def show_help
        puts "Usage: azu init [options]"
        puts
        puts "Initialize Azu in an existing Crystal project."
        puts
        puts "This command will:"
        puts "  - Create the directories Azu generators write to (src/models, src/endpoints, ...)"
        puts
        puts "It takes no options and does not edit shard.yml."
        puts
        puts "Example:"
        puts "  azu init"
      end
    end
  end
end
