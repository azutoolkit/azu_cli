require "../command"
require "../generators/project"
require "file_utils"

module AzuCLI::Commands
  # Init command - initializes Azu in an existing Crystal project
  class Init < Command
    command_name "init"
    description "Initialize Azu in an existing Crystal project"
    usage "init [options]"

    PROJECT_INDICATORS = {
      "web" => ["src/controllers", "src/views", "public", "config.ru"],
      "api" => ["src/controllers", "src/serializers", "api"],
      "cli" => ["src/commands", "src/cli.cr", "bin/"],
    }

    DATABASE_INDICATORS = {
      "postgresql" => ["pg", "postgres", "postgresql"],
      "mysql"      => ["mysql", "mysql2"],
      "sqlite"     => ["sqlite3", "sqlite"],
    }

    def execute(args : Hash(String, String | Array(String))) : String | Nil
      # Check if we're in a Crystal project
      unless has_shard_yml?
        log.error("No shard.yml file found")
        log.info("This command must be run from the root of a Crystal project")
        log.info("Use 'azu new <project_name>' to create a new project instead")
        return nil
      end

      # Check if Azu is already initialized
      if azu_initialized? && !has_flag?(args, "force")
        log.error("Azu is already initialized in this project")
        log.info("Use --force to reinitialize")
        return nil
      end

      # Get options
      force = has_flag?(args, "force")
      skip_interactive = has_flag?(args, "skip-interactive") || has_flag?(args, "s")
      project_type = get_flag(args, "type", "")
      database = get_flag(args, "database", "")

      # Detect project characteristics
      detected_type = detect_project_type
      detected_database = detect_database_type

      log.info("🔍 Analyzing existing project...")

      current_project = get_project_info
      puts
      puts "📋 Current Project:".colorize(:cyan).bold
      puts "   Name: #{current_project[:name]}".colorize(:green)
      puts "   Path: #{current_project[:path]}".colorize(:green)
      if detected_type
        puts "   Detected Type: #{detected_type}".colorize(:yellow)
      end
      if detected_database
        puts "   Detected Database: #{detected_database}".colorize(:yellow)
      end

      # Interactive setup unless skipped
      unless skip_interactive
        unless confirm_initialization
          log.info("Initialization cancelled")
          return nil
        end

        project_type = prompt_project_type(detected_type) if project_type.empty?
        database = prompt_database_type(detected_database) if database.empty?
      else
        project_type = detected_type || "web"
        database = detected_database || "postgresql"
      end

      # Initialize Azu in the project
      initialize_azu(current_project[:name], project_type, database, force)

      nil
    end

    private def has_shard_yml? : Bool
      File.exists?("shard.yml")
    end

    private def azu_initialized? : Bool
      # Check for Azu-specific files or dependencies
      return true if File.exists?("config/azu.yml")
      return true if File.exists?("azu.yml")

      # Check shard.yml for Azu dependency
      if File.exists?("shard.yml")
        content = File.read("shard.yml")
        return content.includes?("azutoolkit/azu")
      end

      false
    end

    private def detect_project_type : String?
      PROJECT_INDICATORS.each do |type, indicators|
        if indicators.any? { |indicator| Dir.exists?(indicator) || File.exists?(indicator) }
          return type
        end
      end
      nil
    end

    private def detect_database_type : String?
      return nil unless File.exists?("shard.yml")

      content = File.read("shard.yml")

      DATABASE_INDICATORS.each do |db_type, indicators|
        if indicators.any? { |indicator| content.includes?(indicator) }
          return db_type
        end
      end

      nil
    end

    private def get_project_info : NamedTuple(name: String, path: String)
      project_name = if File.exists?("shard.yml")
                       yaml_content = File.read("shard.yml")
                       yaml_data = YAML.parse(yaml_content)
                       yaml_data["name"]?.try(&.as_s) || File.basename(Dir.current)
                     else
                       File.basename(Dir.current)
                     end

      {
        name: project_name,
        path: Dir.current,
      }
    end

    private def confirm_initialization : Bool
      puts
      puts "⚠️  This will add Azu framework components to your existing project.".colorize(:yellow).bold
      puts "   We recommend backing up your project before proceeding."
      puts
      puts "This will:"
      puts "   • Add Azu dependencies to shard.yml"
      puts "   • Create Azu directory structure"
      puts "   • Add configuration files"
      puts "   • Preserve your existing code"
      puts

      loop do
        print "Continue with initialization? [y/N]: ".colorize(:cyan)
        response = gets.try(&.strip.downcase) || ""

        case response
        when "y", "yes"
          return true
        when "", "n", "no"
          return false
        else
          puts "Please enter 'y' for yes or 'n' for no.".colorize(:red)
        end
      end
    end

    private def prompt_project_type(detected : String?) : String
      puts
      puts "🚀 What type of Azu project is this?".colorize(:cyan).bold

      if detected
        puts "   (We detected: #{detected})".colorize(:yellow)
      end
      puts

      project_types = ["web", "api", "cli"]
      project_types.each_with_index do |type, index|
        marker = type == detected ? " (detected)" : ""
        puts "  #{(index + 1).to_s.colorize(:yellow).bold}. #{type.capitalize}#{marker}"
      end
      puts

      loop do
        default_choice = detected ? (project_types.index(detected).not_nil! + 1) : 1
        print "Select project type [1-#{project_types.size}] (#{default_choice}): ".colorize(:cyan)
        input = gets.try(&.strip) || ""

        if input.empty?
          return project_types[default_choice - 1]
        end

        if input.to_i? && (1..project_types.size).includes?(input.to_i)
          return project_types[input.to_i - 1]
        end

        if project_types.includes?(input.downcase)
          return input.downcase
        end

        puts "Invalid selection. Please choose 1-#{project_types.size} or type the project type name.".colorize(:red)
      end
    end

    private def prompt_database_type(detected : String?) : String
      puts
      puts "🗄️  Which database will this project use?".colorize(:cyan).bold

      if detected
        puts "   (We detected: #{detected})".colorize(:yellow)
      end
      puts

      database_types = ["postgresql", "mysql", "sqlite"]
      database_types.each_with_index do |db, index|
        marker = db == detected ? " (detected)" : ""
        description = case db
                      when "postgresql" then "Production-ready with advanced features"
                      when "mysql"      then "Popular choice with good performance"
                      when "sqlite"     then "Lightweight, file-based database"
                      else                   "Database option"
                      end

        puts "  #{(index + 1).to_s.colorize(:yellow).bold}. #{db.capitalize}#{marker}"
        puts "     #{description}"
      end
      puts

      loop do
        default_choice = detected ? (database_types.index(detected).not_nil! + 1) : 1
        print "Select database [1-#{database_types.size}] (#{default_choice}): ".colorize(:cyan)
        input = gets.try(&.strip) || ""

        if input.empty?
          return database_types[default_choice - 1]
        end

        if input.to_i? && (1..database_types.size).includes?(input.to_i)
          return database_types[input.to_i - 1]
        end

        if database_types.includes?(input.downcase)
          return input.downcase
        end

        puts "Invalid selection. Please choose 1-#{database_types.size} or type the database name.".colorize(:red)
      end
    end

    private def initialize_azu(project_name : String, project_type : String, database : String, force : Bool)
      puts
      puts "🔨 Initializing Azu in '#{project_name}'...".colorize(:cyan).bold
      puts "   Type: #{project_type.capitalize}".colorize(:green)
      puts "   Database: #{database.capitalize}".colorize(:green)
      puts

      begin
        # Backup existing shard.yml if it exists
        backup_shard_yml if File.exists?("shard.yml")

        # Create Azu directory structure
        create_azu_structure(project_type)

        # Update or create shard.yml with Azu dependencies
        update_shard_yml(project_name, database)

        # Create configuration files
        create_config_files(project_name, database)

        # Create basic Azu components if they don't exist
        create_basic_components(project_type)

        log.success("✅ Azu initialized successfully!")
        show_post_init_message(project_name, project_type, database)
      rescue ex : Exception
        log.error("Failed to initialize Azu: #{ex.message}")
        restore_backup if File.exists?("shard.yml.backup")
        raise ex
      end
    end

    private def backup_shard_yml
      if File.exists?("shard.yml")
        log.info("Backing up existing shard.yml")
        File.copy("shard.yml", "shard.yml.backup")
      end
    end

    private def restore_backup
      if File.exists?("shard.yml.backup")
        log.info("Restoring original shard.yml")
        File.copy("shard.yml.backup", "shard.yml")
        File.delete("shard.yml.backup")
      end
    end

    private def create_azu_structure(project_type : String)
      log.info("Creating Azu directory structure")

      directories = [
        "src/endpoints",
        "src/pages",
        "src/contracts",
        "src/models",
        "src/initializers",
        "public/assets/css",
        "public/assets/js",
        "public/templates",
        "config",
        "db/migrations",
      ]

      directories.each do |dir|
        ensure_directory(dir)
      end

      # Create placeholder files
      write_placeholder("src/models", "your_models_goes_here.txt", "Place your CQL models in this directory")
      write_placeholder("db/migrations", ".gitkeep", "")
    end

    private def write_placeholder(dir : String, filename : String, content : String)
      path = File.join(dir, filename)
      unless File.exists?(path)
        File.write(path, content)
        log.file_created(path)
      end
    end

    private def update_shard_yml(project_name : String, database : String)
      log.info("Updating shard.yml with Azu dependencies")

      if File.exists?("shard.yml")
        # Parse existing shard.yml and add Azu dependencies
        content = File.read("shard.yml")
        yaml_data = YAML.parse(content)

        # Add Azu dependencies if not present
        dependencies = yaml_data["dependencies"]?.try(&.as_h) || {} of YAML::Any => YAML::Any

        azu_key = YAML::Any.new("azu")
        unless dependencies.has_key?(azu_key)
          azu_github = {YAML::Any.new("github") => YAML::Any.new("azutoolkit/azu")} of YAML::Any => YAML::Any
          dependencies[azu_key] = YAML::Any.new(azu_github)
        end

        cql_key = YAML::Any.new("cql")
        unless dependencies.has_key?(cql_key)
          cql_github = {YAML::Any.new("github") => YAML::Any.new("azutoolkit/cql")} of YAML::Any => YAML::Any
          dependencies[cql_key] = YAML::Any.new(cql_github)
        end

        # Add database-specific dependencies
        case database
        when "postgresql"
          pg_key = YAML::Any.new("pg")
          unless dependencies.has_key?(pg_key)
            pg_github = {YAML::Any.new("github") => YAML::Any.new("will/crystal-pg")} of YAML::Any => YAML::Any
            dependencies[pg_key] = YAML::Any.new(pg_github)
          end
        when "mysql"
          mysql_key = YAML::Any.new("mysql")
          unless dependencies.has_key?(mysql_key)
            mysql_github = {YAML::Any.new("github") => YAML::Any.new("crystal-lang/crystal-mysql")} of YAML::Any => YAML::Any
            dependencies[mysql_key] = YAML::Any.new(mysql_github)
          end
        when "sqlite"
          sqlite_key = YAML::Any.new("sqlite3")
          unless dependencies.has_key?(sqlite_key)
            sqlite_github = {YAML::Any.new("github") => YAML::Any.new("crystal-lang/crystal-sqlite3")} of YAML::Any => YAML::Any
            dependencies[sqlite_key] = YAML::Any.new(sqlite_github)
          end
        end

        # Rebuild YAML structure
        updated_yaml = yaml_data.as_h
        dependencies_key = YAML::Any.new("dependencies")
        updated_yaml[dependencies_key] = YAML::Any.new(dependencies)

        # Write updated shard.yml
        File.write("shard.yml", updated_yaml.to_yaml)
        log.file_modified("shard.yml")
      else
        # Create new shard.yml with basic structure
        create_new_shard_yml(project_name, database)
      end
    end

    private def create_new_shard_yml(project_name : String, database : String)
      log.info("Creating new shard.yml")

      db_dependency = case database
                      when "postgresql"
                        "pg:\n    github: will/crystal-pg"
                      when "mysql"
                        "mysql:\n    github: crystal-lang/crystal-mysql"
                      when "sqlite"
                        "sqlite3:\n    github: crystal-lang/crystal-sqlite3"
                      else
                        "pg:\n    github: will/crystal-pg"
                      end

      shard_content = <<-YAML
      name: #{project_name}
      version: 0.1.0

      authors:
        - #{fetch_git_author} <#{fetch_git_email}>

      crystal: ">= 1.0.0"

      license: MIT

      dependencies:
        azu:
          github: azutoolkit/azu
        cql:
          github: azutoolkit/cql
        #{db_dependency}

      targets:
        #{project_name}:
          main: src/#{project_name}.cr
      YAML

      File.write("shard.yml", shard_content)
      log.file_created("shard.yml")
    end

    private def fetch_git_author : String
      if system("which git >/dev/null 2>&1")
        author = `git config --get user.name`.strip
        return author unless author.empty?
      end
      "Your Name"
    end

    private def fetch_git_email : String
      if system("which git >/dev/null 2>&1")
        email = `git config --get user.email`.strip
        return email unless email.empty?
      end
      "your.email@example.com"
    end

    private def create_config_files(project_name : String, database : String)
      log.info("Creating configuration files")

      # Create database initializer
      unless File.exists?("src/initializers/database.cr")
        db_content = render_database_initializer(database)
        write_file("src/initializers/database.cr", db_content)
      end

      # Create logger initializer
      unless File.exists?("src/initializers/logger.cr")
        logger_content = render_logger_initializer
        write_file("src/initializers/logger.cr", logger_content)
      end
    end

    private def render_database_initializer(database : String) : String
      case database
      when "postgresql"
        <<-CRYSTAL
        require "pg"
        require "cql"

        CQL.setup do |settings|
          settings.database_url = ENV.fetch("DATABASE_URL", "postgresql://localhost/#{File.basename(Dir.current)}_development")
        end
        CRYSTAL
      when "mysql"
        <<-CRYSTAL
        require "mysql"
        require "cql"

        CQL.setup do |settings|
          settings.database_url = ENV.fetch("DATABASE_URL", "mysql://localhost/#{File.basename(Dir.current)}_development")
        end
        CRYSTAL
      when "sqlite"
        <<-CRYSTAL
        require "sqlite3"
        require "cql"

        CQL.setup do |settings|
          settings.database_url = ENV.fetch("DATABASE_URL", "sqlite3://./db/#{File.basename(Dir.current)}_development.db")
        end
        CRYSTAL
      else
        ""
      end
    end

    private def render_logger_initializer : String
      <<-CRYSTAL
      require "log"

      Log.setup do |config|
        backend = Log::IOBackend.new
        config.bind "*", :info, backend
      end
      CRYSTAL
    end

    private def create_basic_components(project_type : String)
      log.info("Creating basic Azu components")

      # Create a welcome endpoint if none exists
      unless Dir.exists?("src/endpoints/welcome") || Dir.glob("src/endpoints/*").any?
        create_welcome_endpoint
      end

      # Create a welcome page if none exists
      unless Dir.exists?("src/pages/welcome") || Dir.glob("src/pages/*").any?
        create_welcome_page
      end
    end

    private def create_welcome_endpoint
      ensure_directory("src/endpoints/welcome")
      content = <<-CRYSTAL
      require "azu"

      class Welcome::IndexEndpoint < Azu::Endpoint
        def call
          render Welcome::IndexPage.new
        end
      end
      CRYSTAL

      write_file("src/endpoints/welcome/index_endpoint.cr", content)
    end

    private def create_welcome_page
      ensure_directory("src/pages/welcome")
      content = <<-CRYSTAL
      require "azu"

      class Welcome::IndexPage < Azu::Page
        def render
          html do
            head do
              title "Welcome to Azu!"
            end
            body do
              h1 "Welcome to Azu!"
              p "Your Crystal web application is ready to go."
            end
          end
        end
      end
      CRYSTAL

      write_file("src/pages/welcome/index_page.cr", content)
    end

    private def show_post_init_message(project_name : String, project_type : String, database : String)
      puts
      puts "🎉 Azu has been initialized in your project!".colorize(:green).bold
      puts
      puts "📁 Added Azu Structure:".colorize(:cyan).bold
      puts "   📂 src/endpoints/    # HTTP endpoints (controllers)"
      puts "   📂 src/pages/        # Page components (views)"
      puts "   📂 src/contracts/    # Request/response contracts"
      puts "   📂 src/models/       # Database models"
      puts "   📂 src/initializers/ # Application initializers"
      puts "   📂 config/           # Configuration files"
      puts "   📂 db/migrations/    # Database migrations"
      puts
      puts "🚀 Next Steps:".colorize(:yellow).bold
      puts "   1. shards install              # Install dependencies"
      puts "   2. azu db:create               # Create database"
      puts "   3. azu serve                   # Start development server"
      puts
      puts "💡 Useful Commands:".colorize(:cyan).bold
      puts "   azu generate controller users  # Generate a controller"
      puts "   azu scaffold post title:string # Generate complete resource"
      puts "   azu help                       # Show all available commands"
      puts
      puts "📖 Documentation:".colorize(:blue).bold
      puts "   • Azu Toolkit: https://azutopia.gitbook.io/azu/"
      puts "   • CQL ORM: https://github.com/azutoolkit/cql"
      puts
      puts "🔄 If you had a backup of shard.yml, it's saved as shard.yml.backup"
      puts
      puts "Happy coding! 🎉".colorize(:magenta).bold
    end

    def show_command_specific_help
      puts "Options:"
      puts "  --type TYPE         Project type (web, api, cli)"
      puts "  --database DB       Database type (postgresql, mysql, sqlite)"
      puts "  --force             Force reinitialize even if already initialized"
      puts "  --skip-interactive  Skip interactive prompts"
      puts "  -s                  Alias for --skip-interactive"
      puts
      puts "Examples:"
      puts "  azu init                              # Interactive setup"
      puts "  azu init --type api --database mysql # Specific options"
      puts "  azu init --force                     # Force reinitialize"
      puts "  azu init -s                          # Skip interactive prompts"
    end
  end
end
