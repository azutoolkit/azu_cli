require "../jobs"

module AzuCLI
  module Commands
    module Jobs
      # Start job workers
      class Worker < AzuCLI::Commands::Jobs::Base
        property workers : Int32 = 1
        property queues : Array(String) = ["default"]
        property daemon : Bool = false

        def initialize
          super("jobs:worker", "Start job workers to process queued jobs")
        end

        # Override parse_args to also trigger custom parsing
        def parse_args(args : Array(String))
          super(args)
          parse_options
        end

        def execute : Result
          parse_options

          Logger.info("🚀 Starting JoobQ workers...")
          show_job_info
          Logger.info("Workers: #{@workers}")
          Logger.info("Queues: #{@queues.join(", ")}")
          Logger.info("Mode: #{@daemon ? "daemon" : "foreground"}")
          puts ""

          start_workers

          success("Workers started")
        rescue ex
          Logger.info("\n🛑 Stopping workers...")
          error("Worker error: #{ex.message}")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--workers", "-w"
              @workers = args[index + 1]?.try(&.to_i) || @workers if index + 1 < args.size
            when "--queues", "-q"
              queues_str = args[index + 1]? if index + 1 < args.size
              @queues = queues_str.split(",").map(&.strip) if queues_str
            when "--daemon", "-d"
              @daemon = true
            when "--verbose", "-v"
              @verbose = true
            end
          end
        end

        private def start_workers
          Logger.info("Starting #{@workers} worker process(es)...")

          # Set environment variables for worker
          env = {
            "REDIS_URL"     => @redis_url,
            "JOOBQ_QUEUES"  => @queues.join(","),
            "JOOBQ_WORKERS" => @workers.to_s,
          }

          # Run the worker process
          # This assumes the application has a worker entry point
          process = Process.new(
            "crystal",
            ["run", "src/worker.cr"],
            env: env,
            output: @verbose ? Process::Redirect::Inherit : Process::Redirect::Pipe,
            error: @verbose ? Process::Redirect::Inherit : Process::Redirect::Pipe
          )

          Logger.info("✓ Workers started (PID: #{process.pid})")
          Logger.info("Press Ctrl+C to stop workers")

          process.wait
        rescue ex
          raise "Failed to start workers: #{ex.message}"
        end
      end
    end
  end
end
