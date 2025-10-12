require "teeplate"

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

      def initialize(
        @project_name : String,
        @redis_url : String = "redis://localhost:6379",
        @default_queue : String = "default",
        @workers : Int32 = 3,
        @create_example_job : Bool = true,
      )
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

      # Generate example job name
      def example_job_name : String
        "ExampleJob"
      end
    end
  end
end
