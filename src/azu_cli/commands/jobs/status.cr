require "../jobs"
require "redis"

module AzuCLI
  module Commands
    module Jobs
      # Show job queue status
      class Status < AzuCLI::Commands::Jobs::Base
        def initialize
          super("jobs:status", "Show job queue status and statistics")
        end

        def execute : Result
          Logger.info("Job Queue Status")
          Logger.info("=" * 80)
          show_job_info
          puts ""

          begin
            redis = Redis.new(url: @redis_url)

            # Get queue statistics
            queues = get_queues(redis)

            if queues.empty?
              Logger.info("No queues found")
              return success("No queues")
            end

            display_queue_stats(redis, queues)

            redis.close
            success("Status displayed")
          rescue ex
            error("Failed to connect to Redis: #{ex.message}")
          end
        end

        private def get_queues(redis : Redis) : Array(String)
          # Get all JoobQ queues from Redis
          keys = redis.keys("joobq:queue:*")
          keys.as(Array).map(&.to_s.split(":").last).uniq!
        rescue
          [@queue]
        end

        private def display_queue_stats(redis : Redis, queues : Array(String))
          puts "#{"Queue".ljust(20)} | #{"Pending".rjust(10)} | #{"Processing".rjust(12)} | #{"Failed".rjust(10)}"
          puts "=" * 80

          total_pending = 0
          total_processing = 0
          total_failed = 0

          queues.each do |queue_name|
            pending = redis.llen("joobq:queue:#{queue_name}").to_i
            processing = redis.llen("joobq:processing:#{queue_name}").to_i
            failed = redis.llen("joobq:failed:#{queue_name}").to_i

            puts "#{queue_name.ljust(20)} | #{pending.to_s.rjust(10)} | #{processing.to_s.rjust(12)} | #{failed.to_s.rjust(10)}"

            total_pending += pending
            total_processing += processing
            total_failed += failed
          end

          puts "=" * 80
          puts "#{"Total".ljust(20)} | #{total_pending.to_s.rjust(10)} | #{total_processing.to_s.rjust(12)} | #{total_failed.to_s.rjust(10)}"
        rescue ex
          Logger.error("Error getting queue stats: #{ex.message}")
        end
      end
    end
  end
end
