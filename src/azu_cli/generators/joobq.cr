require "teeplate"
require "uri"

module AzuCLI
  module Generate
    # JoobQ initializer generator
    # Sets up JoobQ configuration and initializer files for existing projects
    class JoobQ < Teeplate::FileTree
      directory "#{__DIR__}/../templates/joobq"

      property project_name : String
      property redis_url : String
      property default_queue : String
      property workers : Int32
      property create_example_job : Bool
      property example_job_name : String

      def initialize(
        @project_name : String,
        @redis_url : String = "redis://localhost:6379",
        @default_queue : String = "default",
        @workers : Int32 = 3,
        @create_example_job : Bool = true,
        @example_job_name : String = "ExampleJob",
      )
      end

      # Why --redis cannot be written into the initializer, if it cannot: the file is committed, so no password
      def self.redis_url_error(url : String) : String?
        uri = URI.parse(url)
        return "Invalid Redis URL. Use redis://host:port or rediss://host:port." unless {"redis", "rediss"}.includes?(uri.scheme) && uri.host.presence
        "The Redis URL holds a password; it would be written into src/initializers/joobq.cr. Set REDIS_URL in the environment (or .env) instead." if uri.password || uri.user
      rescue URI::Error
        "Invalid Redis URL. Use redis://host:port or rediss://host:port."
      end

      # Teeplate renders these: the example job only when asked for
      def rendered_file_entries
        file_entries.reject { |entry| !@create_example_job && entry.path.to_s.ends_with?("example_job.cr") }
      end

      # Generate configuration file path
      def config_file_path : String
        "config/joobq.development.yml"
      end

      # Generate initializer file path
      def initializer_file_path : String
        "src/initializers/joobq.cr"
      end

      # Generate worker file path
      def worker_file_path : String
        "src/worker.cr"
      end

      # Generate jobs directory
      def jobs_directory : String
        "src/jobs"
      end
    end
  end
end
