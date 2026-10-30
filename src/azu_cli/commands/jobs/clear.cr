require "../jobs"

module AzuCLI::Commands::Jobs
  class Clear < Base
    property all : Bool = false
    property failed : Bool = false

    def initialize
      super("jobs:clear", "clear waiting jobs or DLQ entries; preserve active jobs")
    end

    protected def command_options(p : OptionParser)
      queue_option(p)
      mutation_options(p)
      p.on("--all", "All configured queues") { @all = true }
      p.on("--failed", "Purge DLQ entries instead of waiting jobs") { @failed = true }
    end

    def execute : Result
      if result = check
        return result
      end
      return usage_error("--all and --queue cannot be combined") if @all && @explicit_queue
      return usage_error("Confirmation required: use --dry-run to inspect, then --force") unless confirmed?
      operate("clear", {queue: @queue, all_queues: @all, failed: @failed, dry_run: @dry_run}.to_json)
    end
  end
end
