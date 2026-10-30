require "./base"
require "../scratch_file"
require "uri"
require "json"

module AzuCLI::Commands::Jobs
  # Load the application's own JoobQ version; mutations belong to its operator API.
  abstract class Base < Commands::Base
    property redis_url : String = ENV["REDIS_URL"]? || ENV["JOOBQ_REDIS_URL"]? || "redis://localhost:6379"
    property queue : String = ENV["JOOBQ_QUEUE"]? || "default"
    property verbose : Bool = false
    property boot : String = "src/initializers/joobq.cr"
    property json : Bool = false
    property dry_run : Bool = false
    property force : Bool = false
    @explicit_queue = false
    @redis_override = false
    @parse_error : String?
    @help = false
    @environment : String?
    @parser : OptionParser?
    ADAPTER = {{ read_file("#{__DIR__}/../integrations/jobs_operator.cr") }}

    def parse_args(args : Array(String))
      super(args)
      @parse_error = nil
      parser = OptionParser.new do |p|
        p.banner = "Usage: azu #{name} [options]"
        p.on("--redis URL", "Redis URL override (prefer REDIS_URL for credentials)") { |v| @redis_url = v; @redis_override = true }
        p.on("--boot FILE", "Application boot file; must not start a server") { |v| @boot = v }
        p.on("-e NAME", "--env NAME", "Configuration environment") { |v| @environment = v }
        p.on("--json", "Print machine-readable results") { @json = true } unless {"jobs:worker", "jobs:ui"}.includes?(name)
        p.on("-v", "--verbose", "Show diagnostics") { @verbose = true }
        if name == "jobs:ui"
          p.on("--help", "Show command help") { @help = true }
        else
          p.on("-h", "--help", "Show command help") { @help = true }
        end
        command_options(p)
        p.unknown_args { |before, after| raise OptionParser::InvalidOption.new((before + after).join(" ")) unless before.empty? && after.empty? }
      end
      @parser = parser
      parser.parse(args.dup)
    rescue ex : OptionParser::Exception | ArgumentError
      @parse_error = ex.message
    end

    protected def command_options(p : OptionParser)
      queue_option(p)
    end

    protected def queue_option(p : OptionParser)
      p.on("-q NAME", "--queue NAME", "Queue name (default: #{@queue})") { |v| @queue = v; @explicit_queue = true }
    end

    protected def mutation_options(p : OptionParser)
      p.on("-f", "--force", "Confirm mutation without prompting") { @force = true }
      p.on("--dry-run", "Preview without modifying jobs") { @dry_run = true }
    end

    protected def positive(value : String, maximum = 1000) : Int32
      number = value.to_i?
      raise ArgumentError.new("Expected an integer between 1 and #{maximum}") unless number && 1 <= number <= maximum
      number
    end

    protected def check : Result?
      if @help
        stdout.puts @parser
        return success
      end
      if message = @parse_error
        return usage_error(message)
      end
      return usage_error("Queue name must not be empty") if @queue.strip.empty?
      uri = URI.parse(@redis_url)
      return usage_error("Redis URL must use redis:// or rediss:// with a host") unless {"redis", "rediss"}.includes?(uri.scheme) && uri.host.presence
      nil
    rescue URI::Error
      usage_error("Invalid Redis URL")
    end

    def machine_output? : Bool
      @json
    end

    protected def confirmed? : Bool
      return true if @force || @dry_run
      return false unless STDIN.tty?
      STDERR.print "Confirm #{name} for #{@queue}? [y/N]: "
      STDIN.gets.try(&.strip.downcase) == "y"
    end

    protected def child_env : Hash(String, String)
      env = {} of String => String
      # Preserve the app's host/port configuration unless a URL is actually selected.
      if @redis_override || ENV["REDIS_URL"]? || ENV["JOOBQ_REDIS_URL"]?
        env["REDIS_URL"] = @redis_url
      end
      if environment = @environment
        env["CRYSTAL_ENV"] = environment
        env["JOOBQ_ENV"] = environment
      end
      env
    end

    protected def operate(action : String, payload : String, release = false) : Result
      return usage_error("Boot file #{@boot} not found; use --boot src/<app>.cr or generate joobq") unless File.file?(@boot)
      relative = Path[File.expand_path(@boot)].relative_to(Dir.current).to_s
      script = "require #{("./" + relative).inspect}\n#{ADAPTER}"
      ScratchFile.with(".azu_jobs_", script) do |source|
        binary = source + ".bin"
        begin
          args = ["build", source, "-o", binary]
          args << "--release" if release
          args << "--error-trace" if @verbose
          compiler = ScratchFile.watch(Process.new("crystal", args, env: child_env, output: STDERR, error: STDERR))
          return Result.error("JoobQ adapter did not compile", 1) unless compiler.wait.success?
          input = IO::Memory.new(payload)
          output = IO::Memory.new
          process = ScratchFile.watch(Process.new(binary, [action], env: child_env, input: input,
            output: action == "worker" ? Process::Redirect::Inherit : output, error: STDERR))
          # Wait for the worker's own graceful shutdown rather than exiting before it drains.
          Process.on_terminate { |_| ProcessTree.terminate(process) }
          status = process.wait
          return Result.error("JoobQ #{action} failed; inspect diagnostics", status.normal_exit? ? status.exit_code : 1) unless status.success?
          unless action == "worker"
            line = output.to_s.lines.find(&.starts_with?("AZU_JOBS:"))
            return Result.error("JoobQ adapter returned no result") unless line
            data = JSON.parse(line.lchop("AZU_JOBS:"))
            stdout.puts(@json ? data.to_json : data.to_pretty_json)
            if data["missing"]?.try(&.as_a.any?) || data["unredrivable"]?.try(&.as_a.any?) || data["conflicted"]?.try(&.as_a.any?)
              return Result.error("Some jobs were not changed; inspect the result")
            end
          end
          success
        ensure
          File.delete?(binary)
        end
      end
    rescue ex
      Result.error("JoobQ operation failed (#{ex.class}); check configuration and connectivity")
    end
  end
end
