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
        puts "  generate <type> <name> Generate code (alias: g); on a terminal it previews the files first"
        puts "  undo                   Revert the files of the last azu generate"
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
        puts "  db:schema:load         Load a schema file into the database"
        puts "  db:data:migrate        Run data migrations"
        puts "  db:migrations:verify   Verify that migrations roll back and re-apply"
        puts "  db:validate            Validate the database configuration and connection"
        puts
        puts "Development Commands:"
        puts "  joobq                  Manage queues, workflows and dead letters in a terminal dashboard"
        puts "  dev                    Run the app, rebuilding and restarting it when the code changes"
        puts "  connect                Monitor production over verified SSH (read-only local HUD)"
        puts "  serve                  Compile and run the app with a --production build (alias: s)"
        puts "  routes                 List the routes: method, path, endpoint, request/response, helpers"
        puts "  config                 Show the configuration of the application (secrets masked)"
        puts "  console                Open Crystal's interpreter with the app loaded (needs `crystal i`)"
        puts "  doctor                 Check Crystal, shards, database, env, secrets and port"
        puts "  test                   Run application tests (alias: t)"
        puts
        puts "Job Queue Commands:"
        puts "  jobs:worker            Start background job workers"
        puts "  jobs:status            Show job queue status"
        puts "  jobs:clear             Clear job queues"
        puts "  jobs:retry             Retry failed jobs"
        puts "  jobs:ui                Start JoobQUI web interface"
        puts "  jobs:dlq               List dead-letter job IDs"
        puts "  jobs:pause / resume    Control queue claims"
        puts
        puts "Session Commands:"
        puts "  session:setup          Setup session management"
        puts "  session:clear          Clear all sessions"
        puts
        puts "OpenAPI Commands:"
        puts "  openapi:export        Export an OpenAPI 3.1 spec from the code"
        puts "  openapi:generate      Generate code from an OpenAPI 3.1 spec"
        puts
        puts "Other Commands:"
        puts "  completion <shell>     Print a shell completion script (bash, zsh, fish)"
        puts "  version                Show version information"
        puts "  help [command]         Show this help or command help"
        puts
        puts "Generator Types:"
        puts "  model, endpoint, service, request, response, page, migration, data:migration, seed"
        puts "  scaffold, component, spark, spark:scaffold, middleware, validator, job, mailer, channel, auth, template, api_resource"
        puts
        puts "Examples:"
        puts "  azu new my-app"
        puts "  azu generate model User name:string email:string"
        puts "  azu generate auth"
        puts "  azu db:create"
        puts "  azu db:migrate"
        puts "  azu dev"
        puts "  azu routes --method POST"
        puts "  azu config --section database"
        puts "  azu doctor"
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
        when "dev"
          Dev.new.show_help
        when "connect"
          Connect.new.show_help
        when "routes"
          Routes.new.show_help
        when "config"
          Config.new.show_help
        when "console"
          Console.new.show_help
        when "doctor"
          Doctor.new.show_help
        when "serve", "s"
          show_serve_help
        when "test", "t"
          show_test_help
        when "jobs"
          show_jobs_help
        when "session"
          show_session_help
        else
          puts "No detailed help for: #{command_name}"
          puts "Run 'azu help' to see available commands"
        end
      end

      private def show_new_help
        puts "Usage: azu new <project-name> [options]"
        puts
        puts "Create a new Azu project with the specified name."
        puts
        puts "Options:"
        puts "  --type TYPE            Project type (web, api, cli) [default: web]"
        puts "  --api                  Shorthand for --type api"
        puts "  --db DATABASE          Database adapter (postgresql, mysql, sqlite) [default: postgresql]"
        puts "  --test TEST            Test framework (spec, minitest) [default: spec]"
        puts "  --ci CI                CI setup (\"GitHub Actions\" or \"None\") [default: GitHub Actions]"
        puts "  --no-ci                Skip the CI workflow"
        puts "  --docker               Generate a Dockerfile and .dockerignore (web and api)"
        puts "  --no-git               Skip git initialization"
        puts "  --no-example           Skip the example code"
        puts "  --no-joobq             Skip JoobQ integration"
        puts "  --name, --module, --author, --email, --license"
        puts "  --yes                  Non-interactive mode"
        puts
        puts "Examples:"
        puts "  azu new my-web-app"
        puts "  azu new my-api --type api --db sqlite --docker"
        puts "  azu new my-cli --type cli --yes"
      end

      private def show_generate_help
        puts "Usage: azu generate <type> <name> [options] [attributes]"
        puts
        puts "Generate code for your Azu project."
        puts
        puts "Generator Types:"
        puts "  model <name> [attr:type]       Model, with its migration"
        puts "  endpoint <name> [actions]      Endpoints with request and page"
        puts "  service <name> [methods]       Service"
        puts "  request <name> [attr:type]     Request contract"
        puts "  response <name> [attr:type]    Response object"
        puts "  page <name> [attr:type]        Page with its template"
        puts "  migration <name> [attr:type]   Database migration"
        puts "  data:migration <name>          Data migration"
        puts "  seed <name>                    Seed file"
        puts "  scaffold <name> [attr:type]    CRUD: model, endpoints, requests, pages, templates, migration"
        puts "  component <name> [attr:type]   Component"
        puts "  spark <name> [attr:type]       Live component (--page adds a demo route)"
        puts "  scaffold <name> --spark        Live database CRUD with shared updates"
        puts "  middleware <name>              Middleware (--type authentication, ...)"
        puts "  validator <name>               Custom validator (--record RECORD)"
        puts "  mailer <name>                  Mailer"
        puts "  channel <name>                 WebSocket channel"
        puts "  auth                           Session authentication (web projects)"
        puts "  job <name>, joobq              JoobQ jobs and setup"
        puts "  template, api_resource         Templates; API resource"
        puts
        puts "Options:"
        puts "  --force                    Overwrite existing files"
        puts "  --skip-tests               Do not generate the migration (generate model)"
        puts "  --skip COMPONENTS          Skip components (comma-separated)"
        puts "  --api-only, --web-only     Generate only API or only web components"
        puts "  --strategy STRATEGY        Authentication strategy (session)"
        puts "  --type TYPE, --record RECORD   Generator-specific options"
        puts
        puts "Examples:"
        puts "  azu generate model User name:string email:string age:int32"
        puts "  azu generate scaffold Post title:string content:text published:bool"
        puts "  azu generate channel Chat"
        puts "  azu generate auth"
      end

      private def show_db_help
        puts "Usage: azu db:<command> [options]"
        puts
        puts "Commands:"
        puts "  db:create, db:drop, db:setup, db:reset, db:migrate, db:rollback, db:status, db:seed,"
        puts "  db:schema:load, db:data:migrate, db:migrations:verify, db:validate"
        puts
        puts "Options (not every command takes every option):"
        puts "  --env, -e ENV            Environment [default: development]"
        puts "  --force, -f              Skip the confirmation (drop, reset, rollback)"
        puts "  --steps, -s N            Number of migrations (migrate, rollback)"
        puts "  --version, -v VERSION    Target migration version (migrate, rollback)"
        puts "  --dry-run                Show what would be done (migrate, rollback, data:migrate)"
        puts "  --seed / --no-seed       Seed after setup or reset"
        puts
        puts "Examples:"
        puts "  azu db:create"
        puts "  azu db:migrate"
        puts "  azu db:rollback --steps 2"
        puts "  azu db:reset --force"
      end

      private def show_serve_help
        puts "Usage: azu serve [options]"
        puts
        puts "Compile and run the application, rebuilding when sources change."
        puts
        puts "Options:"
        puts "  --port, -p PORT          Server port"
        puts "  --host, -h HOST          Server host"
        puts "  --env, -e ENV            Environment"
        puts "  --no-watch               Do not rebuild on changes"
        puts "  --verbose, -v            Verbose output"
        puts
        puts "Examples:"
        puts "  azu serve"
        puts "  azu serve --port 8080 --host 0.0.0.0"
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
        puts "  --filter, -f <pattern>   Run examples matching pattern"
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
        puts "Commands and options:"
        puts "  jobs:worker              --workers N, --queues LIST, --release, --api, --shutdown-timeout N"
        puts "  jobs:status              --queue NAME, --json"
        puts "  jobs:dlq                 --queue NAME, --limit N, --offset N, --json"
        puts "  jobs:pause / resume      --queue NAME, --dry-run, --force"
        puts "  Common: --boot FILE, --redis URL, --env NAME, --help"
        puts "  jobs:clear               --queue NAME, --all, --failed, --dry-run, --force"
        puts "  jobs:retry               --queue NAME, --all, --limit N, --dry-run, --force"
        puts "  jobs:ui                  --path DIR, --port PORT, --host HOST"
        puts
        puts "Examples:"
        puts "  azu jobs:worker --workers 4"
        puts "  azu jobs:clear --failed"
        puts "  azu jobs:retry --all --dry-run"
      end

      private def show_session_help
        puts "Usage: azu session:<command> [options]"
        puts
        puts "Commands:"
        puts "  session:setup            Setup session management"
        puts "  session:clear            Clear all sessions"
        puts
        puts "Options:"
        puts "  --backend, -b TYPE       Session backend (cookie, redis, memory)"
        puts "  --force, -f              Overwrite existing configuration (setup) / skip confirmation (clear)"
        puts
        puts "Examples:"
        puts "  azu session:setup --backend redis"
        puts "  azu session:clear"
        puts
        puts "Note: session:setup writes its own session initializer and handler, which conflict with the ones"
        puts "'azu generate auth' writes. Use one of them."
      end
    end
  end
end
