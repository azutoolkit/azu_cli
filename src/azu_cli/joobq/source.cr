require "json"
require "../scratch_file"

module AzuCLI::JoobQDashboard
  abstract class Source
    abstract def snapshot : JSON::Any
    abstract def replay(id : String) : JSON::Any
    abstract def close : Nil
  end

  # A dedicated application process supplies the typed runtime/store integration.
  # The TUI never imports app job classes, invents storage keys, or performs SQL DML.
  class ProcessSource < Source
    PROTOCOL  = {{ read_file("#{__DIR__}/../integrations/joobq_protocol.cr") }}
    AGENT     = {{ read_file("#{__DIR__}/../integrations/joobq_agent.cr") }}
    MAX_REPLY = 1_048_576
    @process : Process
    @replies = Channel(String | Exception).new(1)
    @closed = false

    def self.script(boot : String) : String
      relative = Path[File.expand_path(boot)].relative_to(Dir.current).to_s
      "#{PROTOCOL}\nrequire #{("./" + relative).inspect}\n#{AGENT}"
    end

    def self.open(boot : String, output : IO = STDERR, & : ProcessSource -> T) : T forall T
      ScratchFile.with(".azu_joobq_", script(boot)) do |path|
        binary = path + ".bin"
        begin
          # Compilation precedes the alternate-screen session; errors remain readable.
          compiler = ScratchFile.watch(Process.new("crystal", ["build", path, "-o", binary], output: output, error: output))
          status = compiler.wait
          raise "Could not compile the project's JoobQ adapter" unless status.success?
          source = new(binary)
          yield source
        ensure
          source.try(&.close)
          File.delete?(binary)
        end
      end
    end

    def initialize(binary : String)
      @process = ScratchFile.watch(Process.new(binary, input: Process::Redirect::Pipe, output: Process::Redirect::Pipe, error: Process::Redirect::Close))
      spawn do
        begin
          while line = @process.output.gets('\n', MAX_REPLY + 1)
            raise IO::Error.new("JoobQ snapshot exceeds 1 MiB") if line.bytesize > MAX_REPLY
            @replies.send(line.lchop("AZU_JOOBQ:")) if line.starts_with?("AZU_JOOBQ:")
          end
          @replies.send(IO::Error.new("JoobQ adapter exited"))
        rescue ex
          @replies.send(ex) unless @closed
        end
      end
    end

    def snapshot : JSON::Any
      request({action: "snapshot"}.to_json)
    end

    def replay(id : String) : JSON::Any
      request({action: "replay", id: id}.to_json)
    end

    private def request(body : String) : JSON::Any
      raise IO::Error.new("JoobQ adapter is closed; restart the dashboard") if @closed
      @process.input.puts body
      @process.input.flush
      select
      when reply = @replies.receive
        raise reply if reply.is_a?(Exception)
        parsed = JSON.parse(reply)
        raise IO::Error.new(parsed["error"].as_s) unless parsed["ok"].as_bool
        parsed["data"]
      when timeout(5.seconds)
        close
        raise IO::TimeoutError.new("JoobQ operation timed out; outcome unknown. Refresh state before replaying again")
      end
    end

    def close : Nil
      return if @closed
      @closed = true
      @replies.close
      ProcessTree.terminate(@process)
      @process.input.close rescue nil
      @process.output.close rescue nil
    end
  end
end
