require "./base"

module AzuCLI
  module Commands
    # New command for creating new Azu projects
    class New < Base
      def initialize
        super("new", "Create a new Azu project")
      end

      def execute : Result
        parse_args(get_args)

        # Handle help option
        if has_option?("help")
          show_help
          return success("Help displayed")
        end

        unless validate_required_args(1)
          return error("Usage: azu new <project-name> [options]")
        end

        project_name = get_arg(0).not_nil!
        project_type = get_option("type", "web")
        database = get_option("database", "postgresql")

        # Create generator options for project generation
        options = create_project_options(project_type, database)

        # Execute project generator
        execute_project_generator(project_name, options)
      end

      private def create_project_options(project_type : String, database : String) : Generator::Core::GeneratorOptions
        options = Generator::Core::GeneratorOptions.new
        options.force = has_option?("force")
        options.skip_tests = has_option?("skip-tests")
        options.custom_options = {
          "type"     => project_type,
          "database" => database,
        }
        options.additional_args = [] of String

        options
      end

      private def execute_project_generator(project_name : String, options : Generator::Core::GeneratorOptions) : Result
        begin
          # Create and execute the project generator
          generator = Generator::ProjectGenerator.new(project_name, project_name, options)
          result = generator.generate!

          Logger.info("✅ #{result}")

          # Show next steps
          show_next_steps(project_name, options.custom_options["type"]?)

          success(result)
        rescue ex : ArgumentError
          error("Invalid project arguments: #{ex.message}")
        rescue ex : File::Error
          error("File operation failed: #{ex.message}")
        rescue ex : Exception
          error("Project creation failed: #{ex.message}")
        end
      end

      private def show_next_steps(project_name : String, project_type : String?)
        puts
        puts "🎉 Project '#{project_name}' created successfully!"
        puts
        puts "Next steps:"
        puts "  1. cd #{project_name}"
        puts "  2. shards install"

        case project_type
        when "web", "api"
          puts "  3. azu db create"
          puts "  4. azu db migrate"
          puts "  5. azu serve"
        when "cli"
          puts "  3. crystal build src/#{project_name}.cr"
          puts "  4. ./#{project_name} --help"
        end

        puts
        puts "📚 Learn more: https://azutopia.gitbook.io/azu/getting-started"
      end

      def show_help
        puts "Usage: azu new <project-name> [options]"
        puts
        puts "Create a new Azu project with the specified name."
        puts
        puts "Options:"
        puts "  --type <type>          Project type (web, api, cli) [default: web]"
        puts "  --database <db>        Database type (postgresql, mysql, sqlite) [default: postgresql]"
        puts "  --force                Overwrite existing directory"
        puts "  --skip-tests           Skip test file generation"
        puts "  --skip-git             Skip git initialization"
        puts "  --skip-install         Skip dependency installation"
        puts
        puts "Examples:"
        puts "  azu new my-web-app"
        puts "  azu new my-api --type api --database mysql"
        puts "  azu new my-cli --type cli"
      end
    end
  end
end
