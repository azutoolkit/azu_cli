require "../jobs"

module AzuCLI::Commands::Jobs
  class Retry < Base
    property all : Bool = false
    property limit : Int32?

    def initialize
      super("jobs:retry", "retry failed jobs through atomic JoobQ DLQ redrive")
    end

    protected def command_options(p : OptionParser)
      queue_option(p)
      mutation_options(p)
      p.on("--all", "Retry selected queue's DLQ (maximum 1000)") { @all = true }
      p.on("-l N", "--limit N", "Maximum jobs (1..1000, default 1)") { |v| @limit = positive(v) }
    end

    def execute : Result
      if result = check
        return result
      end
      return usage_error("--all and --limit cannot be combined") if @all && @limit
      return usage_error("Confirmation required: use --dry-run to inspect, then --force") unless confirmed?
      operate("retry", {queue: @queue, all: @all, limit: @limit || 1, dry_run: @dry_run}.to_json)
    end
  end
end
