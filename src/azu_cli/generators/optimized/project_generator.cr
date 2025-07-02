require "../core/abstract_generator"

module AzuCLI::Generator
  # Optimized Project Generator following SOLID principles
  # Uses configuration-driven approach to generate complete Azu projects
  class ProjectGenerator < Core::AbstractGenerator
    property project_type : String
    property database : String
    property copy_assets : Bool
    property copy_templates : Bool

    def initialize(name : String, project_name : String, options : Core::GeneratorOptions)
      @project_type = options.custom_options["type"]? || "web"
      @database = options.custom_options["database"]? || "postgresql"
      @copy_assets = should_copy_assets?
      @copy_templates = should_copy_templates?
      super(name, project_name, options.force, options.skip_tests)
    end

    # Concrete implementation of abstract method
    def generator_type : String
      "project"
    end

    # Override validation to include project-specific validation
    def validate_input! : Nil
      super
      validate_project_type
      validate_database_type
    end

    # Concrete implementation of abstract method
    def generate_files : Nil
      puts "🚀 Creating #{@project_type} project '#{name}' with #{@database} database...".colorize(:cyan).bold
      puts

      create_project_structure
      generate_core_files
      generate_project_type_files
      copy_static_assets if @copy_assets
      copy_template_files if @copy_templates
      generate_placeholder_files
    end

    # Override to create comprehensive project directory structure
    def create_directories : Nil
      puts "📁 Creating project directories...".colorize(:blue)

      # Get all directories from configuration
      directories = config.get_hash("directories")
      directories.each do |dir_key, dir_path|
        expanded_path = expand_template_path(dir_path)
        file_strategy.create_directory(File.join(name, expanded_path))
      end

      # Create additional directories based on project type
      create_project_type_directories
    end

    # Override to skip individual file tests (project handles its own testing setup)
    def generate_tests : Nil
      # Project generator creates its own spec structure
      puts "✅ Test structure created as part of project".colorize(:green)
    end

    # Validate project type
    private def validate_project_type : Nil
      valid_types = config.get_hash("project_types").keys
      unless valid_types.includes?(@project_type)
        raise ArgumentError.new("Invalid project type: #{@project_type}. Valid types: #{valid_types.join(", ")}")
      end
    end

    # Validate database type
    private def validate_database_type : Nil
      valid_databases = config.get_hash("databases").keys
      unless valid_databases.includes?(@database)
        raise ArgumentError.new("Invalid database: #{@database}. Valid databases: #{valid_databases.join(", ")}")
      end
    end

    # Determine if assets should be copied based on project type
    private def should_copy_assets? : Bool
      project_type_config = config.get_hash("project_types.#{@project_type}")
      project_type_config["copy_assets"]? == "true"
    end

    # Determine if templates should be copied based on project type
    private def should_copy_templates? : Bool
      project_type_config = config.get_hash("project_types.#{@project_type}")
      project_type_config["copy_templates"]? == "true"
    end

    # Create basic project structure
    private def create_project_structure : Nil
      puts "🏗️ Setting up project structure...".colorize(:yellow)

      # Create root project directory
      file_strategy.create_directory(name)

      # Create directories
      create_directories
    end

    # Generate core project files that all project types need
    private def generate_core_files : Nil
      puts "📝 Generating core files...".colorize(:yellow)

      core_templates = ["main", "shard", "readme", "spec_helper", "spec_main"]

      core_templates.each do |template_key|
        if template_name = config.get("templates.#{template_key}")
          output_path = get_template_output_path(template_key)
          if output_path
            generate_project_file(template_name, output_path, template_key)
          end
        end
      end
    end

    # Generate files specific to the project type
    private def generate_project_type_files : Nil
      puts "🎯 Generating #{@project_type} specific files...".colorize(:yellow)

      project_type_config = config.get_hash("project_types.#{@project_type}")
      templates = project_type_config["templates"]?.try(&.as_a?) || [] of YAML::Any

      templates.each do |template_yaml|
        template_key = template_yaml.as_s
        if template_name = config.get("templates.#{template_key}")
          output_path = get_template_output_path(template_key)
          if output_path
            generate_project_file(template_name, output_path, template_key)
          end
        end
      end
    end

    # Generate individual project file from template
    private def generate_project_file(template_name : String, output_path : String, template_key : String) : Nil
      full_output_path = File.join(name, output_path)
      variables = generate_project_variables

      # Add template-specific variables
      case template_key
      when "shard"
        variables["dependencies"] = generate_shard_dependencies
      when "server"
        variables["routes"] = generate_default_routes
      when "database_init"
        variables["database_config"] = generate_database_config
      end

      create_file_from_template(
        template_name,
        full_output_path,
        variables,
        template_key
      )
    end

    # Generate template variables for project files
    private def generate_project_variables : Hash(String, String)
      database_config = config.get_hash("databases.#{@database}")

      default_template_variables.merge({
        "project_type"       => @project_type,
        "database"           => @database,
        "database_url"       => expand_template_string(database_config["url"]? || ""),
        "database_driver"    => database_config["driver"]? || "",
        "database_adapter"   => database_config["adapter"]? || "",
        "project_features"   => generate_project_features,
        "timestamp"          => Time.utc.to_rfc3339,
        "crystal_version"    => "1.10.0",
        "azu_version"        => "~> 1.0.0",
      })
    end

    # Get output path for template
    private def get_template_output_path(template_key : String) : String?
      template_paths = config.get_hash("template_output_paths")
      path_template = template_paths[template_key]?
      return nil unless path_template

      expand_template_string(path_template)
    end

    # Expand template variables in strings
    private def expand_template_string(template : String) : String
      template.gsub("{{project}}", snake_case_name)
             .gsub("{{Project}}", class_name)
             .gsub("{{PROJECT}}", snake_case_name.upcase)
    end

    # Expand template variables in paths
    private def expand_template_path(path : String) : String
      expand_template_string(path)
    end

    # Generate project features list
    private def generate_project_features : String
      project_type_config = config.get_hash("project_types.#{@project_type}")
      features = project_type_config["features"]?.try(&.as_a?) || [] of YAML::Any

      feature_list = features.map(&.as_s).join(", ")
      "Features: #{feature_list}"
    end

    # Generate shard dependencies
    private def generate_shard_dependencies : String
      dependencies = [] of String

      # Base dependencies for all projects
      dependencies << "azu:\n    github: azutoolkit/azu"
      dependencies << "cql:\n    github: azutoolkit/cql"
      dependencies << "cql:\n    github: azutoolkit/topia"

      # Database-specific dependencies
      case @database
      when "postgresql"
        dependencies << "pg:\n    github: will/crystal-pg"
      when "mysql"
        dependencies << "mysql:\n    github: crystal-lang/crystal-mysql"
      when "sqlite"
        dependencies << "sqlite3:\n    github: crystal-lang/crystal-sqlite3"
      end

      # Project type specific dependencies
      case @project_type
      when "web"
        dependencies << "jinja:\n    github: straight-shoota/jinja.cr"
      when "cli"
        dependencies << "topia:\n    github: azutoolkit/topia"
      end

      dependencies.join("\n  ")
    end

    # Generate default routes for the project
    private def generate_default_routes : String
      case @project_type
      when "web", "api"
        <<-CRYSTAL
        # Welcome route
        get "/", Welcome::IndexEndpoint
        CRYSTAL
      else
        "# Add your routes here"
      end
    end

    # Generate database configuration
    private def generate_database_config : String
      database_config = config.get_hash("databases.#{@database}")
      database_url = expand_template_string(database_config["url"]? || "")

      <<-CRYSTAL
      CQL.setup do |settings|
        settings.database_url = ENV["DATABASE_URL"]? || "#{database_url}"
        settings.adapter = "#{database_config["adapter"]? || @database}"
      end
      CRYSTAL
    end

    # Copy static assets if needed
    private def copy_static_assets : Nil
      return unless @copy_assets

      puts "📦 Copying static assets...".colorize(:yellow)

      assets_source = "src/azu_cli/templates/project/public"
      assets_dest = File.join(name, "public")

      if Dir.exists?(assets_source)
        copy_directory_recursive(assets_source, assets_dest)
      end
    end

    # Copy template files if needed
    private def copy_template_files : Nil
      return unless @copy_templates

      puts "📄 Copying template files...".colorize(:yellow)

      templates_source = "src/azu_cli/templates/project/public/templates"
      templates_dest = File.join(name, "public/templates")

      if Dir.exists?(templates_source)
        copy_directory_recursive(templates_source, templates_dest)
      end
    end

    # Generate placeholder files for empty directories
    private def generate_placeholder_files : Nil
      puts "📋 Creating placeholder files...".colorize(:yellow)

      # Create .gitkeep files for placeholder directories
      placeholder_dirs = config.get_array("placeholder_directories")
      placeholder_dirs.each do |dir|
        expanded_dir = expand_template_path(dir)
        placeholder_path = File.join(name, expanded_dir, ".gitkeep")
        file_strategy.create_file(placeholder_path, "", {"description" => "placeholder"})
      end

      # Create special placeholder files
      placeholder_files = config.get_hash("placeholder_files")
      placeholder_files.each do |file_key, file_config|
        if file_config.is_a?(Hash)
          file_path = file_config["path"]?.try(&.as_s)
          file_content = file_config["content"]?.try(&.as_s) || ""

          if file_path
            expanded_path = expand_template_path(file_path)
            full_path = File.join(name, expanded_path)
            file_strategy.create_file(full_path, file_content, {"description" => file_key})
          end
        end
      end
    end

    # Create project type specific directories
    private def create_project_type_directories : Nil
      case @project_type
      when "web"
        # Web projects need additional view directories
        file_strategy.create_directory(File.join(name, "src/views"))
        file_strategy.create_directory(File.join(name, "src/views/layouts"))
      when "cli"
        # CLI projects need commands directory
        file_strategy.create_directory(File.join(name, "src/commands"))
      end
    end

    # Copy directory recursively
    private def copy_directory_recursive(source : String, dest : String) : Nil
      return unless Dir.exists?(source)

      file_strategy.create_directory(dest)

      Dir.each_child(source) do |child|
        source_path = File.join(source, child)
        dest_path = File.join(dest, child)

        if Dir.exists?(source_path)
          copy_directory_recursive(source_path, dest_path)
        else
          content = File.read(source_path)
          file_strategy.create_file(dest_path, content, {"description" => "asset"})
        end
      end
    end

    # Override success message for project generation
    def success_message : String
      "🎉 Project '#{name}' created successfully!"
    end

    # Override to show project-specific next steps
    def post_generation_tasks : Nil
      show_project_completion_info
      show_next_steps
    end

    # Show project completion information
    private def show_project_completion_info
      puts
      puts "✅ Project Generation Complete!".colorize(:green).bold
      puts
      puts "📊 Project Details:".colorize(:cyan).bold
      puts "   Name: #{name}"
      puts "   Type: #{@project_type.capitalize}"
      puts "   Database: #{@database.capitalize}"

      project_type_config = config.get_hash("project_types.#{@project_type}")
      if description = project_type_config["description"]?
        puts "   Description: #{description}"
      end

      if features = project_type_config["features"]?.try(&.as_a?)
        feature_list = features.map(&.as_s).join(", ")
        puts "   Features: #{feature_list}"
      end
      puts
    end

    # Show next steps
    private def show_next_steps
      puts "🚀 Next Steps:".colorize(:yellow).bold

      step_number = 1

      puts "  #{step_number}. Navigate to your project:"
      puts "     cd #{name}"
      step_number += 1

      puts "  #{step_number}. Install dependencies:"
      puts "     shards install"
      step_number += 1

      # Database setup steps
      unless @project_type == "cli"
        puts "  #{step_number}. Set up your database:"
        puts "     # Update database configuration in src/initializers/database.cr"
        puts "     # Create database: azu db:create"
        puts "     # Run migrations: azu db:migrate"
        step_number += 1
      end

      # Project type specific steps
      case @project_type
      when "web"
        puts "  #{step_number}. Start the development server:"
        puts "     azu serve"
        step_number += 1
        puts "  #{step_number}. Visit your application:"
        puts "     http://localhost:3000"
      when "api"
        puts "  #{step_number}. Start the API server:"
        puts "     azu serve"
        step_number += 1
        puts "  #{step_number}. Test your API:"
        puts "     curl http://localhost:3000"
      when "cli"
        puts "  #{step_number}. Build your CLI:"
        puts "     crystal build src/#{snake_case_name}.cr"
        step_number += 1
        puts "  #{step_number}. Run your CLI:"
        puts "     ./#{snake_case_name} --help"
      end

      puts
      puts "💡 Additional Commands:".colorize(:blue).bold
      puts "   Generate models:     azu generate model User name:string email:string"
      puts "   Generate endpoints:  azu generate endpoint Users"
      puts "   Generate services:   azu generate service UserService"
      puts "   Run tests:          crystal spec"
      puts

      puts "📚 Learn more: https://azutopia.gitbook.io/azu/getting-started".colorize(:cyan)
      puts "💬 Get help: https://discord.gg/azu".colorize(:cyan)
    end
  end
end
