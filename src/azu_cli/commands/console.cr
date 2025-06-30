require "../command"
require "process"
require "file_utils"

module AzuCLI::Commands
  # Console command - provides interactive REPL for Azu applications
  class Console < Command
    command_name "console"
    description "Start interactive console with full application context"
    usage "console [options]"

    @project_name : String?
    @main_file : String?
    @console_process : Process?

    def execute(args : Hash(String, String | Array(String))) : String | Nil
      require_project_root!

      # Parse command line arguments
      environment = get_flag(args, "environment", "development")
      verbose = has_flag?(args, "verbose") || config.verbose

      # Get project information
      @project_name = get_project_name
      @main_file = "src/#{@project_name}.cr"

      log.info("🚀 Starting Azu Console...")
      log.info("   Project: #{@project_name}")
      log.info("   Environment: #{environment}")
      log.info("   Main file: #{@main_file}")

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

      # Set environment variable
      ENV["AZU_ENV"] = environment

      log.info("Starting Crystal interactive mode...")
      log.info("Environment: #{environment}")
      log.info("Loading: #{@main_file}")

      # Start Crystal's interactive mode with the main file
      start_crystal_interactive(verbose)
    end

    private def start_crystal_interactive(verbose : Bool)
      # Show welcome message
      puts
      puts "💎 Azu Console (Crystal Interactive Mode)"
      puts "========================================="
      puts "Environment: #{ENV["AZU_ENV"]? || "development"}"
      puts "Project: #{@project_name}"
      puts "Main file: #{@main_file}"
      puts
      puts "💡 Console Tips:"
      puts "   • Type Crystal code directly"
      puts "   • Use pp(object) to pretty print"
      puts "   • Use exit or Ctrl+D to quit"
      puts "   • Press Ctrl+C to interrupt"
      puts

      # Create temporary console script
      console_script = create_console_script

      begin
        # Start Crystal's interactive mode with the console script
        @console_process = Process.new(
          "crystal", ["i", console_script],
          input: Process::Redirect::Inherit,
          output: Process::Redirect::Inherit,
          error: Process::Redirect::Inherit
        )

        # Wait for the process to complete
        @console_process.not_nil!.wait
      ensure
        # Clean up the temporary console script
        cleanup_console_script(console_script)
      end
    end

    private def create_console_script : String
      # Create console script content
      script_content = <<-CRYSTAL
        # Minimal Azu Console Entry Point
        # This file loads only essential dependencies to avoid Crystal REPL issues

        require "log"

        # Set up basic environment
        ENV["AZU_ENV"] ||= "#{ENV["AZU_ENV"]? || "development"}"

        # Basic project detection
        def project_name
          if File.exists?("shard.yml")
            content = File.read("shard.yml")
            if match = content.match(/^name:\\s*(.+)$/)
              match[1].strip
            else
              File.basename(Dir.current)
            end
          else
            File.basename(Dir.current)
          end
        end

        def project_root
          Dir.current
        end

        # Set up basic logging
        Log.setup(:info)

        # Welcome message
        puts
        puts "💎 Azu Console"
        puts "=============="
        puts "Environment: \#{ENV["AZU_ENV"]}"
        puts "Project: \#{project_name}"
        puts "Directory: \#{project_root}"
        puts

        # Check if project's main file exists
        main_file = "src/\#{project_name}.cr"
        if File.exists?(main_file)
          puts "📁 Main project file found: \#{main_file}"
          puts "   Note: To load your project code, you can manually require it:"
          puts "   require \"./\#{main_file}\""
        else
          puts "⚠️  Main project file not found: \#{main_file}"
        end

        puts "   Crystal REPL is ready for your code!"

        puts
        puts "💡 Console Tips:"
        puts "   • Type Crystal code directly"
        puts "   • Use pp(object) to pretty print"
        puts "   • Access ENV[\\"AZU_ENV\\"] for environment"
        puts "   • Use exit or Ctrl+D to quit"
        puts

        # Helper functions available in console
        def reload!
          puts "🔄 Note: Crystal doesn't support dynamic reloading"
          puts "   You'll need to exit and restart the console to reload changes"
          puts "   Tip: Use 'exit' then run 'azu console' again"
        end

        def info
          puts
          puts "📊 Project Information:"
          puts "   Name: \#{project_name}"
          puts "   Environment: \#{ENV["AZU_ENV"]}"
          puts "   Crystal Version: \#{Crystal::VERSION}"
          puts "   Directory: \#{project_root}"
          puts
        end

        # Make helper functions available
        puts "Available helpers: info, reload!, project_name"
        puts
        CRYSTAL

      # Write the script to a temporary file
      Dir.mkdir_p("tmp")
      script_file = "tmp/azu_console_#{Process.pid}.cr"
      File.write(script_file, script_content)
      script_file
    end

    private def cleanup_console_script(script_file : String)
      # Clean up the temporary script file
      if File.exists?(script_file)
        File.delete(script_file)
      end
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

    private def cleanup_and_exit(exit_code : Int32)
      # Terminate console process if running
      if process = @console_process
        process.terminate unless process.terminated?
      end

      # Clean up any temporary console scripts
      Dir.glob("tmp/azu_console_*.cr").each do |file|
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
      puts
      puts "Examples:"
      puts "  azu console                           # Start console in development"
      puts "  azu console --environment test        # Start console in test environment"
      puts "  azu console --verbose                 # Enable verbose output"
    end
  end
end
