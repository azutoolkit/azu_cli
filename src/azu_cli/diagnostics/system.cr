require "socket"

module AzuCLI
  module Diagnostics
    # What the checks need from the machine; replaced in specs.
    abstract class System
      # Runs a command and returns its exit code and combined output, or nil when it cannot be started.
      abstract def capture(command : String, args : Array(String), chdir : String) : {Int32, String}?
      abstract def tcp_reachable?(host : String, port : Int32, timeout : Time::Span) : Bool
      abstract def port_free?(port : Int32) : Bool
    end

    class LocalSystem < System
      def capture(command : String, args : Array(String), chdir : String) : {Int32, String}?
        output = IO::Memory.new
        status = Process.run(command, args, chdir: chdir, output: output, error: output)
        {status.exit_code, output.to_s}
      rescue IO::Error
        nil
      end

      def tcp_reachable?(host : String, port : Int32, timeout : Time::Span) : Bool
        TCPSocket.new(host, port, connect_timeout: timeout).close
        true
      rescue Socket::Error | IO::Error
        false
      end

      def port_free?(port : Int32) : Bool
        TCPServer.new("0.0.0.0", port).close
        true
      rescue Socket::Error | IO::Error
        false
      end
    end
  end
end
