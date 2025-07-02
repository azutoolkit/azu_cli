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

        # Initialize Azu configuration
        initialize_configuration

        # Create basic project structure
        create_project_structure

        Logger.info("✅ Azu initialized successfully!")
        success("Azu initialized in current project")
      end

      private def valid_project_directory? : Bool
        File.exists?("shard.yml")
      end

      private def initialize_configuration
        Logger.info("Creating Azu configuration...")

        # Create config directory if it doesn't exist
        Dir.mkdir_p("config")

        # Create basic configuration files
        create_config_file("config/azu.yml", default_config_content)
      end

      private def create_project_structure
        Logger.info("Creating project structure...")

        # Create basic directories
        directories = [
          "src/models",
          "src/endpoints",
          "src/services",
          "src/contracts",
          "src/pages",
          "src/middleware",
          "src/validators",
          "src/channels",
          "src/handlers",
          "src/requests",
          "src/responses",
          "src/components",
          "src/db/migrations",
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

      private def create_config_file(path : String, content : String)
        unless File.exists?(path)
          File.write(path, content)
          Logger.info("Created #{path}")
        end
      end

      private def default_config_content : String
        <<-YAML
        # Azu CLI Configuration
        version: "1.0.0"

        # Project settings
        project:
          name: "#{get_project_name}"
          type: "web"

        # Database configuration
        database:
          adapter: "postgresql"
          url: "${DATABASE_URL}"
          host: "localhost"
          port: 5432
          database: "#{get_project_name}_development"
          username: "postgres"
          password: ""

        # Server configuration
        server:
          host: "localhost"
          port: 3000
          environment: "development"
          reload: true

        # Generator configuration
        generators:
          templates_path: "src/azu_cli/templates"
          output_path: "src"
          test_output_path: "spec"

        # Plugin configuration
        plugins: {}
        YAML
      end

      private def get_project_name : String
        if File.exists?("shard.yml")
          content = File.read("shard.yml")
          if match = content.match(/name:\s*(\w+)/)
            return match[1]
          end
        end

        File.basename(Dir.current)
      end

      def show_help
        puts "Usage: azu init [options]"
        puts
        puts "Initialize Azu in an existing Crystal project."
        puts
        puts "This command will:"
        puts "  - Create Azu configuration files"
        puts "  - Set up project directory structure"
        puts "  - Initialize basic project files"
        puts
        puts "Options:"
        puts "  --force                 Overwrite existing configuration"
        puts "  --skip-structure        Skip directory structure creation"
        puts
        puts "Examples:"
        puts "  azu init"
        puts "  azu init --force"
      end
    end
  end
end
