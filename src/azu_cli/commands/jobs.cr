require "./base"

module AzuCLI
  module Commands
    module Jobs
      # Base class for job commands
      abstract class Base < Commands::Base
        property redis_url : String = "redis://localhost:6379"
        property queue : String = "default"
        property verbose : Bool = false

        def initialize(name : String = "", description : String = "")
          super(name, description)
          load_job_config
        end

      # Load job configuration from environment
      private def load_job_config
          @redis_url = ENV["REDIS_URL"]? || ENV["JOOBQ_REDIS_URL"]? || @redis_url
          @queue = ENV["JOOBQ_QUEUE"]? || @queue
        end

        # Get Redis connection URL
        protected def redis_connection_url : String
          @redis_url
        end

        # Display job configuration info
        protected def show_job_info
          AzuCLI::Logger.info("Redis: #{@redis_url}")
          AzuCLI::Logger.info("Queue: #{@queue}")
        end
      end
    end
  end
end

