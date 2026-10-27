require "../base"
require "redis"

module AzuCLI
  module Commands
    module Session
      # Ends every session the app keeps server-side (Redis). Cookie and memory sessions cannot be cleared
      # from here: the command says why and what to do instead, without asking first.
      class Clear < Base
        OPTIONS  = ["backend", "b", "force", "f"]
        BACKENDS = %w[cookie redis memory]
        USAGE    = "Usage: azu session:clear [--backend cookie|redis|memory] [--force]"
        # The keys the session shard's RedisStore writes (`RedisStore#prefixed`: "session:<id>"). The prefix is
        # not per app, so every session in the Redis database goes.
        REDIS_KEY_PATTERN = "session:*"
        INITIALIZER       = "./src/initializers/session.cr"

        property force : Bool = false
        property backend : String?

        def initialize
          super("session:clear", "Clear all application sessions")
        end

        def parse_args(args : Array(String))
          super(args)
          @force = has_option?("force") || has_option?("f")
          @backend = value_option("backend", "b")
        end

        def execute : Result
          return show_help_result if has_option?("help")
          if option = unknown_option(OPTIONS)
            return usage_error("Unknown option #{option}. #{USAGE}")
          end
          if @backend == ""
            return usage_error("--backend needs a value: #{BACKENDS.join(", ")}. #{USAGE}")
          end

          backend = @backend || detected_backend
          unless backend
            return error("Cannot tell the session backend: #{INITIALIZER} names no store. Pass --backend #{BACKENDS.join("|")}.")
          end

          case backend
          when "cookie"
            error("Cookie sessions live in the browsers, so nothing here can clear them: change SESSION_SECRET and restart the app, and every existing session cookie stops working.")
          when "memory"
            error("Memory sessions live in the app process, so nothing here can clear them: restart the app to end them all.")
          when "redis"
            clear_redis_sessions
          else
            usage_error("Unknown session backend #{backend.inspect}: use #{BACKENDS.join(", ")}. #{USAGE}")
          end
        end

        # Deletes every key matching `pattern`, a SCAN page at a time (never KEYS, which blocks the server).
        # Returns how many keys went.
        def self.clear_redis(redis : Redis, pattern : String = REDIS_KEY_PATTERN) : Int64
          deleted = 0_i64
          cursor = "0"
          loop do
            result = redis.scan(cursor, match: pattern, count: 100)
            cursor = result[0].as(String)
            keys = result[1].as(Array(Redis::RedisValue)).map(&.as(String))
            deleted += redis.del(keys) unless keys.empty?
            break if cursor == "0"
          end
          deleted
        end

        private def clear_redis_sessions : Result
          redis_url = ENV["REDIS_URL"]? || "redis://localhost:6379"
          unless @force
            print "Delete every #{REDIS_KEY_PATTERN} key in #{redis_url}? This logs out all users. [y/N]: "
            response = gets
            return error("Operation cancelled") unless response && response.downcase.starts_with?("y")
          end

          redis = Redis.new(url: redis_url)
          begin
            count = self.class.clear_redis(redis)
            success("Cleared #{count} session(s)")
          ensure
            redis.close
          end
        rescue ex : Redis::Error
          error("Failed to clear Redis sessions: #{ex.message}")
        end

        # The store the initializer uses, or SESSION_BACKEND; nil when neither says.
        private def detected_backend : String?
          if File.exists?(INITIALIZER)
            content = File.read(INITIALIZER)
            return "redis" if content.includes?("RedisStore")
            return "memory" if content.includes?("MemoryStore")
            return "cookie" if content.includes?("CookieStore")
          end
          ENV["SESSION_BACKEND"]?
        end

        private def show_help_result : Result
          show_help
          success
        end

        def show_help
          stdout.puts <<-HELP
            #{USAGE}

            Deletes the sessions kept in Redis (every #{REDIS_KEY_PATTERN} key in REDIS_URL's database, SCAN by SCAN).
            The backend is read from src/initializers/session.cr unless --backend names it. Cookie and memory
            sessions cannot be cleared from here: the command says what to do instead, without asking.

            Options:
              -b, --backend <type>  cookie, redis or memory
              -f, --force           Do not ask first
              --help                Show this help

            Exit codes: 0 cleared, 1 not cleared, 2 invalid usage.
            HELP
        end
      end
    end
  end
end
