require "../jobs"
require "redis"

module AzuCLI
  module Commands
    module Jobs
      # Clear job queues
      class Clear < AzuCLI::Commands::Jobs::Base
        property all : Bool = false
        property failed : Bool = false
        property force : Bool = false

        def initialize
          super("jobs:clear", "clear job queues")
        end

        # Override parse_args to also trigger custom parsing
        def parse_args(args : Array(String))
          super(args)
          parse_options
        end

        def execute : Result
          parse_options

          unless @force
            print "Are you sure you want to clear #{queue_description}? [y/N]: "
            response = gets
            unless response && response.downcase.starts_with?("y")
              return error("Operation cancelled")
            end
          end

          begin
            redis = Redis.new(url: @redis_url)

            if @all
              clear_all_queues(redis)
            elsif @failed
              clear_failed_jobs(redis)
            else
              clear_queue(redis, @queue)
            end

            redis.close
            Logger.info("✓ Queue(s) cleared successfully")
            success("Queue cleared")
          rescue ex
            error("Failed to clear queue: #{ex.message}")
          end
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--all"
              @all = true
            when "--failed"
              @failed = true
            when "--force", "-f"
              @force = true
            when "--queue", "-q"
              @queue = args[index + 1]? || @queue if index + 1 < args.size
            end
          end
        end

        private def queue_description : String
          if @all
            "all queues"
          elsif @failed
            "all failed jobs"
          else
            "queue '#{@queue}'"
          end
        end

        private def clear_all_queues(redis : Redis)
          Logger.info("Clearing all job queues...")
          keys = redis.keys("joobq:queue:*")
          keys.as(Array).each do |key|
            redis.del(key.to_s)
            queue_name = key.to_s.split(":").last
            Logger.info("  Cleared: #{queue_name}")
          end
        end

        private def clear_failed_jobs(redis : Redis)
          Logger.info("Clearing all failed jobs...")
          keys = redis.keys("joobq:failed:*")
          keys.as(Array).each do |key|
            redis.del(key.to_s)
            queue_name = key.to_s.split(":").last
            Logger.info("  Cleared failed jobs in: #{queue_name}")
          end
        end

        private def clear_queue(redis : Redis, queue_name : String)
          Logger.info("Clearing queue '#{queue_name}'...")
          redis.del("joobq:queue:#{queue_name}")
          redis.del("joobq:processing:#{queue_name}")
        end
      end
    end
  end
end
