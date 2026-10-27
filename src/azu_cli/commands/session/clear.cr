require "../base"
require "redis"
require "uri"

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
        STORE_BACKENDS    = {"CookieStore" => "cookie", "RedisStore" => "redis", "MemoryStore" => "memory"}
        # The store an initializer sets: `config.store = <Store>` or `Session.use_store(<Store>`, across lines.
        STORE_LINE = /(?:\b\w+\.store\s*=(?![=~])|\buse_store\s*\(?)\s*([\w:]+)/

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

        # The backends the store lines of an initializer name, in order and without repeats: "cookie", "redis",
        # "memory", or the store as written when it is none of the session shard's. Comments do not count.
        def self.store_backends(source : String) : Array(String)
          code_only(source).scan(STORE_LINE).map do |match|
            store = match[1]
            STORE_BACKENDS[store.split("::").last]? || store
          end.uniq
        end

        # `source` without its comments: from a `#` outside a string literal to the end of the line.
        def self.code_only(source : String) : String
          source.lines(chomp: false).join do |line|
            quote = nil
            cut = line.size
            line.each_char_with_index do |char, index|
              if quote
                quote = nil if char == quote && line[index - 1]? != '\\'
              elsif char == '"' || char == '\''
                quote = char
              elsif char == '#'
                cut = index
                break
              end
            end
            cut < line.size ? "#{line[0, cut]}\n" : line
          end
        end

        # The URL with its password replaced by `***`, so it can be printed.
        def self.redacted_url(uri : URI) : String
          return uri.to_s unless uri.password
          uri.to_s.sub(/\A([a-z][a-z0-9+.-]*:\/\/[^:@\/]*:)[^@\/]*@/i, "\\1***@")
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
          uri = redis_uri
          return uri if uri.is_a?(Result)

          stdout.puts "This deletes every #{REDIS_KEY_PATTERN} key in database #{uri.path.lchop('/').presence || "0"} of " \
                      "#{self.class.redacted_url(uri)}, including the sessions of other apps that share that database: " \
                      "every user of each of them is logged out."
          unless @force
            stdout.print "Delete them? [y/N]: "
            stdout.flush
            response = gets
            return error("Operation cancelled") unless response && response.downcase.starts_with?("y")
          end

          redis = Redis.new(url: uri.to_s)
          begin
            count = self.class.clear_redis(redis)
            success("Cleared #{count} session(s)")
          ensure
            redis.close
          end
        rescue ex : Redis::Error | Socket::Error | IO::Error
          error("Failed to clear Redis sessions: #{ex.message}")
        end

        # REDIS_URL (default redis://localhost:6379) when it is a redis:// or rediss:// URL with a host and a
        # numeric port, or the error to answer.
        private def redis_uri : URI | Result
          url = ENV["REDIS_URL"]? || "redis://localhost:6379"
          uri = URI.parse(url)
          database = uri.path.lchop('/')
          port = url.sub(/\A[a-z]+:\/\//i, "").split('/', 2)[0].split('@').last.partition(':')[2]
          unless %w[redis rediss].includes?(uri.scheme) && uri.host.presence && (port.empty? || port.to_i?) &&
                 (database.empty? || database.to_i?)
            return invalid_redis_url(uri)
          end
          uri
        rescue URI::Error | ArgumentError
          error("REDIS_URL is not a redis://host[:port][/database] URL.")
        end

        private def invalid_redis_url(uri : URI) : Result
          error("REDIS_URL (#{self.class.redacted_url(uri)}) is not a redis://host[:port][/database] URL.")
        end

        # The store the initializer sets, or SESSION_BACKEND when it sets none; an error when it cannot tell.
        private def detected_backend : String | Result
          backends = File.exists?(INITIALIZER) ? self.class.store_backends(File.read(INITIALIZER)) : [] of String
          if backends.empty?
            ENV["SESSION_BACKEND"]? || error("Cannot tell the session backend: #{INITIALIZER} sets no store. Pass --backend #{BACKENDS.join("|")}.")
          elsif backends.size == 1 && BACKENDS.includes?(backends.first)
            backends.first
          else
            error("Cannot tell the session backend: #{INITIALIZER} sets #{backends.join(" and ")}. Pass --backend #{BACKENDS.join("|")}.")
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
            including the sessions of other apps that share that database. It prints the target (password hidden)
            and asks first unless --force.
            The backend is read from the store src/initializers/session.cr sets (config.store or Session.use_store,
            comments ignored) unless --backend names it. Cookie and memory sessions cannot be cleared from here: the
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
