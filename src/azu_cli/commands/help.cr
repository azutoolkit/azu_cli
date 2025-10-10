require "./base"

module AzuCLI
  module Commands
    # Help command to display CLI help information
    class Help < Base
      def initialize
        super("help", "Show help information for Azu CLI")
      end

      def execute : Result
        if command_name = get_arg(0)
          show_command_help(command_name)
        else
          show_general_help
        end

        success("Help information displayed")
      end

      private def show_general_help
        puts "Azu CLI - Crystal web framework command line tool"
        puts "Version: #{AzuCLI::VERSION}"
        puts
        puts "Usage: azu <command> [options] [arguments]"
        puts
        puts "Project Commands:"
        puts "  new <project-name>     Create a new Azu project"
        puts "  init                   Initialize Azu in existing project"
        puts "  generate <type> <name> Generate code (alias: g)"
        puts
        puts "Database Commands:"
        puts "  db:create              Create the database"
        puts "  db:migrate             Run pending migrations"
        puts "  db:rollback            Rollback migrations"
        puts "  db:seed                Seed the database with data"
        puts "  db:reset               Reset database (drop, create, migrate)"
        puts "  db:status              Show migration status"
        puts "  db:setup               Setup database (create and migrate)"
        puts "  db:drop                Drop the database"
        puts
        puts "Development Commands:"
        puts "  serve                  Start development server with hot reload (alias: s)"
        puts "  test                   Run application tests (alias: t)"
        puts
        puts "Job Queue Commands:"
        puts "  jobs:worker            Start background job workers"
        puts "  jobs:status            Show job queue status"
        puts "  jobs:clear             Clear job queues"
        puts "  jobs:retry             Retry failed jobs"
        puts "  jobs:ui                Start JoobQUI web interface"
        puts
        puts "Session Commands:"
        puts "  session:setup          Setup session management"
        puts "  session:clear          Clear all sessions"
        puts
        puts "Other Commands:"
        puts "  plugin <operation>     Plugin management"
        puts "  version                Show version information"
        puts "  help [command]         Show this help or command help"
        puts
        puts "Generator Types:"
        puts "  model, endpoint, service, request, page, migration, scaffold"
        puts "  component, middleware, validator, job, mailer, channel, auth"
        puts
        puts "Examples:"
        puts "  azu new my-app"
        puts "  azu generate model User name:string email:string"
        puts "  azu generate auth --strategy jwt"
        puts "  azu db:create"
        puts "  azu db:migrate"
        puts "  azu serve"
        puts "  azu test --watch"
        puts "  azu jobs:worker --workers 4"
        puts
        puts "For more information, visit: https://azutopia.gitbook.io/azu"
      end

      private def show_command_help(command_name : String)
        case command_name
        when "new"
          show_new_help
        when "generate", "g"
          show_generate_help
        when "db"
          show_db_help
        when "serve"
          show_serve_help
        when "test"
          show_test_help
        when "jobs"
          show_jobs_help
        when "session"
          show_session_help
        when "plugin"
          show_plugin_help
        else
          puts "Unknown command: #{command_name}"
          puts "Run 'azu help' to see available commands"
        end
      end

      private def show_new_help
        puts "Usage: azu new <project-name> [options]"
        puts
        puts "Create a new Azu project with the specified name."
        puts
        puts "Options:"
        puts "  --type <type>          Project type (web, api, cli) [default: web]"
        puts "  --database <db>        Database type (postgresql, mysql, sqlite) [default: postgresql]"
        puts "  --skip-git             Skip git initialization"
        puts "  --skip-install         Skip dependency installation"
        puts
        puts "Examples:"
        puts "  azu new my-web-app"
        puts "  azu new my-api --type api --database mysql"
        puts "  azu new my-cli --type cli"
      end

      private def show_generate_help
        puts "Usage: azu generate <type> <name> [options] [attributes]"
        puts
        puts "Generate code for your Azu project."
        puts
        puts "Generator Types:"
        puts "  model <name> [attr:type]     Generate a model with attributes"
        puts "  endpoint <name> [actions]    Generate endpoints with actions"
        puts "  service <name> [methods]     Generate a service with methods"
        puts "  request <name> [attr:type]   Generate a request with attributes"
        puts "  page <name> [attr:type]      Generate a page with template variables"
        puts "  migration <name> [attr:type] Generate a database migration"
        puts "  scaffold <name> [attr:type]  Generate a complete CRUD scaffold"
        puts "  component <name> [attr:type] Generate a component"
        puts "  middleware <name> [type]     Generate middleware"
        puts "  validator <name> [type]      Generate a custom validator"
        puts "  channel <name> [events]      Generate a WebSocket channel"
        puts "  handler <name> [type]        Generate a request handler"
        puts "  request <name> [attr:type]   Generate a request class"
        puts "  response <name> [attr:type]  Generate a response class"
        puts
        puts "Options:"
        puts "  --force                    Overwrite existing files"
        puts "  --skip-tests               Skip test file generation"
        puts "  --api-only                 Generate API-only components"
        puts "  --web-only                 Generate web-only components"
        puts
        puts "Examples:"
        puts "  azu generate model User name:string email:string age:int32"
        puts "  azu generate endpoint Users index show create update destroy"
        puts "  azu generate scaffold Post title:string content:text published:bool"
        puts "  azu generate service UserService create find update delete"
      end

      private def show_db_help
        puts "Usage: azu db <operation> [options]"
        puts
        puts "Database operations for your Azu project."
        puts
        puts "Operations:"
        puts "  create                   Create the database"
        puts "  migrate                  Run pending migrations"
        puts "  rollback                 Rollback the last migration"
        puts "  seed                     Seed the database with data"
        puts "  reset                    Reset the database (drop, create, migrate, seed)"
        puts "  status                   Show migration status"
        puts
        puts "Options:"
        puts "  --environment <env>      Use specific environment [default: development]"
        puts "  --dry-run                Show what would be done without executing"
        puts
        puts "Examples:"
        puts "  azu db create"
        puts "  azu db migrate"
        puts "  azu db seed"
        puts "  azu db reset"
      end

      private def show_serve_help
        puts "Usage: azu serve [options]"
        puts
        puts "Start the development server with hot reloading."
        puts
        puts "Options:"
        puts "  --host <host>            Server host [default: localhost]"
        puts "  --port <port>            Server port [default: 3000]"
        puts "  --environment <env>      Environment [default: development]"
        puts "  --no-reload              Disable hot reloading"
        puts "  --workers <count>        Number of worker processes"
        puts
        puts "Examples:"
        puts "  azu serve"
        puts "  azu serve --port 4000"
        puts "  azu serve --host 0.0.0.0 --port 8080"
      end

      private def show_test_help
        puts "Usage: azu test [files] [options]"
        puts
        puts "Run application tests with Crystal spec."
        puts
        puts "Options:"
        puts "  --watch, -w              Run tests in watch mode"
        puts "  --coverage, -c           Enable coverage reporting"
        puts "  --verbose, -v            Enable verbose output"
        puts "  --parallel, -p           Run tests in parallel"
        puts "  --filter, -f <pattern>   Run tests matching pattern"
        puts
        puts "Examples:"
        puts "  azu test"
        puts "  azu test spec/models/"
        puts "  azu test --watch"
        puts "  azu test --filter User"
      end

      private def show_jobs_help
        puts "Usage: azu jobs:<command> [options]"
        puts
        puts "Background job management with JoobQ."
        puts
        puts "Commands:"
        puts "  jobs:worker              Start job workers"
        puts "  jobs:status              Show queue status and statistics"
        puts "  jobs:clear               Clear job queues"
        puts "  jobs:retry               Retry failed jobs"
        puts "  jobs:ui                  Start JoobQUI web interface"
        puts
        puts "Examples:"
        puts "  azu jobs:worker --workers 4"
        puts "  azu jobs:status"
        puts "  azu jobs:clear --failed"
        puts "  azu jobs:retry --all"
        puts "  azu jobs:ui --port 4000"
      end

      private def show_session_help
        puts "Usage: azu session:<command> [options]"
        puts
        puts "Session management for the application."
        puts
        puts "Commands:"
        puts "  session:setup            Setup session management"
        puts "  session:clear            Clear all sessions"
        puts
        puts "Options (for setup):"
        puts "  --backend <type>         Session backend (redis, memory, database)"
        puts "  --force                  Overwrite existing configuration"
        puts
        puts "Examples:"
        puts "  azu session:setup --backend redis"
        puts "  azu session:clear"
      end

      private def show_plugin_help
        puts "Usage: azu plugin <operation> [options]"
        puts
        puts "Plugin management for Azu CLI."
        puts
        puts "Operations:"
        puts "  list                     List installed plugins"
        puts "  install <name>           Install a plugin"
        puts "  uninstall <name>         Uninstall a plugin"
        puts "  enable <name>            Enable a plugin"
        puts "  disable <name>           Disable a plugin"
        puts "  info <name>              Show plugin information"
        puts
        puts "Options:"
        puts "  --source <url>           Plugin source URL"
        puts "  --version <version>      Plugin version"
        puts
        puts "Examples:"
        puts "  azu plugin list"
        puts "  azu plugin install my-plugin"
        puts "  azu plugin enable my-plugin"
      end
    end
  end
end
