require "../jobs"

module AzuCLI::Commands::Jobs
  class Worker < Base
    property workers : Int32 = 1
    property queues : Array(String) = ["default"]
    property daemon : Bool = false
    @workers_selected = false
    @queues_selected = false
    @release = false
    @api = false
    @shutdown_timeout = 25

    def initialize
      super("jobs:worker", "Start job workers to process queued jobs")
    end

    protected def command_options(p : OptionParser)
      p.on("-w N", "--workers N", "Workers per queue (1..1000); otherwise preserve configuration") { |v| @workers = positive(v); @workers_selected = true }
      p.on("-q LIST", "--queues LIST", "Comma-separated queue selection; otherwise all configured queues") { |v| @queues = v.split(',').map(&.strip); @queues_selected = true }
      p.on("-d", "--daemon", "Unsupported: use a service supervisor") { @daemon = true }
      p.on("--release", "Compile an optimized worker") { @release = true }
      p.on("--api", "Enable management API; requires JoobQ tokens") { @api = true }
      p.on("--shutdown-timeout SECONDS", "Graceful drain timeout (1..3600, default 25)") { |v| @shutdown_timeout = positive(v, 3600) }
    end

    def execute : Result
      if result = check
        return result
      end
      return usage_error("--daemon is unsupported; use systemd, Docker or another service supervisor") if @daemon
      return usage_error("Queue names must not be empty") if @queues.any?(&.empty?)
      operate("worker", {queues: @queues, all_queues: !@queues_selected, workers: @workers_selected ? @workers : nil,
                         api: @api, shutdown_timeout: @shutdown_timeout}.to_json, @release)
    end
  end
end
