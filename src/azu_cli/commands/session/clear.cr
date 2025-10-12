require "../base"
require "redis"
require "yaml"

module AzuCLI
  module Commands
    module Session
      # Clear all sessions
      class Clear < Base
        property force : Bool = false
        property backend : String?

        def initialize
          super("session:clear", "Clear all application sessions")
        end

        # Override parse_args to also trigger custom parsing
        def parse_args(args : Array(String))
          super(args)
          parse_options
        end

        def execute : Result
          parse_options

          unless @force
            print "Are you sure you want to clear all sessions? This will log out all users. [y/N]: "
            response = gets
            unless response && response.downcase.starts_with?("y")
              return error("Operation cancelled")
            end
          end

          # Detect backend from config or environment
          backend = detect_backend

          Logger.info("Clearing sessions...")
          Logger.info("Backend: #{backend}")

          case backend
          when "redis"
            clear_redis_sessions
          when "database"
            clear_database_sessions
          when "memory"
            Logger.warn("Memory sessions cannot be cleared remotely")
            Logger.info("Restart the application to clear memory sessions")
          else
            return error("Unknown session backend: #{backend}")
          end

          Logger.info("✓ Sessions cleared successfully")
          success("Sessions cleared")
        end

        private def parse_options
          args = get_args
          args.each_with_index do |arg, index|
            case arg
            when "--force", "-f"
              @force = true
            when "--backend", "-b"
              @backend = args[index + 1]? if index + 1 < args.size
            end
          end
        end

        private def detect_backend : String
          # Try to detect from session initializer file
          if File.exists?("./src/initializers/session.cr")
            content = File.read("./src/initializers/session.cr")
            return "redis" if content.includes?("RedisStore")
            return "database" if content.includes?("DatabaseStore")
            return "memory" if content.includes?("MemoryStore")
          end

          # Try to detect from environment
          ENV["SESSION_BACKEND"]? || "redis"
        end

        private def clear_redis_sessions
          redis_url = ENV["REDIS_URL"]? || "redis://localhost:6379"
          redis = Redis.new(url: redis_url)

          # Get project name for key prefix
          project = get_project_name
          pattern = "#{project}:session:*"

          Logger.info("Clearing Redis sessions with pattern: #{pattern}")

          keys = redis.keys(pattern)
          count = keys.size

          if count > 0
            keys.each do |key|
              redis.del(key)
            end
            Logger.info("Cleared #{count} session(s)")
          else
            Logger.info("No sessions found")
          end

          redis.close
        rescue ex
          raise "Failed to clear Redis sessions: #{ex.message}"
        end

        private def clear_database_sessions
          Logger.info("Clearing database sessions...")

          # This is a simplified version - in production you'd want to use
          # the actual session model/repository
          db_url = ENV["DATABASE_URL"]?
          unless db_url
            raise "DATABASE_URL not set"
          end

          ::DB.open(db_url) do |db|
            result = db.exec("DELETE FROM sessions")
            Logger.info("Cleared #{result.rows_affected} session(s)")
          end
        rescue ex
          raise "Failed to clear database sessions: #{ex.message}"
        end

        private def get_project_name : String
          if File.exists?("./shard.yml")
            shard_yml = YAML.parse(File.read("./shard.yml"))
            return shard_yml["name"].as_s
          end
          Dir.current.split("/").last
        end
      end
    end
  end
end
