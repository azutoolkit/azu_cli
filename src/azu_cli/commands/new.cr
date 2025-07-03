require "./base"
require "option_parser"
require "readline"
require "../generators/project"

module AzuCLI
  module Commands
    # New command for creating new Azu projects
    class New < Base
      # Configuration properties
      property project_name : String = ""
      property module_name : String = ""
      property author : String = ""
      property email : String = ""
      property license : String = "MIT"
      property project_type : String = "web"
      property database : String = "postgresql"
      property test_framework : String = "spec"
      property ci_setup : String = "GitHub Actions"
      property docker_support : Bool = false
      property git_init : Bool = true
      property include_example : Bool = true
      property non_interactive : Bool = false

      def initialize
        super("new", "Create a new Azu project")
      end

      def execute : Result
        parse_arguments

        # If project name wasn't provided as argument or flag, this is an error
        if @project_name.empty? && get_arg(0).nil?
          return error("Project name is required. Usage: azu new <project-name> [options]")
        end

        # Set project name from argument if not set by flag
        @project_name = get_arg(0).not_nil! if @project_name.empty?

        # Validate project name
        unless valid_project_name?(@project_name)
          return error("Invalid project name '#{@project_name}'. Use only letters, numbers, underscores, and hyphens.")
        end

        # Check if directory already exists
        if Dir.exists?(@project_name)
          return error("Directory '#{@project_name}' already exists. Choose a different name.")
        end

        # Show welcome message
        Logger.announce("Creating new Azu project: #{@project_name}")

        # Gather configuration (interactive or from flags)
        gather_configuration

        # Show configuration summary
        show_configuration_summary

        # Generate the project
        generate_project

        # Post-generation tasks
        post_generation_tasks

        # Show success message
        show_success_message

        success("Project '#{@project_name}' created successfully")
      end

      private def parse_arguments
        OptionParser.parse(get_args) do |parser|
          parser.banner = "Usage: azu new <project-name> [options]"

          parser.on("--name NAME", "Project name") { |name| @project_name = name }
          parser.on("--module MODULE", "Module name (PascalCase)") { |mod| @module_name = mod }
          parser.on("--author AUTHOR", "Author name") { |author| @author = author }
          parser.on("--email EMAIL", "Author email") { |email| @email = email }
          parser.on("--license LICENSE", "License (MIT, Apache-2.0, GPL-3.0, etc.)") { |license| @license = license }
          parser.on("--type TYPE", "Project type (web, api, cli)") { |type| @project_type = type }
          parser.on("--db DATABASE", "Database adapter (postgresql, mysql, sqlite)") { |db| @database = db }
          parser.on("--test TEST", "Test framework (spec, minitest)") { |test| @test_framework = test }
          parser.on("--ci CI", "CI setup (\"GitHub Actions\", \"GitLab CI\", \"None\")") { |ci| @ci_setup = ci }
          parser.on("--docker", "Include Docker support") { @docker_support = true }
          parser.on("--no-docker", "Skip Docker support") { @docker_support = false }
          parser.on("--git", "Initialize Git repository") { @git_init = true }
          parser.on("--no-git", "Skip Git initialization") { @git_init = false }
          parser.on("--example", "Include example code") { @include_example = true }
          parser.on("--no-example", "Skip example code") { @include_example = false }
          parser.on("--yes", "Non-interactive mode (use defaults)") { @non_interactive = true }
          parser.on("--help", "Show help") {
            puts parser
            exit(0)
          }
        end
      end

      private def gather_configuration
        if @non_interactive
          # Use defaults or provided flags
          set_defaults
        else
          # Interactive prompts
          interactive_configuration
        end

        # Set module name if not provided
        if @module_name.empty?
          @module_name = @project_name.split(/[-_]/).map(&.capitalize).join
        end
      end

      private def set_defaults
        @author = get_git_config("user.name") || "Your Name" if @author.empty?
        @email = get_git_config("user.email") || "your.email@example.com" if @email.empty?
      end

      private def interactive_configuration
        puts
        Logger.info("Please provide the following information:")
        puts

        # Project name (already set)
        Logger.step(1, 9, "Project name: #{@project_name}")

        # Module name
        if @module_name.empty?
          default_module = @project_name.split(/[-_]/).map(&.capitalize).join
          @module_name = prompt_with_default("Module name (PascalCase)", default_module)
        end
        Logger.step(2, 9, "Module name: #{@module_name}")

        # Author
        if @author.empty?
          default_author = get_git_config("user.name") || ""
          @author = prompt_with_default("Author name", default_author)
        end
        Logger.step(3, 9, "Author: #{@author}")

        # Email
        if @email.empty?
          default_email = get_git_config("user.email") || ""
          @email = prompt_with_default("Author email", default_email)
        end
        Logger.step(4, 9, "Email: #{@email}")

        # License
        @license = prompt_choice("License", ["MIT", "Apache-2.0", "GPL-3.0", "BSD-3-Clause", "ISC"], @license)
        Logger.step(5, 9, "License: #{@license}")

        # Project type
        @project_type = prompt_choice("Project type", ["web", "api", "cli"], @project_type)
        Logger.step(6, 9, "Project type: #{@project_type}")

        # Database
        @database = prompt_choice("Database adapter", ["postgresql", "mysql", "sqlite"], @database)
        Logger.step(7, 9, "Database: #{@database}")

        # Test framework
        @test_framework = prompt_choice("Test framework", ["spec", "minitest"], @test_framework)

        # CI setup
        @ci_setup = prompt_choice("CI setup", ["GitHub Actions", "GitLab CI", "None"], @ci_setup)

        # Boolean options
        @docker_support = prompt_boolean("Include Docker support?", @docker_support)
        @git_init = prompt_boolean("Initialize Git repository?", @git_init)
        @include_example = prompt_boolean("Include example #{get_example_description}?", @include_example)

        Logger.step(8, 9, "Additional options configured")
        Logger.step(9, 9, "Configuration complete")
      end

      private def prompt_with_default(question : String, default : String) : String
        prompt_text = default.empty? ? "#{question}: " : "#{question} [#{default}]: "
        Logger.prompt(prompt_text)

        response = Readline.readline("", false)
        return default if response.nil? || response.strip.empty?
        response.strip
      end

      private def prompt_choice(question : String, choices : Array(String), default : String) : String
        puts
        Logger.prompt("#{question}:")
        choices.each_with_index do |choice, index|
          marker = choice == default ? "●" : "○"
          puts "  #{marker} #{choice}"
        end

        print "Select (#{choices.join("/")}) [#{default}]: "
        response = Readline.readline("", false)

        return default if response.nil? || response.strip.empty?

        selected = response.strip.downcase
        choice = choices.find { |c| c.downcase.starts_with?(selected) }
        choice || default
      end

      private def prompt_boolean(question : String, default : Bool) : Bool
        default_text = default ? "Y/n" : "y/N"
        Logger.prompt("#{question} (#{default_text}): ")

        response = Readline.readline("", false)
        return default if response.nil? || response.strip.empty?

        response = response.strip.downcase
        case response
        when "y", "yes", "true", "1"
          true
        when "n", "no", "false", "0"
          false
        else
          default
        end
      end

      private def get_example_description : String
        case @project_type
        when "web"
          "endpoint"
        when "api"
          "API endpoint"
        when "cli"
          "command"
        else
          "code"
        end
      end

      private def get_git_config(key : String) : String?
        output = `git config --global #{key} 2>/dev/null`.strip
        output.empty? ? nil : output
      rescue
        nil
      end

      private def valid_project_name?(name : String) : Bool
        return false if name.empty?
        return false if name.starts_with?("-") || name.ends_with?("-")
        return false if name.starts_with?("_") || name.ends_with?("_")

        name.matches?(/^[a-zA-Z0-9_-]+$/)
      end

      private def show_configuration_summary
        puts
        Logger.announce("Project Configuration Summary")

        puts "  Project name:     #{@project_name}"
        puts "  Module name:      #{@module_name}"
        puts "  Author:           #{@author} <#{@email}>"
        puts "  License:          #{@license}"
        puts "  Project type:     #{@project_type}"
        puts "  Database:         #{@database}"
        puts "  Test framework:   #{@test_framework}"
        puts "  CI setup:         #{@ci_setup}"
        puts "  Docker support:   #{@docker_support ? "Yes" : "No"}"
        puts "  Git repository:   #{@git_init ? "Yes" : "No"}"
        puts "  Include example:  #{@include_example ? "Yes" : "No"}"
        puts
      end

      private def generate_project
        Logger.progress_start("Generating project files")

        begin
          # Create the generator
          generator = Generate::Project.new(
            project: @project_name,
            module_name: @module_name,
            author: @author,
            email: @email,
            license: @license,
            project_type: @project_type,
            database: @database,
            test_framework: @test_framework,
            ci_setup: @ci_setup,
            docker_support: @docker_support,
            git_init: @git_init,
            include_example: @include_example
          )

          # Generate the project in the target directory
          generator.render(@project_name, force: false, interactive: false, list: false, color: true)

          Logger.progress_done(true)
        rescue ex : Exception
          Logger.progress_done(false)
          Logger.exception(ex, "Failed to generate project files")
          raise ex
        end
      end

      private def post_generation_tasks
        Dir.cd(@project_name) do
          # Initialize Git repository
          if @git_init
            Logger.progress_start("Initializing Git repository")
            if system("git init > /dev/null 2>&1")
              system("git add . > /dev/null 2>&1")
              system("git commit -m \"Initial commit\" > /dev/null 2>&1")
              Logger.progress_done(true)
            else
              Logger.progress_done(false)
            end
          end

          # Install dependencies
          Logger.progress_start("Installing dependencies")
          if system("shards install > /dev/null 2>&1")
            Logger.progress_done(true)
          else
            Logger.progress_done(false)
            Logger.warn("Failed to install dependencies. Run 'shards install' manually.")
          end

          # Verify project compiles
          Logger.progress_start("Verifying project compiles")
          if system("crystal build src/#{main_filename} --no-codegen > /dev/null 2>&1")
            Logger.progress_done(true)
          else
            Logger.progress_done(false)
            Logger.warn("Project may have compilation issues. Check with 'crystal build'.")
          end
        end
      end

      private def main_filename : String
        case @project_type
        when "web"
          "server.cr"
        when "api"
          "api.cr"
        when "cli"
          "#{@project_name}.cr"
        else
          "server.cr"
        end
      end

      private def show_success_message
        puts
        Logger.announce("🚀 Project '#{@project_name}' created successfully!")

        puts "Next steps:"
        puts "  1. cd #{@project_name}"
        puts "  2. Configure your database in config/database.yml"

        case @project_type
        when "web"
          puts "  3. Run: azu serve"
          puts "  4. Visit: http://localhost:3000"
        when "api"
          puts "  3. Run: azu serve"
          puts "  4. Test: curl http://localhost:3000/health"
        when "cli"
          puts "  3. Run: crystal build src/#{@project_name}.cr"
          puts "  4. Run: ./#{@project_name} --help"
        end

        puts
        puts "Documentation: https://azutoolkit.org"
        puts "Support: https://github.com/azutoolkit/azu"
        puts
      end

      def show_help
        puts "Usage: azu new <project-name> [options]"
        puts
        puts "Create a new Azu project with the specified name."
        puts
        puts "Options:"
        puts "  --name NAME               Project name"
        puts "  --module MODULE           Module name (PascalCase)"
        puts "  --author AUTHOR           Author name"
        puts "  --email EMAIL             Author email"
        puts "  --license LICENSE         License (MIT, Apache-2.0, GPL-3.0, etc.)"
        puts "  --type TYPE               Project type (web, api, cli) [default: web]"
        puts "  --db DATABASE             Database adapter (postgresql, mysql, sqlite) [default: postgresql]"
        puts "  --test TEST               Test framework (spec, minitest) [default: spec]"
        puts "  --ci CI                   CI setup (\"GitHub Actions\", \"GitLab CI\", \"None\") [default: GitHub Actions]"
        puts "  --docker                  Include Docker support"
        puts "  --no-docker               Skip Docker support"
        puts "  --git                     Initialize Git repository [default]"
        puts "  --no-git                  Skip Git initialization"
        puts "  --example                 Include example code [default]"
        puts "  --no-example              Skip example code"
        puts "  --yes                     Non-interactive mode (use defaults)"
        puts "  --help                    Show this help message"
        puts
        puts "Interactive Examples:"
        puts "  azu new my_app            # Interactive prompts"
        puts "  azu new my_blog --type web"
        puts
        puts "Non-interactive Examples:"
        puts "  azu new my_api --type api --db postgresql --yes"
        puts "  azu new my_tool --type cli --no-docker --no-git --yes"
        puts "  azu new my_service --author \"John Doe\" --email john@example.com --license MIT --yes"
      end
    end
  end
end
