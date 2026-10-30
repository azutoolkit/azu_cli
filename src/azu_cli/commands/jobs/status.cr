require "../jobs"

module AzuCLI::Commands::Jobs
  class Status < Base
    def initialize
      super("jobs:status", "Show job queue status and statistics")
    end

    def execute : Result
      if result = check
        return result
      end
      operate("status", {queue: @queue, all_queues: !@explicit_queue && !ENV["JOOBQ_QUEUE"]?}.to_json)
    end
  end
end
