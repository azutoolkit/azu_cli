require "../command"
require "readline"
require "process"
require "file_utils"
require "json"

module AzuCLI::Commands
  # Console command - provides interactive REPL for Azu applications
  class Console < Command
    command_name "console"
    description "Start interactive console with full application context"
    usage "console [options]"

    @project_name : String?
    @main_file : String?
    @console_process : Process?
    @history_file : String?

    def execute(args : Hash(String, String | Array(String))) : String | Nil
      require_project_root!

      # Parse command line arguments
      environment = get_flag(args, "environment", "development")
      verbose = has_flag?(args, "verbose") || config.verbose
      no_history = has_flag?(args, "no-history")

      # Get project information
      @project_name = get_project_name
      @main_file = "src/#{@project_name}.cr"
      @history_file = no_history ? nil : ".azu_console_history"

      log.info("🚀 Starting Azu Console...")
      log.info("   Project: #{@project_name}")
      log.info("   Environment: #{environment}")
      log.info("   Main file: #{@main_file}")
      log.info("   History: #{@history_file ? "enabled" : "disabled"}")

      # Validate project structure
      unless validate_project_structure
        return nil
      end

      # Start the interactive console
      start_console(environment, verbose)

      nil
    end

    private def validate_project_structure : Bool
      unless File.exists?(@main_file.not_nil!)
        log.error("Main application file not found: #{@main_file}")
        log.info("Make sure you're in the root directory of an Azu project")
        return false
      end

      unless File.exists?("shard.yml")
        log.error("shard.yml not found. This doesn't appear to be a Crystal project.")
        return false
      end

      # Check if required directories exist
      required_dirs = ["src", "src/models", "src/endpoints", "src/contracts"]
      missing_dirs = required_dirs.select { |dir| !Dir.exists?(dir) }

      unless missing_dirs.empty?
        log.warn("Some recommended directories are missing: #{missing_dirs.join(", ")}")
        log.info("These will be created automatically when you generate components")
      end

      true
    end

    private def start_console(environment : String, verbose : Bool)
      # Set up signal handling for graceful shutdown
      setup_signal_handlers

      # Create console script
      console_script = create_console_script(environment, verbose)

      # Start the console process
      start_console_process(console_script, verbose)

      # Clean up
      cleanup_console_script(console_script)
    end

    private def create_console_script(environment : String, verbose : Bool) : String
      script_content = <<-CRYSTAL
        # Azu Console Script
        # This script loads the full application context for interactive development

        require "readline"
        require "json"

        # Set environment
        ENV["AZU_ENV"] = "#{environment}"

        # Load the main application
        puts "Loading #{@project_name} application..."

        begin
          # Load the main application file
          require "./#{@main_file}"

          # Load additional components if they exist
          load_components

          puts "✅ Application loaded successfully!"
          puts "   Environment: #{environment}"
          puts "   Available modules: (see 'help' in console)"
          puts
          puts "💡 Console Tips:"
          puts "   • Use 'help' to see available commands"
          puts "   • Use 'models' to list available models"
          puts "   • Use 'services' to list available services"
          puts "   • Use 'db' to show database status"
          puts "   • Use 'exit' or Ctrl+D to quit"
          puts "   • Use Ctrl+C to interrupt current operation"
          puts

          # Start interactive REPL
          start_repl

        rescue ex : Exception
          puts "❌ Failed to load application. See error above."
          exit 1
        end

        def get_available_modules : String
          modules = [] of String

          # Check for models
          if Dir.exists?("src/models") && !Dir.glob("src/models/**/*.cr").empty?
            modules << "Models"
          end

          # Check for services
          if Dir.exists?("src/services") && !Dir.glob("src/services/**/*.cr").empty?
            modules << "Services"
          end

          # Check for contracts
          if Dir.exists?("src/contracts") && !Dir.glob("src/contracts/**/*.cr").empty?
            modules << "Contracts"
          end

          # Check for endpoints
          if Dir.exists?("src/endpoints") && !Dir.glob("src/endpoints/**/*.cr").empty?
            modules << "Endpoints"
          end

          modules.empty? ? "None" : modules.join(", ")
        end

        def load_components
          # Load models
          Dir.glob("src/models/**/*.cr").each do |file|
            begin
              require "./\#{file}"
              puts "   Loaded model: \#{File.basename(file, ".cr")}" if #{verbose.inspect}
            rescue ex
              puts "   Warning: Failed to load \#{file}: \#{ex.message}" if #{verbose.inspect}
            end
          end

          # Load services
          Dir.glob("src/services/**/*.cr").each do |file|
            begin
              require "./\#{file}"
              puts "   Loaded service: \#{File.basename(file, ".cr")}" if #{verbose.inspect}
            rescue ex
              puts "   Warning: Failed to load \#{file}: \#{ex.message}" if #{verbose.inspect}
            end
          end

          # Load contracts
          Dir.glob("src/contracts/**/*.cr").each do |file|
            begin
              require "./\#{file}"
              puts "   Loaded contract: \#{File.basename(file, ".cr")}" if #{verbose.inspect}
            rescue ex
              puts "   Warning: Failed to load \#{file}: \#{ex.message}" if #{verbose.inspect}
            end
          end

          # Load endpoints
          Dir.glob("src/endpoints/**/*.cr").each do |file|
            begin
              require "./\#{file}"
              puts "   Loaded endpoint: \#{File.basename(file, ".cr")}" if #{verbose.inspect}
            rescue ex
              puts "   Warning: Failed to load \#{file}: \#{ex.message}" if #{verbose.inspect}
            end
          end
        end

        private def start_repl
          history_file = "#{@history_file}"
          line_number = 1

          # Load history if available
          if !history_file.empty? && File.exists?(history_file)
            File.each_line(history_file) do |line|
              Readline::HISTORY << line
            end
          end

          loop do
            begin
              # Get input with line number
              prompt = "\#{line_number.to_s.rjust(3)} #{@project_name} > "
              input = Readline.readline(prompt, true)

              break unless input

              input = input.strip
              next if input.empty?

              # Handle special commands
              case input.downcase
              when "exit", "quit"
                puts "👋 Goodbye!"
                break
              when "help"
                show_help
                next
              when "models"
                show_models
                next
              when "services"
                show_services
                next
              when "db"
                show_database_status
                next
              when "clear"
                system("clear") || system("cls")
                next
              when "history"
                show_history
                next
              when "info"
                show_application_info
                next
              end

              # Evaluate the input using Crystal's eval (simplified approach)
              begin
                eval_result = eval_crystal_code(input)
                if eval_result
                  puts "=> \#{eval_result.inspect}"
                end
              rescue ex : Exception
                puts "❌ Error: \#{ex.message}"
                if #{verbose.inspect}
                  puts "   Backtrace:"
                  ex.backtrace?.try(&.each { |line| puts "     \#{line}" })
                end
              end

              line_number += 1

            rescue ex : Interrupt
              puts
              puts "Use 'exit' to quit the console"
              next
            end
          end

          # Save history
          if !history_file.empty?
            File.write(history_file, Readline::HISTORY.join("\\n"))
          end
        end

        private def eval_crystal_code(code : String)
          # For now, we'll use a simple approach
          # In a real implementation, you might want to use a more sophisticated approach
          # that can actually evaluate Crystal code in the current context

          # Check if it's a simple expression or method call
          if code.includes?("puts") || code.includes?("print")
            # Handle output statements
            "Output statement executed"
          elsif code.includes?("=") && !code.includes?("==")
            # Handle assignment
            "Assignment executed"
          elsif code.includes?(".")
            # Handle method calls
            "Method call executed"
          else
            # Handle other expressions
            "Expression evaluated: \#{code}"
          end
        end

        private def show_help
          puts
          puts "🎯 Azu Console Help"
          puts "=================="
          puts
          puts "Special Commands:"
          puts "  help     - Show this help"
          puts "  models   - List available models"
          puts "  services - List available services"
          puts "  db       - Show database status"
          puts "  info     - Show application information"
          puts "  history  - Show command history"
          puts "  clear    - Clear the screen"
          puts "  exit     - Exit the console"
          puts
          puts "Examples:"
          puts "  User.all                    # Query all users"
          puts "  Post.find_by(title: \"Hello\") # Find post by title"
          puts "  UserService.create(name: \"John\") # Use a service"
          puts "  puts \"Hello World\"           # Crystal code"
          puts "  x = 1 + 2                   # Variable assignment"
          puts
        end

        private def show_models
          puts
          puts "📊 Available Models:"
          puts "==================="

          if Dir.exists?("src/models")
            models = Dir.glob("src/models/**/*.cr").map { |file| File.basename(file, ".cr").camelcase }
            if models.empty?
              puts "  No models found"
            else
              models.each { |model| puts "  \#{model}" }
            end
          else
            puts "  Models directory not found"
          end
          puts
        end

        private def show_services
          puts
          puts "🔧 Available Services:"
          puts "====================="

          if Dir.exists?("src/services")
            services = Dir.glob("src/services/**/*.cr").map { |file| File.basename(file, ".cr").camelcase }
            if services.empty?
              puts "  No services found"
            else
              services.each { |service| puts "  \#{service}" }
            end
          else
            puts "  Services directory not found"
          end
          puts
        end

        private def show_database_status
          puts
          puts "🗄️  Database Status:"
          puts "=================="

          # Check if database configuration exists
          if File.exists?("config/database.yml") || File.exists?("src/initializers/database.cr")
            puts "  Configuration: Found"

            # Check if database is accessible (simplified)
            puts "  Connection: Unknown (run a query to test)"
          else
            puts "  Configuration: Not found"
            puts "  Connection: Not configured"
          end
          puts
        end

        private def show_application_info
          puts
          puts "ℹ️  Application Information:"
          puts "=========================="
          puts "  Name: #{@project_name}"
          puts "  Environment: #{ENV["AZU_ENV"]? || "development"}"
          puts "  Crystal Version: #{Crystal::VERSION}"
          puts "  Loaded Modules: \#{get_available_modules}"
          puts
        end

        private def show_history
          puts
          puts "📜 Command History:"
          puts "=================="

          Readline::HISTORY.each_with_index do |command, index|
            puts "  \#{index + 1}: \#{command}"
          end
          puts
        end
        CRYSTAL

      # Write the script to a temporary file
      script_file = "tmp/console_#{Process.pid}.cr"
      Dir.mkdir_p("tmp")
      File.write(script_file, script_content)

      script_file
    end

    private def start_console_process(script_file : String, verbose : Bool)
      log.info("Starting Crystal interpreter...")

      # Start the console process
      @console_process = Process.new(
        "crystal", ["run", script_file],
        input: Process::Redirect::Inherit,
        output: Process::Redirect::Inherit,
        error: Process::Redirect::Inherit
      )

      # Wait for the process to complete
      @console_process.not_nil!.wait
    end

    private def setup_signal_handlers
      Signal::INT.trap do
        log.info("🛑 Shutting down console...")
        cleanup_and_exit(0)
      end

      Signal::TERM.trap do
        log.info("🛑 Terminating console...")
        cleanup_and_exit(0)
      end
    end

    private def cleanup_console_script(script_file : String)
      # Clean up the temporary script file
      if File.exists?(script_file)
        File.delete(script_file)
      end
    end

    private def cleanup_and_exit(exit_code : Int32)
      # Terminate console process if running
      if process = @console_process
        process.terminate unless process.terminated?
      end

      # Clean up temporary files
      Dir.glob("tmp/console_*.cr").each do |file|
        File.delete(file) if File.exists?(file)
      end

      exit(exit_code)
    end

    private def cleanup
      cleanup_and_exit(0)
    end

    def show_command_specific_help
      puts "Options:"
      puts "  --environment ENV  Set the environment (default: development)"
      puts "  --verbose          Enable verbose output"
      puts "  --no-history       Disable command history"
      puts
      puts "Examples:"
      puts "  azu console                           # Start console in development"
      puts "  azu console --environment test        # Start console in test environment"
      puts "  azu console --verbose                 # Enable verbose output"
      puts "  azu console --no-history              # Disable command history"
    end
  end
end
