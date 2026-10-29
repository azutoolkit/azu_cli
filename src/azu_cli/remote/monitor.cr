require "../bounded_capture"
require "../process_tree"
require "../integrations/monitor_snapshot"
require "../dev_server/changes"
require "../dev_server/telemetry"

module AzuCLI::Remote
  record Target, host : String, snapshot : String do
    def validate! : Nil
      raise ArgumentError.new("Host or snapshot path is too long") if host.size > 255 || snapshot.size > 4096
      unless host.matches?(/\A(?:[A-Za-z0-9_][A-Za-z0-9_.-]*@)?[A-Za-z0-9][A-Za-z0-9_.-]*\z/)
        raise ArgumentError.new("--ssh must be a host alias or user@hostname; configure ports/jump hosts in ~/.ssh/config")
      end
      unless snapshot.matches?(/\A\/[A-Za-z0-9_\/.:-]+\z/) && !snapshot.split('/').includes?("..")
        raise ArgumentError.new("--snapshot must be an absolute path without spaces, traversal or shell characters")
      end
    end

    def arguments : Array(String)
      validate!
      args = ["-T", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
              "-o", "ForwardAgent=no", "-o", "ForwardX11=no", "-o", "ClearAllForwardings=yes",
              "-o", "PermitLocalCommand=no", "-o", "RemoteCommand=none", "-o", "ControlPath=none", "-o", "SendEnv=-*",
              "-o", "ControlMaster=no", "-o", "ForkAfterAuthentication=no",
              "-o", "ConnectTimeout=5", "-o", "ServerAliveInterval=5", "-o", "ServerAliveCountMax=1",
              "-o", "LogLevel=ERROR"]
      args.concat(["--", host, "cat -- #{Process.quote_posix(snapshot)}"])
    end
  end

  # A fresh SSH invocation per snapshot: no listening port, remote shell UI,
  # command endpoint, agent forwarding, password prompt, or reused master session.
  class Reader
    @process : Process?
    @stopped = false

    def initialize(@target : Target, @executable : String = "ssh", @timeout : Time::Span = 10.seconds)
      @target.validate!
    end

    def read : JSON::Any
      raise IO::Error.new("Disconnected") if @stopped
      output = BoundedCapture.new(AzuMonitor::MAX_BYTES)
      process = Process.new(@executable, @target.arguments, input: Process::Redirect::Close,
        output: Process::Redirect::Pipe, error: Process::Redirect::Close)
      @process = process
      process.signal(Signal::KILL) if @stopped
      done = Channel(Process::Status | Exception).new(1)
      spawn do
        begin
          IO.copy(process.output, output)
          done.send(process.wait)
        rescue ex
          process.signal(Signal::KILL) rescue nil
          process.wait rescue nil
          done.send(ex)
        end
      end
      result = select
      when status = done.receive
        status
      when timeout(@timeout)
        terminate(process)
        select
        when done.receive
        when timeout(1.second)
        end
        raise IO::Error.new("SSH snapshot deadline exceeded")
      end
      raise IO::Error.new("SSH snapshot failed; check host trust, key authorization and file permissions") unless result.is_a?(Process::Status) && result.success?
      raise IO::Error.new("Snapshot exceeds 128 KiB") if output.truncated?
      AzuMonitor::Snapshot.parse(output.text)
    ensure
      @process = nil
    end

    def stop : Nil
      @stopped = true
      @process.try { |process| terminate(process) }
    end

    private def terminate(process : Process) : Nil
      if process.exists?
        ProcessTree.descendants(process.pid).each { |pid| Process.signal(Signal::KILL, pid) rescue nil }
        process.signal(Signal::KILL) rescue nil
      end
      # A proxy child must not keep pipe draining blocked after the deadline.
      process.output.close rescue nil
    end
  end

  class Monitor
    @stopped = false

    def initialize(@reader : Reader, @report : Proc(UI::Message, Nil))
    end

    def start : Nil
      spawn do
        delay = 2
        until @stopped
          wait = 2
          begin
            data = @reader.read
            break if @stopped
            @report.call(DevServer::Events::Telemetry.new(data))
            queues = data["queues"].as_a.map do |row|
              DevServer::Events::Queue.new(row["name"].as_s,
                count(row, "pending"), count(row, "processing"), count(row, "failed"))
            end
            @report.call(DevServer::Events::JobsSample.new(queues))
            @report.call(DevServer::Events::RemoteStatus.new("SSH verified · snapshot current", true))
            delay = 2
          rescue
            break if @stopped
            # Do not expose raw remote stderr, malformed payloads or credentials.
            @report.call(DevServer::Events::RemoteStatus.new("unavailable · check SSH trust, access and snapshot freshness · retry #{delay}s", false))
            wait = delay
            delay = Math.min(delay * 2, 30)
          end
          sleep wait.seconds
        end
      end
    end

    private def count(row : JSON::Any, key : String) : Int64
      value = row[key]?
      value.try(&.as_i64?) || value.try(&.as_f?).try(&.to_i64) || 0_i64
    end

    def stop : Nil
      @stopped = true
      @reader.stop
    end
  end
end
