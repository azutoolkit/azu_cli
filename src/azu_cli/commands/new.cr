require "../command"
require "../generators/project"
require "file_utils"

module AzuCLI::Commands
  # New command - creates a new Azu project with interactive setup
  class New < Command
    command_name "new"
    description "Create a new Azu project"
    usage "new <project_name> [options]"

    PROJECT_TYPES = {
      "web" => {
        name:        "Full-stack Web Application",
        description: "Complete web application with frontend and backend",
        features:    ["Endpoints", "Views", "Models", "Authentication", "Asset Pipeline"],
      },
      "api" => {
        name:        "API-only Application",
        description: "RESTful API server without frontend components",
        features:    ["Endpoints", "Models", "JSON serialization", "API versioning"],
      },
      "cli" => {
        name:        "Command Line Interface",
        description: "CLI application using Crystal and Topia",
        features:    ["Command structure", "Argument parsing", "Configuration", "Testing"],
      },
    }

    DATABASE_TYPES = ["postgresql", "mysql", "sqlite"]

    def execute(args : Hash(String, String | Array(String))) : String | Nil
      positional = get_positional_args(args)

      # Get project name from arguments
      if positional.empty?
        log.error("Project name is required")
        log.info("Usage: azu new <project_name> [options]")
        return nil
      end

      project_name = positional.first

      # Validate project name
      unless valid_project_name?(project_name)
        log.error("Invalid project name: #{project_name}")
        log.info("Project name must contain only letters, numbers, underscores, and hyphens")
        log.info("Examples: my_app, blog-api, user_management")
        return nil
      end

      # Check if directory already exists
      if Dir.exists?(project_name) && !has_flag?(args, "force")
        log.error("Directory '#{project_name}' already exists")
        log.info("Use --force to overwrite the existing directory")
        return nil
      end

      # Get options
      force = has_flag?(args, "force")
      skip_interactive = has_flag?(args, "skip-interactive") || has_flag?(args, "s")
      project_type = get_flag(args, "type", "")
      database = get_flag(args, "database", "")

      # Interactive setup unless skipped
      unless skip_interactive
        project_type = prompt_project_type if project_type.empty?
        database = prompt_database_type if database.empty?
      else
        project_type = "web" if project_type.empty?
        database = "postgresql" if database.empty?
      end

      # Validate options
      unless PROJECT_TYPES.has_key?(project_type)
        log.error("Invalid project type: #{project_type}")
        log.info("Available types: #{PROJECT_TYPES.keys.join(", ")}")
        return nil
      end

      unless DATABASE_TYPES.includes?(database)
        log.error("Invalid database type: #{database}")
        log.info("Available databases: #{DATABASE_TYPES.join(", ")}")
        return nil
      end

      # Create the project
      create_project(project_name, project_type, database, force)

      nil
    end

    private def valid_project_name?(name : String) : Bool
      # Crystal naming convention: letters, numbers, underscores, hyphens
      /^[a-zA-Z][a-zA-Z0-9_-]*$/.matches?(name)
    end

    private def prompt_project_type : String
      puts
      puts "🚀 What type of project would you like to create?".colorize(:cyan).bold
      puts

      PROJECT_TYPES.each_with_index do |(key, info), index|
        puts "  #{(index + 1).to_s.colorize(:yellow).bold}. #{info[:name].colorize(:green).bold}"
        puts "     #{info[:description]}"
        puts "     Features: #{info[:features].join(", ")}"
        puts
      end

      loop do
        print "Select project type [1-#{PROJECT_TYPES.size}]: ".colorize(:cyan)
        input = gets.try(&.strip) || ""

        if input.to_i? && (1..PROJECT_TYPES.size).includes?(input.to_i)
          return PROJECT_TYPES.keys[input.to_i - 1]
        end

        if PROJECT_TYPES.has_key?(input)
          return input
        end

        puts "Invalid selection. Please choose 1-#{PROJECT_TYPES.size} or type the project type name.".colorize(:red)
      end
    end

    private def prompt_database_type : String
      puts
      puts "🗄️  Which database would you like to use?".colorize(:cyan).bold
      puts

      DATABASE_TYPES.each_with_index do |db, index|
        description = case db
                      when "postgresql" then "Production-ready with advanced features"
                      when "mysql"      then "Popular choice with good performance"
                      when "sqlite"     then "Lightweight, file-based database"
                      else                   "Database option"
                      end

        puts "  #{(index + 1).to_s.colorize(:yellow).bold}. #{db.capitalize.colorize(:green).bold}"
        puts "     #{description}"
      end
      puts

      loop do
        print "Select database [1-#{DATABASE_TYPES.size}]: ".colorize(:cyan)
        input = gets.try(&.strip) || ""

        if input.to_i? && (1..DATABASE_TYPES.size).includes?(input.to_i)
          return DATABASE_TYPES[input.to_i - 1]
        end

        if DATABASE_TYPES.includes?(input.downcase)
          return input.downcase
        end

        puts "Invalid selection. Please choose 1-#{DATABASE_TYPES.size} or type the database name.".colorize(:red)
      end
    end

    private def create_project(name : String, type : String, database : String, force : Bool)
      puts
      puts "🔨 Creating Azu project '#{name}'...".colorize(:cyan).bold
      puts "   Type: #{PROJECT_TYPES[type][:name]}".colorize(:green)
      puts "   Database: #{database.capitalize}".colorize(:green)
      puts

      # Remove existing directory if force is enabled
      if Dir.exists?(name) && force
        log.info("Removing existing directory '#{name}'")
        FileUtils.rm_rf(name)
      end

      begin
        # Create project using existing generator
        generator = Generator::Project.new(name, database)
        generator.render(name)

        # Post-creation setup
        setup_git_repository(name)
        install_dependencies(name)

        show_success_message(name, type, database)
      rescue ex : Exception
        log.error("Failed to create project: #{ex.message}")
        # Clean up partially created project
        FileUtils.rm_rf(name) if Dir.exists?(name)
        raise ex
      end
    end

    private def setup_git_repository(project_name : String)
      Dir.cd(project_name) do
        if system("git --version > /dev/null 2>&1")
          log.info("Initializing git repository")
          system("git init")
          system("git add .")
          system("git commit -m 'Initial commit'")
        end
      end
    end

    private def install_dependencies(project_name : String)
      Dir.cd(project_name) do
        if File.exists?("shard.yml")
          log.info("Installing dependencies")
          if system("shards --version > /dev/null 2>&1")
            system("shards install")
          else
            log.warn("Shards not found. Please install dependencies manually with 'shards install'")
          end
        end
      end
    end

    private def show_success_message(name : String, type : String, database : String)
      puts
      puts "✅ Project '#{name}' created successfully!".colorize(:green).bold
      puts
      puts "📁 Project Structure:".colorize(:cyan).bold
      puts "   📂 src/              # Application source code"
      puts "   📂 src/endpoints/    # HTTP endpoints (controllers)"
      puts "   📂 src/pages/        # Page components (views)"
      puts "   📂 src/contracts/    # Request/response contracts"
      puts "   📂 src/models/       # Database models"
      puts "   📂 src/initializers/ # Application initializers"
      puts "   📂 public/           # Static assets"
      puts "   📂 spec/             # Test files"
      puts "   📄 shard.yml         # Dependencies configuration"
      puts

      puts "🚀 Next Steps:".colorize(:yellow).bold
      puts "   1. cd #{name}"
      puts "   2. azu serve           # Start development server"
      puts "   3. azu db:create       # Create database (if using #{database})"
      puts "   4. azu db:migrate      # Run migrations"
      puts
      puts "💡 Useful Commands:".colorize(:cyan).bold
      puts "   azu generate controller users    # Generate a controller"
      puts "   azu scaffold post title:string   # Generate complete resource"
      puts "   azu help                         # Show all available commands"
      puts
      puts "📖 Documentation:".colorize(:blue).bold
      puts "   • Azu Toolkit: https://azutopia.gitbook.io/azu/"
      puts "   • CQL ORM: https://github.com/azutoolkit/cql"
      puts
      puts "Happy coding! 🎉".colorize(:magenta).bold
    end

    def show_command_specific_help
      puts "Arguments:"
      puts "  <project_name>      Name of the project to create"
      puts
      puts "Options:"
      puts "  --type TYPE         Project type (web, api, cli)"
      puts "  --database DB       Database type (postgresql, mysql, sqlite)"
      puts "  --force             Overwrite existing directory"
      puts "  --skip-interactive  Skip interactive prompts"
      puts "  -s                  Alias for --skip-interactive"
      puts
      puts "Examples:"
      puts "  azu new my_app                           # Interactive setup"
      puts "  azu new blog --type web --database mysql # Specific options"
      puts "  azu new api_server --type api -s         # Skip interactive"
      puts "  azu new my_cli --type cli --force        # Overwrite existing"
    end
  end
end
