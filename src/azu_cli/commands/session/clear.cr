require "../base"
require "./redis_target"
require "./generated_initializer"
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
        # How long to wait for the Redis connection (TLS handshake included), and for each reply after it.
        property connect_timeout : Time::Span = 5.seconds
        property command_timeout : Time::Span = 10.seconds

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

        # AUTH and SELECT are sent here, not by the client, so a user name reaches the server (`AUTH user password`,
        # Redis 6 ACLs); without reconnect the client never comes back unauthenticated or on database 0.
        private def delete_sessions(target : RedisTarget) : Result
          scanning = false
          redis = Redis.new(host: target.host, port: target.port, ssl: target.ssl?, reconnect: false,
            dns_timeout: @connect_timeout, connect_timeout: @connect_timeout, command_timeout: @command_timeout)
          begin
            target.auth_arguments.try { |arguments| redis.string_command((["AUTH"] of Redis::RedisValue).concat(arguments)) }
            redis.string_command(["SELECT", target.database.to_s] of Redis::RedisValue)
            scanning = true
            success("Cleared #{self.class.clear_redis(redis)} session(s)")
          ensure
            redis.close
          end
        rescue ex : Redis::Error | Socket::Error | IO::Error
          redis_error(target, target.scrub(ex.message.to_s), timeout: ex.is_a?(Redis::CommandTimeoutError) || ex.message.to_s.includes?("TimeoutError"),
            scanning: scanning == true)
        end

        private def redis_error(target : RedisTarget, message : String, timeout : Bool, scanning : Bool) : Result
          outcome = scanning ? "Some sessions may have been deleted already." : "Nothing was deleted."
          if message.includes?("DB index is out of range")
            error("#{target} has no database #{target.database} (a server has 16, 0 to 15, unless its `databases` " \
                  "setting says otherwise). #{outcome}")
          elsif timeout
            error("#{target} did not answer within #{@connect_timeout.total_seconds}s (connecting) or " \
                  "#{@command_timeout.total_seconds}s (a command): check REDIS_URL's host and port, and its " \
                  "scheme (rediss:// needs a TLS port, redis:// a plain one). #{outcome}")
          else
            error("Failed to clear Redis sessions at #{target}: #{message.rstrip('.')}. #{outcome}")
          end
        end

        # The backend of an initializer the generators wrote, as they wrote it (see GeneratedInitializer), or
        # SESSION_BACKEND when there is no initializer; an error otherwise. What the code of any other initializer
        # does is not guessed, and SESSION_BACKEND does not overrule it: this answer decides what is deleted.
        private def detected_backend : String | Result
          unless File.exists?(INITIALIZER)
            return ENV["SESSION_BACKEND"]? || error("Cannot tell the session backend: there is no #{INITIALIZER} and " \
                                                    "SESSION_BACKEND is not set. Pass --backend #{BACKENDS.join("|")}.")
          end
          source = File.file?(INITIALIZER) ? File.read(INITIALIZER) : ""
          renderings = GeneratedInitializer.renderings(AzuCLI::Generate::Session.project_name)
          GeneratedInitializer.backend(source, renderings) ||
            error("Cannot tell the session backend: #{INITIALIZER} is not a file `azu session:setup` or `azu generate auth` " \
                  "writes for this project, as written. session:clear deletes sessions, so it takes the backend only from " \
                  "such a file, never from code that was edited (and not from SESSION_BACKEND while the file exists). " \
                  "Pass --backend #{BACKENDS.join("|")}.")
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
            Without --backend, the backend is inferred only when src/initializers/session.cr is, as written, a
            file `azu session:setup` or `azu generate auth` writes for this project (line ends and trailing blank
            lines aside); SESSION_BACKEND is used only when that file does not exist. An edited initializer makes
            it refuse: pass --backend. Cookie and memory sessions cannot be cleared from here: the command says
            what to do instead, without asking.

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
