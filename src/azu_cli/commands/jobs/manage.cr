require "../jobs"

module AzuCLI::Commands::Jobs
  class Pause < Base
    def initialize
      super("jobs:pause", "Pause claims for a queue across workers")
    end

    protected def command_options(p : OptionParser)
      queue_option(p)
      mutation_options(p)
    end

    def execute : Result
      if result = check
        return result
      end
      return usage_error("Confirmation required; use --force or --dry-run") unless confirmed?
      operate(name.lchop("jobs:"), {queue: @queue, dry_run: @dry_run}.to_json)
    end
  end

  class Resume < Pause
    def initialize
      super
      @name = "jobs:resume"
      @description = "Resume claims for a paused queue"
    end
  end

  class DLQ < Base
    @limit = 50
    @offset = 0

    def initialize
      super("jobs:dlq", "List DLQ job identifiers without exposing payloads")
    end

    protected def command_options(p : OptionParser)
      queue_option(p)
      p.on("--limit N", "Page size (1..1000)") { |v| @limit = positive(v) }
      p.on("--offset N", "Zero-based offset") do |v|
        number = v.to_i?
        raise ArgumentError.new("Offset must be nonnegative") unless number && number >= 0
        @offset = number
      end
    end

    def execute : Result
      if result = check
        return result
      end
      operate("dlq", {queue: @queue, limit: @limit, offset: @offset}.to_json)
    end
  end
end
