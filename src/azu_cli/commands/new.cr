require "./base"
require "option_parser"
require "readline"

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
      property include_joobq : Bool = true
      property non_interactive : Bool = false

      def initialize
        super("new", "Create a new Azu project")
      end

      # Override parse_args to also trigger custom parsing
      def parse_args(args : Array(String))
        super(args)
        parse_arguments
      end

      def execute : Result
        parse_arguments

        # Set project name from argument if not set by flag
        if @project_name.empty?
          if name = get_arg(0)
            @project_name = name
          else
            return error("Project name is required. Usage: azu new <project-name> [options]")
          end
        end

        # Validate project name
        unless valid_project_name?(@project_name)
          error_msg = "Invalid project name '#{@project_name}'.\n"
          error_msg += "  Project names must:\n"
          error_msg += "  • Start with a letter (not a number)\n"
          error_msg += "  • Contain only letters, numbers, underscores, and hyphens\n"
          error_msg += "  • Not be a Crystal reserved word (e.g., class, module, def)\n"
          error_msg += "  • Be convertible to a valid Crystal module name\n"
          error_msg += "\n  Example: my_app, blog, web_service"
          return error(error_msg)
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
          parser.on("--api", "Create API project (shorthand for --type api)") { @project_type = "api" }
          parser.on("--db DATABASE", "Database adapter (postgresql, mysql, sqlite)") { |db| @database = db }
          parser.on("--test TEST", "Test framework (spec, minitest)") { |test| @test_framework = test }
          parser.on("--ci CI", "CI setup (\"GitHub Actions\", \"GitLab CI\", \"None\")") { |ci| @ci_setup = ci }
          parser.on("--docker", "Include Docker support") { @docker_support = true }
          parser.on("--no-docker", "Skip Docker support") { @docker_support = false }
          parser.on("--git", "Initialize Git repository") { @git_init = true }
          parser.on("--no-git", "Skip Git initialization") { @git_init = false }
          parser.on("--example", "Include example code") { @include_example = true }
          parser.on("--no-example", "Skip example code") { @include_example = false }
          parser.on("--joobq", "Include JoobQ for background jobs") { @include_joobq = true }
          parser.on("--no-joobq", "Skip JoobQ integration") { @include_joobq = false }
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

        # Ask about background jobs (only for web/api projects)
        unless @project_type == "cli"
          @include_joobq = prompt_boolean("Include JoobQ for background job processing?", @include_joobq)
        end

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
        choices.each_with_index do |choice, _|
          marker = choice == default ? "●" : "○"
          puts "  #{marker} #{choice}"
        end

        print "Select (#{choices.join("/")}) [#{default}]: "
        response = Readline.readline("", false)

        return default if response.nil? || response.strip.empty?

        selected = response.strip.downcase
        choice = choices.find(&.downcase.starts_with?(selected))
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
        # Validate key to prevent shell injection - only allow safe git config keys
        unless key.matches?(/^[a-z][a-z0-9.\-]*$/i)
          Logger.debug("Invalid git config key format: #{key}")
          return nil
        end

        # Use Process.run for safer execution
        process = Process.new("git", ["config", "--global", key], output: Process::Redirect::Pipe, error: Process::Redirect::Close)
        output = process.output.gets_to_end.strip
        process.wait
        output.empty? ? nil : output
      rescue ex : Exception
        Logger.debug("Failed to get git config #{key}: #{ex.message}")
        nil
      end

      # Crystal reserved words that cannot be used as project names
      CRYSTAL_RESERVED_WORDS = %w[
        abstract alias annotation as asm begin break case class def do else elsif end ensure enum
        extend false for fun if include instance_sizeof is_a? lib macro module next nil of out
        pointerof private protected require rescue responds_to? return select self sizeof struct
        super then true type typeof union uninitialized unless until verbatim when while with yield
      ]

      private def valid_project_name?(name : String) : Bool
        return false if name.empty?

        # Project name must start with a letter
        return false unless name[0].ascii_letter?

        # Must not start or end with hyphen or underscore
        return false if name.starts_with?("-") || name.ends_with?("-")
        return false if name.starts_with?("_") || name.ends_with?("_")

        # Must contain only valid characters
        return false unless name.matches?(/^[a-zA-Z][a-zA-Z0-9_-]*$/)

        # Cannot be a Crystal reserved word
        return false if CRYSTAL_RESERVED_WORDS.includes?(name.downcase)

        # Module name (derived from project name) must also be valid
        module_name = name.split(/[-_]/).map(&.capitalize).join
        return false unless module_name.matches?(/^[A-Z][a-zA-Z0-9]*$/)
        return false if CRYSTAL_RESERVED_WORDS.includes?(module_name.downcase)

        true
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
        puts "  Background jobs:  #{@include_joobq ? "Yes (JoobQ)" : "No"}" unless @project_type == "cli"
        puts
      end

      private def generate_project
        Logger.progress_start("Generating project files")

        begin
          # Create the generator
          generator = AzuCLI::Generate::Project.new(
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
            include_example: @include_example,
            include_joobq: @include_joobq,
            env: "development"
          )

          # Generate the project in the target directory
          generator.render(@project_name, force: false, interactive: false, list: false, color: true)

          # Remove JoobQ files if not included
          unless @include_joobq
            remove_joobq_files
          end

          Logger.progress_done(true)
        rescue ex : Exception
          Logger.progress_done(false)
          Logger.exception(ex, "Failed to generate project files")
          raise ex
        end
      end

      private def remove_joobq_files
        Dir.cd(@project_name) do
          # Remove JoobQ-related files
          File.delete("config/jobs.yml") if File.exists?("config/jobs.yml")
          File.delete("src/initializers/joobq.cr") if File.exists?("src/initializers/joobq.cr")
          File.delete("src/worker.cr") if File.exists?("src/worker.cr")

          # Remove jobs directory if it exists and is empty
          if Dir.exists?("src/jobs")
            begin
              Dir.children("src/jobs").each do |file|
                File.delete(File.join("src/jobs", file))
              end
              Dir.delete("src/jobs")
            rescue
              # Directory not empty or other error - skip
            end
          end
        rescue ex
          # Silently ignore errors - files may not exist
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
          if @include_joobq
            puts "  5. Start background workers: azu jobs:worker"
          end
        when "api"
          puts "  3. Run: azu serve"
          puts "  4. Test: curl http://localhost:3000/health"
          if @include_joobq
            puts "  5. Start background workers: azu jobs:worker"
          end
        when "cli"
          puts "  3. Run: crystal build src/#{@project_name}.cr"
          puts "  4. Run: ./#{@project_name} --help"
        end

        if @include_joobq && (@project_type == "web" || @project_type == "api")
          puts
          Logger.info("📦 JoobQ Integration:")
          puts "  - Configuration: config/jobs.yml"
          puts "  - Initializer: src/initializers/joobq.cr"
          puts "  - Worker: src/worker.cr"
          puts "  - Generate jobs: azu generate job <name> [params]"
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
        puts "  --api                     Create API project (shorthand for --type api)"
        puts "  --db DATABASE             Database adapter (postgresql, mysql, sqlite) [default: postgresql]"
        puts "  --test TEST               Test framework (spec, minitest) [default: spec]"
        puts "  --ci CI                   CI setup (\"GitHub Actions\", \"GitLab CI\", \"None\") [default: GitHub Actions]"
        puts "  --docker                  Include Docker support"
        puts "  --no-docker               Skip Docker support"
        puts "  --git                     Initialize Git repository [default]"
        puts "  --no-git                  Skip Git initialization"
        puts "  --example                 Include example code [default]"
        puts "  --no-example              Skip example code"
        puts "  --joobq                   Include JoobQ for background jobs [default]"
        puts "  --no-joobq                Skip JoobQ integration"
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
