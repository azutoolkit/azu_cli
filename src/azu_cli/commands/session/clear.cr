require "../base"
require "./redis_target"
require "./store_detector"
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
          return show_help_result if has_option?("help") || has_option?("h")
          if problem = usage_problem
            return usage_error("#{problem}. #{USAGE}")
          end

          backend = @backend || detected_backend
          return backend if backend.is_a?(Result)

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

        # The backends the initializer sets (see StoreDetector): an entry that is not a backend is a store it
        # cannot read, which makes the command refuse.
        def self.store_backends(source : String) : Array(String)
          StoreDetector.backends(source)
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

        private def usage_problem : String?
          if option = unknown_option(OPTIONS)
            "Unknown option #{option}"
          elsif @backend == ""
            "--backend needs a value: #{BACKENDS.join(", ")}"
          elsif !@args.empty?
            "session:clear takes no arguments (got #{@args.join(" ")})"
          end
        end

        private def clear_redis_sessions : Result
          target = RedisTarget.parse(ENV["REDIS_URL"]? || "redis://localhost:6379")
          return error("REDIS_URL cannot be used: #{target}. Nothing was deleted.") if target.is_a?(String)

          stdout.puts "This deletes every #{REDIS_KEY_PATTERN} key in database #{target.database} of #{target}, " \
                      "including the sessions of other apps that share that database: every user of each of them is logged out."
          unless @force
            stdout.print "Delete them? [y/N]: "
            stdout.flush
            response = gets
            return error("Operation cancelled") unless response && response.downcase.starts_with?("y")
          end
          delete_sessions(target)
        end

        private def delete_sessions(target : RedisTarget) : Result
          redis = Redis.new(host: target.host, port: target.port, password: target.password, database: target.database,
            ssl: target.ssl?)
          begin
            success("Cleared #{self.class.clear_redis(redis)} session(s)")
          ensure
            redis.close
          end
        rescue ex : Redis::Error | Socket::Error | IO::Error
          message = target.scrub(ex.message.to_s)
          if message.includes?("DB index is out of range")
            error("#{target} has no database #{target.database} (a server has 16, 0 to 15, unless its `databases` " \
                  "setting says otherwise). Nothing was deleted.")
          else
            error("Failed to clear Redis sessions at #{target}: #{message}")
          end
        end

        # The store the initializer sets, or SESSION_BACKEND when it sets none; an error when it cannot tell.
        private def detected_backend : String | Result
          backends = File.exists?(INITIALIZER) ? self.class.store_backends(File.read(INITIALIZER)) : [] of String
          if backends.empty?
            ENV["SESSION_BACKEND"]? || error("Cannot tell the session backend: #{INITIALIZER} sets no store. Pass --backend #{BACKENDS.join("|")}.")
          elsif backends.size == 1 && BACKENDS.includes?(backends.first)
            backends.first
          else
            error("Cannot tell the session backend from #{INITIALIZER} (#{backends.join("; ")}). Pass --backend #{BACKENDS.join("|")}.")
          end
        end

        private def show_help_result : Result
          show_help
          success
        end

        def show_help
          stdout.puts <<-HELP
            #{USAGE}

            Deletes the sessions kept in Redis: every #{REDIS_KEY_PATTERN} key in REDIS_URL's database, SCAN by SCAN,
            including the sessions of other apps that share that database. It prints the target as
            scheme://host:port/database (never the user or password) and asks first unless --force.
            The backend is read from the store src/initializers/session.cr sets unless --backend names it: only
            `Session.use_store(Session::<Store>(...))` or `config.store = Session::<Store>(...).new(...)` at the top
            level or in a do block count (comments and strings do not); any other store it finds, or code it cannot
            read, makes it refuse. Cookie and memory sessions cannot be cleared from here: the
            command says what to do instead, without asking.

            Options:
              -b, --backend <type>  cookie, redis or memory
              -f, --force           Do not ask first
              -h, --help            Show this help

            Exit codes: 0 cleared, 1 not cleared, 2 invalid usage.
            HELP
        end
      end
    end
  end
end
