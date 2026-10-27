require "topia"

module AzuCLI
  # Main CLI class using Topia framework
  class CLI
    @commands : Hash(String, Commands::Base.class) = {} of String => Commands::Base.class
    @plugins : Array(Plugins::Base) = [] of Plugins::Base
    @middleware : Array(Middleware::Base) = [] of Middleware::Base

    # The names the CLI answers to (commands and their aliases).
    def command_names : Array(String)
      @commands.keys
    end

    def initialize
      setup_commands
      setup_plugins
      setup_middleware
    end

    # Set up all CLI commands
    private def setup_commands
      # Project management commands
      register_command("new", Commands::New)
      register_command("init", Commands::Init)
      register_command("version", Commands::Version)
      register_command("help", Commands::Help)

      # Code generation commands
      register_command("generate", Commands::Generate)
      register_command("g", Commands::Generate) # Alias
      register_command("undo", Commands::Undo)

      # Database commands
      register_command("db:create", Commands::DB::Create)
      register_command("db:drop", Commands::DB::Drop)
      register_command("db:migrate", Commands::DB::Migrate)
      register_command("db:rollback", Commands::DB::Rollback)
      register_command("db:seed", Commands::DB::Seed)
      register_command("db:reset", Commands::DB::Reset)
      register_command("db:status", Commands::DB::Status)
      register_command("db:setup", Commands::DB::Setup)
      register_command("db:schema:load", Commands::DB::SchemaLoad)
      register_command("db:data:migrate", Commands::DB::DataMigrate)
      register_command("db:migrations:verify", Commands::DB::Verify)
      register_command("db:validate", Commands::DB::Validate)

      # Development server command
      register_command("serve", Commands::Serve)
      register_command("server", Commands::Serve) # Alias
      register_command("s", Commands::Serve)      # Short alias

      # Development workflow commands
      register_command("dev", Commands::Dev)
      register_command("routes", Commands::Routes)
      register_command("console", Commands::Console)
      register_command("doctor", Commands::Doctor)

      # Job queue commands
      register_command("jobs:worker", Commands::Jobs::Worker)
      register_command("jobs:status", Commands::Jobs::Status)
      register_command("jobs:clear", Commands::Jobs::Clear)
      register_command("jobs:retry", Commands::Jobs::Retry)
      register_command("jobs:ui", Commands::Jobs::UI)

      # Session commands
      register_command("session:setup", Commands::Session::Setup)
      register_command("session:clear", Commands::Session::Clear)

      # Testing command
      register_command("test", Commands::Test)
      register_command("t", Commands::Test) # Alias

      # OpenAPI commands
      register_command("openapi:generate", Commands::OpenAPI::Generate)
      register_command("openapi:export", Commands::OpenAPI::Export)

      # Config commands
      register_command("config:show", Commands::Config::Show)
      register_command("config:validate", Commands::Config::Validate)
      register_command("config:env", Commands::Config::Env)

      # Completion command
      register_command("completion", Commands::Completion)
    end

    # Register a command
    private def register_command(name : String, command_class : Commands::Base.class)
      @commands[name] = command_class
    end

    # Set up plugins
    private def setup_plugins
      # Load built-in plugins
      load_builtin_plugins
    end

    # Load built-in plugins
    private def load_builtin_plugins
      @plugins << Plugins::GeneratorPlugin.new
      @plugins << Plugins::DatabasePlugin.new
      @plugins << Plugins::DevelopmentPlugin.new

      # Call on_load for each plugin
      @plugins.each(&.on_load)
    end

    # Set up middleware
    private def setup_middleware
      @middleware << Middleware::Logging.new
      @middleware << Middleware::ErrorHandler.new
      @middleware << Middleware::Configuration.new
    end

    # Run the CLI with given arguments and return the process exit code (the entry point exits with it,
    # so the CLI can be driven from specs without ending the process)
    def run(args : Array(String)) : Int32
      if args.empty?
        show_help
        return 0
      end

      command_name = args[0]
      command_args = args[1..-1]

      if command_class = @commands[command_name]?
        execute_command(command_class, command_name, command_args)
      else
        Logger.error("Unknown command: #{command_name}")
        Logger.info("Run 'azu help' to see available commands")
        1
      end
    end

    # Execute a command with middleware
    private def execute_command(command_class : Commands::Base.class, command_name : String, args : Array(String)) : Int32
      command = command_class.new

      begin
        command.parse_args(args)

        # Run middleware before command (a plugin may reject the arguments by raising)
        @middleware.each(&.before(command, args))
        @plugins.each(&.before_command(command, args))

        # Execute the command
        result = command.execute

        # Run middleware after command
        @middleware.each(&.after(command, result))
        @plugins.each(&.after_command(command, result))

        # Handle result
        handle_result(result, command)
      rescue ex : Exception
        # Run middleware on error
        @middleware.each(&.error(command, ex))
        @plugins.each(&.on_error(command, ex))

        Logger.error("Command failed: #{ex.message}")
        1
      end
    end

    # Handle command result
    private def handle_result(result : Commands::Result, command : Commands::Base) : Int32
      if result.success?
        # A command that drew a card has shown its outcome; the summary line would repeat it
        Logger.info(result.message) unless result.message.empty? || command.drew_card?
        0
      else
        Logger.error(result.error) unless result.error.empty?
        result.exit_code
      end
    end

    # Show help
    private def show_help
      Commands::Help.new.execute
    end
  end
end
