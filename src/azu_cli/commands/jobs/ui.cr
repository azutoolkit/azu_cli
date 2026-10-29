require "../jobs"

module AzuCLI
  module Commands
    module Jobs
      # Start JoobQUI server
      class UI < AzuCLI::Commands::Jobs::Base
        property port : Int32 = 4000
        property host : String = "localhost"

        def initialize
          super("jobs:ui", "Start JoobQUI web interface")
        end

        # Override parse_args to also trigger custom parsing
        def parse_args(args : Array(String))
          super(args)
          parse_options
        end

        def execute : Result
          parse_options

          Logger.info("🚀 Starting JoobQUI server...")
          show_job_info
          Logger.info("UI Server: http://#{@host}:#{@port}")
          puts ""

          start_ui_server

          success("UI server stopped")
        rescue ex
          Logger.info("\n🛑 Stopping UI server...")
          error("UI server error: #{ex.message}")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--port", "-p"
              @port = args[index + 1]?.try(&.to_i) || @port if index + 1 < args.size
            when "--host", "-h"
              @host = args[index + 1]? || @host if index + 1 < args.size
            when "--verbose", "-v"
              @verbose = true
            end
          end
        end

        private def start_ui_server
          # Check if JoobQUI is available
          unless Dir.exists?("lib/joobqui") || Dir.exists?("../joobqui")
            Logger.warn("JoobQUI not found in dependencies")
            Logger.info("Add joobqui to your shard.yml:")
            Logger.info("")
            Logger.info("dependencies:")
            Logger.info("  joobqui:")
            Logger.info("    github: azutoolkit/joobqui")
            Logger.info("")
            raise "JoobQUI is not installed"
          end

          Logger.info("Starting JoobQUI server on http://#{@host}:#{@port}")
          Logger.info("Press Ctrl+C to stop")
          puts ""

          env = {
            "REDIS_URL"    => @redis_url,
            "JOOBQUI_PORT" => @port.to_s,
            "JOOBQUI_HOST" => @host,
          }

          # Start JoobQUI server
          # This assumes JoobQUI has a server entry point
          process = Process.new(
            "crystal",
            ["run", Dir.exists?("lib/joobqui") ? "lib/joobqui/src/joobqui.cr" : "../joobqui/src/joobqui.cr"],
            env: env,
            output: Process::Redirect::Inherit,
            error: Process::Redirect::Inherit
          )

          Logger.info("✓ JoobQUI started (PID: #{process.pid})")
          Logger.info("Open http://#{@host}:#{@port} in your browser")

          status = process.wait
          raise "Child process exited with status #{status.exit_code}" unless status.success?
        rescue ex
          raise "Failed to start JoobQUI: #{ex.message}"
        end
      end
    end
  end
end
