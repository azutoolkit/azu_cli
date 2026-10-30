require "json"
require "yaml"
require "socket"
require "redis"
require "../ui"

module AzuCLI
  module DevServer
    # What `azu dev` tells its dashboard. Each is a message on the dashboard's event channel.
    module Events
      struct RemoteStatus < UI::Message
        getter message : String
        getter connected : Bool

        def initialize(@message : String, @connected : Bool)
        end
      end

      struct BuildStarted < UI::Message
        getter files : Array(String)

        def initialize(@files : Array(String) = [] of String)
        end
      end

      # A line of compiler output (`--progress` lines included).
      struct BuildLine < UI::Message
        getter line : String

        def initialize(@line : String)
        end
      end

      struct BuildFinished < UI::Message
        getter success : Bool
        getter seconds : Float64
        getter output : String

        def initialize(@success : Bool, @seconds : Float64, @output : String)
        end
      end

      struct AppStarted < UI::Message
        getter pid : Int64?

        def initialize(@pid : Int64?)
        end
      end

      struct AppExited < UI::Message
        getter description : String

        def initialize(@description : String)
        end
      end

      struct Changed < UI::Message
        getter files : Array(String)
        getter action : Action

        def initialize(@files : Array(String), @action : Action)
        end
      end

      struct LogLine < UI::Message
        getter line : String
        getter error : Bool

        def initialize(@line : String, @error : Bool = false)
        end
      end

      struct RssSample < UI::Message
        getter app : Int64?
        getter cli : Int64?

        def initialize(@app : Int64?, @cli : Int64?)
        end
      end

      record Queue, name : String, pending : Int64, processing : Int64, failed : Int64, completed : Int64? = nil

      struct JobsSample < UI::Message
        getter queues : Array(Queue)
        getter error : String?

        def initialize(@queues : Array(Queue), @error : String? = nil)
        end
      end

      # One snapshot from the app (`azu/dev` with AZU_TELEMETRY_SOCKET), kept as JSON so a newer or older app
      # degrades to missing fields instead of a parse error.
      struct Telemetry < UI::Message
        getter data : JSON::Any

        def initialize(@data : JSON::Any)
        end
      end
    end

    # Where the compiler is: `[13/14] [120/385] Codegen (bc+obj)` from `crystal build --progress`.
    record CompilerProgress, step : Int32, steps : Int32, stage : String, done : Int32? = nil, total : Int32? = nil do
      PATTERN = /\[(\d+)\/(\d+)\](?:\s+\[(\d+)\/(\d+)\])?\s+(\S.*?)\s*\z/

      def self.parse(line : String) : CompilerProgress?
        match = PATTERN.match(line.strip)
        return unless match

        new(match[1].to_i, match[2].to_i, match[5], match[3]?.try(&.to_i), match[4]?.try(&.to_i))
      end

      # 0.0 to 1.0 over the whole build.
      def fraction : Float64
        within = (done && total && total.not_nil! > 0) ? done.not_nil! / total.not_nil! : 0.0
        ((step - 1) + within) / steps
      end

      # parse, semantic or codegen.
      def phase : String
        return "parse" if stage.starts_with?("Parse")
        return "semantic" if stage.starts_with?("Semantic")
        "codegen"
      end
    end

    # The part of a failed build's output worth showing: the location and the error.
    record CompilerError, file : String?, line : Int32?, column : Int32?, excerpt : Array(String) do
      LOCATION = /^In (\S+?):(\d+):(\d+)/

      def self.parse(output : String) : CompilerError
        lines = output.gsub('\r', '\n').lines.map(&.rstrip).reject { |line| line.empty? || CompilerProgress.parse(line) }
        start = lines.rindex { |line| line.matches?(LOCATION) }
        match = start.try { |index| LOCATION.match(lines[index]) }
        excerpt = start ? lines[start..] : lines.last(12)
        new(match.try(&.[1]), match.try(&.[2].to_i), match.try(&.[3].to_i), excerpt.first(16))
      end

      def location : String?
        file.try { |path| "#{path}:#{line}:#{column}" }
      end

      def message : String
        excerpt.find(&.starts_with?("Error:")).try(&.lchop("Error:").strip) || excerpt.last? || "the build failed"
      end
    end

    # Splits what is written to it into lines (on \n and on the \r the compiler's progress uses) and hands each over.
    class LineSink < IO
      @buffer = IO::Memory.new

      def initialize(&@on_line : String ->)
      end

      def read(slice : Bytes) : Int32
        raise IO::Error.new("write-only")
      end

      def write(slice : Bytes) : Nil
        slice.each do |byte|
          if byte == '\n'.ord || byte == '\r'.ord
            flush_line
          else
            @buffer.write_byte(byte)
          end
        end
      end

      def flush_line : Nil
        return if @buffer.empty?

        line = String.new(@buffer.to_slice)
        @buffer.clear
        @on_line.call(line) unless line.blank?
      end
    end

    # Resident memory of a process, in bytes; nil where it cannot be read.
    module Memory
      PAGE_SIZE = 4096_i64

      def self.rss(pid : Int64) : Int64?
        statm = "/proc/#{pid}/statm"
        if File.exists?(statm)
          File.read(statm).split[1]?.try(&.to_i64?).try { |pages| pages * PAGE_SIZE }
        else
          output = `ps -o rss= -p #{pid.to_i} 2>/dev/null`.strip
          output.to_i64?.try { |kb| kb * 1024 }
        end
      rescue File::Error | IO::Error
        nil
      end
    end

    # The app connects to this socket (AZU_TELEMETRY_SOCKET) and writes one JSON snapshot per line.
    class TelemetryServer
      getter path : String
      @server : UNIXServer?
      @clients = Set(UNIXSocket).new
      MAX_SNAPSHOT = 1_048_576
      MAX_CLIENTS  =         4

      # The socket lives in a directory only this user can enter, so no one else can connect, even in the moment
      # between creating the socket and restricting it.
      def initialize(@directory : String = File.join(Dir.tempdir, "azu-dev-#{Process.pid}-#{Random::Secure.hex(4)}"))
        @path = File.join(@directory, "telemetry.sock")
      end

      def start(&on_snapshot : JSON::Any ->) : Nil
        Dir.mkdir_p(@directory, 0o700)
        File.chmod(@directory, 0o700)
        File.delete?(path)
        server = UNIXServer.new(path)
        File.chmod(path, 0o600)
        @server = server
        spawn do
          while client = server.accept?
            if @clients.size >= MAX_CLIENTS
              client.close
            else
              @clients << client
              client.read_timeout = 5.seconds
              spawn read(client, on_snapshot)
            end
          end
        end
      end

      private def read(client : UNIXSocket, on_snapshot : JSON::Any ->) : Nil
        while line = client.gets('
', MAX_SNAPSHOT + 1)
          break if line.bytesize > MAX_SNAPSHOT
          snapshot = JSON.parse(line) rescue nil
          on_snapshot.call(snapshot.not_nil!) if snapshot && self.class.valid_snapshot?(snapshot)
        end
      rescue IO::Error
      ensure
        @clients.delete(client)
        client.close rescue nil
      end

      # Legacy overview cards expect objects; reject incompatible shapes at the boundary.
      def self.valid_snapshot?(snapshot : JSON::Any) : Bool
        root = snapshot.as_h?
        return false unless root && root["v"]?.try(&.as_i?) == 1
        if stream = root["stream"]?
          return false unless stream.as_s? == "auth" && root["auth"]?.try(&.as_h?)
        end
        %w(requests sql runtime auth dashboard database).each do |key|
          value = root[key]?
          next if value.nil? || value.raw.nil?
          fields = value.as_h?
          return false unless fields
          %w(recent slowest n_plus_one).each do |list|
            next unless rows = fields[list]?
            entries = rows.as_a?
            return false unless entries && entries.all?(&.as_h?)
          end
          if pool = fields["pool"]?
            return false unless pool.raw.nil? || pool.as_h?
          end
        end
        true
      end

      def stop : Nil
        @server.try(&.close) rescue nil
        @clients.to_a.each { |client| client.close rescue nil }
        @clients.clear
        File.delete?(path)
        Dir.delete(@directory) rescue nil
      end
    end

    # Read-only metrics for JoobQ's legacy Queue/Worker API. Redis connectivity
    # does not establish worker liveness. Delivery has a separate ledger.
    class JobsSampler
      def self.queues(config : String? = nil) : Array(String)
        environment = ENV["JOOBQ_ENV"]? || ENV["RACK_ENV"]? || ENV["CRYSTAL_ENV"]? || "development"
        config ||= ["config/joobq.#{environment}.yml", "joobq.yml", "config/joobq.yml", "config/jobs.yml"].find { |path| File.exists?(path) }
        return [] of String unless config && File.exists?(config)

        yaml = YAML.parse(File.read(config))
        yaml["joobq"]?.try(&.["queues"]?).try(&.as_h?).try(&.keys.map(&.as_s)) || [] of String
      rescue YAML::ParseException
        [] of String
      end

      def initialize(@queues : Array(String), @url : String? = ENV["REDIS_URL"]?)
      end

      def sample : Events::JobsSample
        redis = Redis.new(url: @url, host: ENV["REDIS_HOST"]? || "localhost",
          port: (ENV["REDIS_PORT"]? || "6379").to_i, password: ENV["REDIS_PASS"]?,
          connect_timeout: 1.second, command_timeout: 1.second)
        counts = redis.pipelined do |pipeline|
          @queues.each do |queue|
            pipeline.llen(queue)
            pipeline.llen("joobq:processing:#{queue}")
            pipeline.hget("joobq:dead_letter:counts", queue)
            pipeline.hget("joobq:stats:completed", queue)
          end
        end
        queues = @queues.each_with_index.map do |(name, index)|
          Events::Queue.new(name, counts[index * 4].as(Int64), counts[index * 4 + 1].as(Int64),
            counts[index * 4 + 2].as(String?).try(&.to_i64) || 0_i64,
            counts[index * 4 + 3].as(String?).try(&.to_i64) || 0_i64)
        end.to_a
        Events::JobsSample.new(queues)
      rescue ex
        # Do not expose connection credentials or raw exception payloads in the UI.
        Events::JobsSample.new([] of Events::Queue, "JoobQ metrics unavailable; check Redis connection and key types")
      ensure
        redis.try(&.close)
      end
    end
  end
end
