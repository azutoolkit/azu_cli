require "../jobs"
require "redis"

module AzuCLI
  module Commands
    module Jobs
      # Retry failed jobs
      class Retry < AzuCLI::Commands::Jobs::Base
        property all : Bool = false
        property limit : Int32?

        def initialize
          super("jobs:retry", "Retry failed jobs")
        end

        def execute : Result
          parse_options

          begin
            redis = Redis.new(url: @redis_url)

            failed_key = "joobq:failed:#{@queue}"
            failed_count = redis.llen(failed_key).to_i

            if failed_count == 0
              Logger.info("No failed jobs in queue '#{@queue}'")
              redis.close
              return success("No failed jobs")
            end

            retry_count = @limit || (@all ? failed_count : 1)
            retry_count = [retry_count, failed_count].min

            Logger.info("Retrying #{retry_count} failed job(s) in queue '#{@queue}'...")

            retry_count.times do |i|
              job_data = redis.rpop(failed_key)
              if job_data
                redis.lpush("joobq:queue:#{@queue}", job_data)
                Logger.info("  Retrying job #{i + 1}/#{retry_count}")
              end
            end

            redis.close
            Logger.info("✓ #{retry_count} job(s) queued for retry")
            success("Jobs retried")
          rescue ex
            error("Failed to retry jobs: #{ex.message}")
          end
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--all"
              @all = true
            when "--limit", "-l"
              @limit = args[index + 1]?.try(&.to_i) if index + 1 < args.size
            when "--queue", "-q"
              @queue = args[index + 1]? || @queue if index + 1 < args.size
            end
          end
        end
      end
    end
  end
end

