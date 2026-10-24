require "./base"

module AzuCLI
  module Commands
    # Opens Crystal's interpreter (`crystal i`) with the application loaded.
    #
    # Crystal has no REPL of its own besides the interpreter, which is an optional part of the compiler: the
    # official Docker images and some packages are built without it. When it is missing the command
    # says so and exits with 2 instead of pretending.
    class Console < Base
      OPTIONS = [] of String

      # How the command reaches the outside world; replaced in specs.
      abstract class Environment
        abstract def interpreter? : Bool
        abstract def run_interpreter(script : String, dir : String) : Int32
      end

      class SystemEnvironment < Environment
        # `crystal i --help` of a compiler built without the interpreter says so and fails.
        def interpreter? : Bool
          output = IO::Memory.new
          status = Process.run("crystal", ["i", "--help"], output: output, error: output)
          status.success? && !output.to_s.includes?("without interpreter support")
        rescue File::NotFoundError | IO::Error
          false
        end

        def run_interpreter(script : String, dir : String) : Int32
          Process.run("crystal", ["i", script], chdir: dir, input: Process::Redirect::Inherit, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit).exit_code
        end
      end

      class_property environment : Environment = SystemEnvironment.new

      def initialize
        super("console", "Open Crystal's interpreter with the application loaded")
      end

      def execute : Result
        return show_help_result if has_option?("help")
        if option = unknown_option(OPTIONS)
          return usage_error("Unknown option #{option}. Run 'azu console --help'")
        end

        app_file = "./src/#{Utils.project_name}.cr"
        return Result.error("#{app_file} not found: run 'azu console' in the root of an Azu project") unless File.exists?(app_file)
        return unavailable unless self.class.environment.interpreter?

        run_console(app_file)
      end

      # What the scratch file does: load the app (without starting its server) and stop in the interpreter.
      def script(app_file : String) : String
        <<-CRYSTAL
          require #{app_file.inspect}

          puts #{"Azu console: #{Utils.project_module_name} is loaded. Type Crystal code; `exit` leaves.".inspect}
          debugger
        CRYSTAL
      end

      private def run_console(app_file : String) : Result
        path = File.join(Dir.current, ".azu_console_#{Process.pid}.cr")
        File.write(path, script(app_file))
        code = self.class.environment.run_interpreter(path, Dir.current)
        code.zero? ? success : Result.error("the interpreter exited with #{code}", code)
      ensure
        File.delete(path) if path && File.exists?(path)
      end

      private def unavailable : Result
        Logger.info("Install a Crystal that includes it (the packages from crystal-lang.org/install and Homebrew do; the official Docker images do not),")
        Logger.info("check with 'crystal i --help', then run 'azu console' again.")
        Logger.info("Meanwhile 'azu routes' lists the routes and 'crystal run' of a script that requires ./src/#{Utils.project_name} runs code with the app loaded.")
        Result.error("this Crystal has no interpreter (crystal i), so 'azu console' cannot open a REPL", AzuCLI::Config::EXIT_INVALID_USAGE)
      end

      private def show_help_result : Result
        show_help
        success
      end

      def show_help
        stdout.puts <<-HELP
          Usage: azu console

          Loads the application (its server is not started) in Crystal's interpreter, `crystal i`, and stops
          at a prompt where you can run Crystal code against it. `exit` leaves. Loading the application runs the
          top-level code of src/<project>.cr (initializers, .env loading, database connections), and what you
          type runs against whatever the environment points at: do not use it against production by accident.

          This is the interpreter, not a Rails-style console. Its limits:
            * It needs a Crystal built with the interpreter (`crystal i --help` must work). The official
              Docker images are built without it; this command then exits with 2 and says so.
            * Code that links native libraries (SQLite, OpenSSL) runs only if the shared libraries are installed.
            * The interpreter is slower than compiled code and does not support every Crystal feature.
            * Nothing is reloaded: restart the console after changing code.

          Options:
            --help   Show this help

          Exit codes: 0 the session ended, 1 the interpreter failed, 2 the interpreter is not available or invalid usage.
        HELP
        stdout.puts
        stdout.puts "Examples:"
        show_examples
      end

      def show_examples
        stdout.puts "  azu console"
      end
    end
  end
end
