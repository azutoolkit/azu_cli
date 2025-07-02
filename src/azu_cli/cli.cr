require "topia"

module AzuCLI
  # Main CLI class using Topia framework
  class CLI
    @commands : Hash(String, Commands::Base.class) = {} of String => Commands::Base.class
    @plugins : Array(Plugins::Base) = [] of Plugins::Base
    @middleware : Array(Middleware::Base) = [] of Middleware::Base

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

      # Database commands
      register_command("db", Commands::Database)

      # Development commands
      register_command("serve", Commands::Serve)
      register_command("dev", Commands::Dev)

      # Plugin commands
      register_command("plugin", Commands::Plugin)
    end

    # Register a command
    private def register_command(name : String, command_class : Commands::Base.class)
      @commands[name] = command_class
    end

    # Set up plugins
    private def setup_plugins
      # Load built-in plugins
      load_builtin_plugins

      # Load external plugins
      load_external_plugins
    end

    # Load built-in plugins
    private def load_builtin_plugins
      @plugins << Plugins::GeneratorPlugin.new
      @plugins << Plugins::DatabasePlugin.new
      @plugins << Plugins::DevelopmentPlugin.new

      # Call on_load for each plugin
      @plugins.each(&.on_load)
    end

    # Load external plugins
    private def load_external_plugins
      # This would load plugins from configuration
      # For now, just log that we're loading external plugins
      Logger.debug("Loading external plugins...")
    end

    # Set up middleware
    private def setup_middleware
      @middleware << Middleware::Logging.new
      @middleware << Middleware::ErrorHandler.new
      @middleware << Middleware::Configuration.new
    end

    # Run the CLI with given arguments
    def run(args : Array(String))
      if args.empty?
        show_help
        return
      end

      command_name = args[0]
      command_args = args[1..-1]

      if command_class = @commands[command_name]?
        execute_command(command_class, command_name, command_args)
      else
        Logger.error("Unknown command: #{command_name}")
        Logger.info("Run 'azu help' to see available commands")
        exit(1)
      end
    end

    # Execute a command with middleware
    private def execute_command(command_class : Commands::Base.class, command_name : String, args : Array(String))
      command = command_class.new
      command.parse_args(args)

      # Run middleware before command
      @middleware.each(&.before(command, args))
      @plugins.each(&.before_command(command, args))

      begin
        # Execute the command
        result = command.execute

        # Run middleware after command
        @middleware.each(&.after(command, result))
        @plugins.each(&.after_command(command, result))

        # Handle result
        handle_result(result)
      rescue ex : Exception
        # Run middleware on error
        @middleware.each(&.error(command, ex))
        @plugins.each(&.on_error(command, ex))

        Logger.error("Command failed: #{ex.message}")
        exit(1)
      end
    end

    # Handle command result
    private def handle_result(result : Commands::Result)
      if result.success?
        Logger.info(result.message) if result.message
        exit(0)
      else
        Logger.error(result.error) if result.error
        exit(1)
      end
    end

    # Show help
    private def show_help
      Commands::Help.new.execute
    end
  end
end
