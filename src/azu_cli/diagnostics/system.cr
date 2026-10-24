require "socket"

module AzuCLI
  module Diagnostics
    # Free, taken by another process, or not allowed to this user (ports below 1024).
    enum PortState
      Free
      InUse
      Denied
    end

    # What the checks need from the machine; replaced in specs.
    abstract class System
      # Runs a command and returns its exit code and combined output, or nil when it cannot be started.
      abstract def capture(command : String, args : Array(String), chdir : String) : {Int32, String}?
      abstract def tcp_reachable?(host : String, port : Int32, timeout : Time::Span) : Bool
      abstract def port_state(port : Int32) : PortState
    end

    class LocalSystem < System
      def capture(command : String, args : Array(String), chdir : String) : {Int32, String}?
        output = IO::Memory.new
        status = Process.run(command, args, chdir: chdir, output: output, error: output)
        {status.normal_exit? ? status.exit_code : 128, output.to_s} # 128: ended by a signal
      rescue IO::Error
        nil
      end

      def tcp_reachable?(host : String, port : Int32, timeout : Time::Span) : Bool
        TCPSocket.new(host, port, connect_timeout: timeout).close
        true
      rescue Socket::Error | IO::Error
        false
      end

      def port_state(port : Int32) : PortState
        TCPServer.new("0.0.0.0", port).close
        PortState::Free
      rescue error : Socket::Error | IO::Error
        error.os_error == Errno::EACCES ? PortState::Denied : PortState::InUse
      end
    end
  end
end
