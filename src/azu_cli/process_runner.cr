module AzuCLI
  class ProcessRunner
    FILE_TIMESTAMPS = {} of String => String # {file => timestamp}

    getter app_process : (Nil | Process) = nil
    property display_name : String
    property should_build = true
    property files = [] of String

    def initialize(
      @display_name : String,
      @build_command : String,
      @run_command : String,
      @build_args : Array(String) = [] of String,
      @run_args : Array(String) = [] of String,
      files = [] of String,
      should_build = true,
      install_shards = false,
      colorize = true
    )
      @files = files
      @should_build = should_build
      @should_kill = false
      @app_built = false
      @should_install_shards = install_shards
      @colorize = colorize
    end

    private def stdout(str : String)
      if @colorize
        puts str.colorize.fore(:yellow)
      else
        puts str
      end
    end

    private def build_app_process
      stdout "🤖  compiling #{display_name}..."
      build_args = @build_args
      if build_args.size > 0
        Process.run(@build_command, build_args, shell: true, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
      else
        Process.run(@build_command, shell: true, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
      end
    end

    private def create_app_process
      app_process = @app_process
      if app_process.is_a? Process
        unless app_process.terminated?
          stdout "🤖  killing #{display_name}..."
          app_process.terminate
          app_process.wait
        end
      end

      stdout "🤖  starting #{display_name}..."
      run_args = @run_args
      if run_args.size > 0
        @app_process = Process.new(@run_command, run_args, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
      else
        @app_process = Process.new(@run_command, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
      end
    end

    private def get_timestamp(file : String)
      File.info(file).modification_time.to_unix.to_s
    end

    # Compiles and starts the application
    #
    def start_app
      return create_app_process unless @should_build
      build_result = build_app_process()
      if build_result && build_result.success?
        @app_built = true
        create_app_process()
      elsif !@app_built # if build fails on first time compiling, then exit
        stdout "🤖 Compile time errors detected."
        exit 1
      end
    end

    # Scans all of the `@files`
    #
    def scan_files
      file_changed = false
      app_process = @app_process
      files = @files
      begin
        Dir.glob(files) do |file|
          timestamp = get_timestamp(file)
          if FILE_TIMESTAMPS[file]? && FILE_TIMESTAMPS[file] != timestamp
            FILE_TIMESTAMPS[file] = timestamp
            file_changed = true
            stdout "🤖  #{file}"
          elsif FILE_TIMESTAMPS[file]?.nil?
            FILE_TIMESTAMPS[file] = timestamp
            file_changed = true if (app_process && !app_process.terminated?)
          end
        end
      rescue ex
        # The underlining lib for reading directories will fail very rarely, crashing Sentry
        # This catches that error and allows Sentry to carry on normally
        # https://github.com/crystal-lang/crystal/blob/59788834554399f7fe838487a83eb466e55c6408/src/errno.cr#L37
        unless ex.message == "readdir: Input/output error"
          raise ex
        end
      end

      start_app() if (file_changed || app_process.nil?)
    end

    def run_install_shards
      stdout "🤖 Installing shards..."
      install_result = Process.run("shards", ["install"], shell: true, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
      if !install_result || !install_result.success?
        stdout "🤖  Error installing shards. SentryBot shutting down..."
        exit 1
      end
    end

    def run
      stdout "🤖 Tracking file changes"

      run_install_shards if @should_install_shards

      loop do
        if @should_kill
          stdout "🤖  Powering down service..."
          break
        end
        scan_files
        sleep 1
      end
    end

    def kill
      @should_kill = true
    end
  end
end
