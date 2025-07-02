require "../core/abstract_generator"
require "file_utils"

module AzuCLI::Generator
  # Optimized Project Generator following SOLID principles
  # Uses configuration-driven approach with Template Method pattern
  class ProjectGenerator < Core::AbstractGenerator
    property project_type : String
    property database : String
    property force_create : Bool
    property skip_interactive : Bool
    property skip_git : Bool
    property skip_deps : Bool

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @project_type = options.custom_options["type"]? || "web"
      @database = options.custom_options["database"]? || "postgresql"
      @force_create = options.force
      @skip_interactive = options.custom_options["skip-interactive"]? == "true"
      @skip_git = options.custom_options["skip-git"]? == "true"
      @skip_deps = options.custom_options["skip-deps"]? == "true"
      super(name, project_name, options.force, options.skip_tests)
    end

    def generator_type : String
      "project"
    end

    def generate_files : Nil
      puts "🔨 Creating Azu project '#{name}'...".colorize(:cyan).bold
      puts "   Type: #{get_project_type_info[:name]}".colorize(:green)
      puts "   Database: #{database.capitalize}".colorize(:green)
      puts

      # Generate project files within the created directory structure
      Dir.cd(name) do
        generate_project_structure
        copy_static_assets if should_copy_assets?
        copy_template_files if should_copy_templates?
      end
    end

    def create_directories : Nil
      # Remove existing directory if force is enabled
      if Dir.exists?(name) && force_create
        puts "Removing existing directory '#{name}'".colorize(:yellow)
        FileUtils.rm_rf(name)
      end

      # Create the main project directory
      Dir.mkdir_p(name)

      # Create all subdirectories within the project
      Dir.cd(name) do
        directories_config = config.get_hash("directories")

        directories_config.each do |dir_type, dir_path|
          next if dir_path == "." # Skip root directory
          file_strategy.create_directory(dir_path)
        end

        # Create placeholder files for empty directories
        create_placeholder_files
      end
    end

    def post_generation_tasks : Nil
      # Project-specific post-generation tasks
      Dir.cd(name) do
        setup_git_repository unless skip_git
        install_dependencies unless skip_deps
        show_success_message
      end
    end

    def validate_input! : Nil
      super

      # Additional validation for project generation
      unless get_project_types.has_key?(project_type)
        raise ArgumentError.new("Invalid project type: #{project_type}. Available: #{get_project_types.keys.join(", ")}")
      end

      unless get_databases.has_key?(database)
        raise ArgumentError.new("Invalid database: #{database}. Available: #{get_databases.keys.join(", ")}")
      end

      if Dir.exists?(name) && !force_create
        raise ArgumentError.new("Directory '#{name}' already exists. Use --force to overwrite.")
      end
    end

    private def generate_project_structure : Nil
      project_type_config = get_project_type_config
      template_names = project_type_config["templates"]?.try(&.as_a.map(&.as_s)) || [] of String

      template_names.each do |template_name|
        generate_template_file(template_name)
      end
    end

    private def generate_template_file(template_name : String) : Nil
      template_config = config.get("templates.#{template_name}")
      return unless template_config

      template_path = template_config
      output_path = resolve_template_output_path(template_name, template_path)

      # Ensure output directory exists
      output_dir = File.dirname(output_path)
      Dir.mkdir_p(output_dir) unless output_dir == "."

      template_variables = generate_template_variables

      # Adjust template path for project templates
      actual_template_path = File.join(__DIR__, "..", "templates", template_path)

      create_file_from_template(
        actual_template_path,
        output_path,
        template_variables,
        "#{template_name} file"
      )
    end

    def resolve_template_output_path(template_name : String, template_path : String) : String
      # Get template output paths from configuration
      template_output_paths = config.get_nested("template_output_paths")

      if template_output_paths && template_output_paths.as_h.has_key?(template_name)
        output_path = template_output_paths[template_name].as_s
        # Replace {{project}} placeholder with actual project name
        output_path.gsub("{{project}}", name)
      else
        # Fallback: derive from template path
        template_path.gsub("project/", "").gsub("{{project}}", name).chomp(".ecr")
      end
    end

    def generate_template_variables : Hash(String, String)
      database_config = get_database_config

      database_url = database_config["url"]?.try(&.as_s) || "postgresql://localhost/#{name}_development"
      db_driver = database_config["driver"]?.try(&.as_s) || "pg"
      db_adapter = database_config["adapter"]?.try(&.as_s) || "postgresql"

      default_template_variables.merge({
        "project_type" => project_type,
        "database"     => database,
        "database_url" => database_url.gsub("{{project}}", name),
        "db_driver"    => db_driver,
        "db_adapter"   => db_adapter,
        "author"       => ENV["USER"]? || "Developer",
        "email"        => ENV["EMAIL"]? || "developer@example.com",
        "year"         => Time.utc.year.to_s,
      })
    end

    private def copy_static_assets : Nil
      puts "📦 Copying static assets...".colorize(:yellow)

      assets_source = File.join(__DIR__, "..", "templates", "project", "public")
      assets_dest = "public"

      if Dir.exists?(assets_source)
        copy_directory_recursive(assets_source, assets_dest)
      end
    end

    private def copy_template_files : Nil
      puts "🎨 Copying template files...".colorize(:yellow)

      templates_source = File.join(__DIR__, "..", "templates", "project", "public", "templates")
      templates_dest = "public/templates"

      if Dir.exists?(templates_source)
        copy_directory_recursive(templates_source, templates_dest)
      end
    end

    private def copy_directory_recursive(source : String, dest : String) : Nil
      Dir.mkdir_p(dest)

      Dir.each_child(source) do |item|
        source_path = File.join(source, item)
        dest_path = File.join(dest, item)

        if Dir.exists?(source_path)
          copy_directory_recursive(source_path, dest_path)
        else
          File.copy(source_path, dest_path)
        end
      end
    end

    private def create_placeholder_files : Nil
      # Create placeholder files for directories that should exist but might be empty
      placeholder_dirs = get_placeholder_directories

      placeholder_dirs.each do |dir|
        next unless Dir.exists?(dir)
        placeholder_file = File.join(dir, ".gitkeep")
        File.write(placeholder_file, "# This file keeps the directory in git\n") unless File.exists?(placeholder_file)
      end

      # Create special placeholder files
      create_special_placeholder_files
    end

    private def setup_git_repository : Nil
      if system("git --version > /dev/null 2>&1")
        puts "🔄 Initializing git repository...".colorize(:yellow)
        system("git init > /dev/null 2>&1")
        system("git add . > /dev/null 2>&1")
        system("git commit -m 'Initial commit' > /dev/null 2>&1")
      else
        puts "⚠️  Git not found. Skipping git initialization".colorize(:yellow)
      end
    end

    private def install_dependencies : Nil
      if File.exists?("shard.yml")
        if system("shards --version > /dev/null 2>&1")
          puts "📦 Installing dependencies...".colorize(:yellow)
          system("shards install")
          puts "✅ Dependencies installed".colorize(:green)
        else
          puts "⚠️  Shards not found. Please install dependencies manually with 'shards install'".colorize(:yellow)
        end
      end
    end

    private def show_success_message : Nil
      project_type_info = get_project_type_info

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

      if should_copy_assets?
        puts "   📂 public/           # Static assets"
      end

      puts "   📂 spec/             # Test files"
      puts "   📄 shard.yml         # Dependencies configuration"
      puts

      puts "🚀 Next Steps:".colorize(:yellow).bold
      puts "   1. cd #{name}"
      puts "   2. azu serve           # Start development server"

      if project_type != "cli"
        puts "   3. azu db:create       # Create database (if using #{database})"
        puts "   4. azu db:migrate      # Run migrations"
      end

      puts
      puts "💡 Useful Commands:".colorize(:cyan).bold
      puts "   azu generate model User          # Generate a model"
      puts "   azu generate endpoint users      # Generate an endpoint"
      puts "   azu scaffold post title:string   # Generate complete resource"
      puts "   azu help                         # Show all available commands"
      puts
      puts "📖 Documentation:".colorize(:blue).bold
      puts "   • Azu Toolkit: https://azutopia.gitbook.io/azu/"
      puts "   • CQL ORM: https://github.com/azutoolkit/cql"
      puts
      puts "Happy coding! 🎉".colorize(:magenta).bold
    end

    # Configuration helper methods
    private def get_project_types
      if project_types = config.get_nested("project_types")
        project_types.as_h.transform_keys(&.as_s).transform_values(&.as_h)
      else
        {} of String => Hash(YAML::Any, YAML::Any)
      end
    end

    private def get_project_type_config
      project_types = get_project_types
      if project_types.has_key?(project_type)
        project_types[project_type]
      else
        {} of YAML::Any => YAML::Any
      end
    end

    def get_project_type_info
      project_type_config = get_project_type_config
      {
        name:        project_type_config["name"]?.try(&.as_s) || "Unknown",
        description: project_type_config["description"]?.try(&.as_s) || "No description",
        features:    project_type_config["features"]?.try(&.as_a.map(&.as_s)) || [] of String,
      }
    end

    private def get_databases
      if databases = config.get_nested("databases")
        databases.as_h.transform_keys(&.as_s).transform_values(&.as_h)
      else
        {} of String => Hash(YAML::Any, YAML::Any)
      end
    end

    private def get_database_config
      databases = get_databases
      if databases.has_key?(database)
        databases[database]
      else
        {} of YAML::Any => YAML::Any
      end
    end

    def should_copy_assets? : Bool
      project_type_config = get_project_type_config
      if copy_assets = project_type_config["copy_assets"]?
        copy_assets.as_bool || false
      else
        false
      end
    end

    private def should_copy_templates? : Bool
      project_type_config = get_project_type_config
      if copy_templates = project_type_config["copy_templates"]?
        copy_templates.as_bool || false
      else
        false
      end
    end

    private def get_placeholder_directories : Array(String)
      placeholder_dirs = config.get_nested("placeholder_directories")
      if placeholder_dirs && placeholder_dirs.as_a?
        placeholder_dirs.as_a.map(&.as_s)
      else
        # Fallback to empty array if not configured
        [] of String
      end
    end

    private def create_special_placeholder_files : Nil
      placeholder_files = config.get_nested("placeholder_files")
      return unless placeholder_files

      placeholder_files.as_h.each do |key, file_config|
        file_path = file_config["path"]?.try(&.as_s)
        file_content = file_config["content"]?.try(&.as_s)

        next unless file_path && file_content

        # Replace {{project}} placeholder with actual project name
        actual_path = file_path.gsub("{{project}}", name)

        unless File.exists?(actual_path)
          File.write(actual_path, file_content)
        end
      end
    end
  end
end
