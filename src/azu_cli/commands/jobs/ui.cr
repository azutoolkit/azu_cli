require "../jobs"

module AzuCLI::Commands::Jobs
  class UI < Base
    property port : Int32 = 4000
    property host : String = "localhost"
    @path = "lib/joobqui"

    def initialize
      super("jobs:ui", "Start JoobQUI web interface")
    end

    protected def command_options(p : OptionParser)
      p.on("-p PORT", "--port PORT", "HTTP port") { |v| @port = positive(v, 65535) }
      p.on("-h HOST", "--host HOST", "Bind address") { |v| @host = v }
      p.on("--path DIRECTORY", "JoobQUI checkout with installed dependencies") { |v| @path = v }
    end

    def execute : Result
      if result = check
        return result
      end
      root = File.expand_path(@path)
      return usage_error("JoobQUI src/app.cr not found at #{root}; use --path with a configured JoobQUI checkout") unless File.file?(File.join(root, "src/app.cr"))
      env = child_env.merge({"PORT" => @port.to_s, "HOST" => @host})
      ScratchFile.with(".azu_jobs_ui_", "") do |source|
        binary = source + ".bin"
        begin
          compiler = ScratchFile.watch(Process.new("crystal", ["build", "src/app.cr", "-o", binary], chdir: root, env: env, output: STDERR, error: STDERR))
          return Result.error("JoobQUI did not compile") unless compiler.wait.success?
          process = ScratchFile.watch(Process.new(binary, chdir: root, env: env, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit))
          Process.on_terminate { |_| ProcessTree.terminate(process) }
          status = process.wait
          status.success? ? success : Result.error("JoobQUI exited unsuccessfully", status.normal_exit? ? status.exit_code : 1)
        ensure
          File.delete?(binary)
        end
      end
    rescue ex
      Result.error("JoobQUI launch failed (#{ex.class})")
    end
  end
end
