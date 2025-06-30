require "../command"

module AzuCLI::Commands
  # Help command - displays available commands and usage information
  class Help < Command
    command_name "help"
    description "Show help information for Azu CLI commands"
    usage "help [command]"

    def execute(args : Hash(String, String | Array(String))) : String | Nil
      positional = get_positional_args(args)

      if positional.empty?
        show_general_help
      else
        show_command_help(positional.first)
      end

      nil
    end

    private def show_general_help
      puts
      puts "🚀 Azu CLI - A Crystal toolkit for building web applications".colorize(:cyan).bold
      puts
      puts "Azu is a powerful toolkit that provides expressive, elegant syntax for building"
      puts "rich, interactive, type-safe applications quickly with less code."
      puts
      puts "💡 Documentation:"
      puts "  • Azu Toolkit: https://azutopia.gitbook.io/azu/"
      puts "  • CQL ORM: https://github.com/azutoolkit/cql"
      puts
      puts "🎯 Usage:"
      puts "  azu <command> [options] [arguments]"
      puts
      puts "📋 Available Commands:"
      puts

      commands = [
        {name: "new", desc: "Create a new Azu project", category: "Project"},
        {name: "init", desc: "Initialize Azu in existing project", category: "Project"},
        {name: "generate", desc: "Generate components (controllers, models, etc.)", category: "Generation"},
        {name: "scaffold", desc: "Generate complete resource scaffolding", category: "Generation"},
        {name: "model", desc: "Generate a new model", category: "Generation"},
        {name: "migration", desc: "Generate a new database migration", category: "Generation"},
        {name: "serve", desc: "Start development server with hot reloading", category: "Development"},
        {name: "dev", desc: "Alias for serve command", category: "Development"},
        {name: "console", desc: "Start interactive console with full application context", category: "Development"},
        {name: "db:create", desc: "Create the database", category: "Database"},
        {name: "db:migrate", desc: "Run database migrations", category: "Database"},
        {name: "db:rollback", desc: "Rollback database migration", category: "Database"},
        {name: "db:seed", desc: "Seed the database with sample data", category: "Database"},
        {name: "db:reset", desc: "Drop, create, and migrate database", category: "Database"},
        {name: "test", desc: "Run the test suite", category: "Testing"},
        {name: "build", desc: "Build the application for production", category: "Build"},
        {name: "version", desc: "Show version information", category: "Info"},
        {name: "help", desc: "Show help information", category: "Info"},
      ]

      # Group commands by category
      categories = commands.group_by { |cmd| cmd[:category] }

      categories.each do |category, category_commands|
        puts "  #{category}:".colorize(:yellow).bold
        category_commands.each do |cmd|
          puts "    #{"#{cmd[:name]}".ljust(15)} #{cmd[:desc]}"
        end
        puts
      end

      puts "🔧 Global Options:"
      puts "  --help, -h      Show help information"
      puts "  --version, -v   Show version information"
      puts "  --debug, -d     Enable debug mode"
      puts "  --verbose       Enable verbose output"
      puts "  --quiet, -q     Suppress non-error output"
      puts "  --config FILE   Use custom configuration file"
      puts
      puts "💡 Examples:"
      puts "  azu new my_app                    # Create new project"
      puts "  azu generate controller users     # Generate users controller"
      puts "  azu scaffold post title:string   # Generate complete post resource"
      puts "  azu serve --port 4000            # Start server on port 4000"
      puts "  azu db:migrate                   # Run database migrations"
      puts
      puts "📖 For detailed command help:"
      puts "  azu help <command>               # Show help for specific command"
      puts "  azu <command> --help             # Alternative help syntax"
      puts
      puts "🌟 Get started:"
      puts "  azu new my_awesome_app && cd my_awesome_app && azu serve"
      puts
    end

    private def show_command_help(command_name : String)
      # This would show detailed help for a specific command
      # For now, we'll show a general message and suggest using --help
      puts
      puts "📖 Help for command: #{command_name}".colorize(:cyan).bold
      puts
      puts "For detailed help about the '#{command_name}' command, run:"
      puts "  azu #{command_name} --help"
      puts
      puts "This will show:"
      puts "  • Command description"
      puts "  • Usage syntax"
      puts "  • Available options"
      puts "  • Examples"
      puts
    end

    def show_command_specific_help
      puts "Options:"
      puts "  [command]       Show help for specific command"
      puts
      puts "Examples:"
      puts "  azu help                         # Show general help"
      puts "  azu help new                     # Show help for 'new' command"
      puts "  azu help scaffold                # Show help for 'scaffold' command"
    end
  end
end
