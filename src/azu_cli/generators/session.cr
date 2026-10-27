require "teeplate"
require "./session_wiring"
require "./auth"

module AzuCLI
  module Generate
    # `azu session:setup`: a `UserSession` kept by the session shard in an encrypted cookie (default), Redis or
    # memory, its handler in the app's handler list and a random SESSION_SECRET in the git-ignored .env.
    class Session < Teeplate::FileTree
      directory "#{__DIR__}/../templates/session"
      OUTPUT_DIR  = "."
      BACKENDS    = %w[cookie redis memory]
      INITIALIZER = "src/initializers/session.cr"
      # Files only `azu generate auth` writes: their UserSession (user_id, authenticated?) is what sign-in needs.
      AUTH_FILES = ["src/endpoints/sessions", "src/services/auth_throttle.cr"]

      getter project : String
      getter backend : String

      def initialize(@project : String, @backend : String = "cookie")
        unless BACKENDS.includes?(@backend)
          raise ArgumentError.new("Unknown session backend #{@backend.inspect}: use #{BACKENDS.join(", ")} (the session shard has no database store)")
        end
      end

      # Why the session cannot be set up in `root`, if it cannot: the initializer exists (replaced only with
      # `force`, never when authentication wrote it) or the app file has no place for the session handler.
      def self.conflict(root : String = ".", force : Bool = false) : String?
        initializer = File.join(root, INITIALIZER)
        if File.exists?(initializer)
          if auth_initializer?(root, File.read(initializer))
            return "#{INITIALIZER} was written by `azu generate auth`: its UserSession has the user_id and authenticated? " \
                   "that sign-in needs, so session:setup will not replace it, even with --force. The session is set up " \
                   "already; to change its store, edit `config.store` in that file (Session::RedisStore or Session::MemoryStore)."
          end
          return "#{INITIALIZER} exists: run again with --force to replace it (what you added to UserSession is lost)." unless force
        end

        app_file = File.join(root, "src", "#{Utils.project_name}.cr")
        return "#{app_file} not found: run azu session:setup in the root of an Azu project." unless File.exists?(app_file)
        source = File.read(app_file)
        unless source.includes?("Session::SessionHandler") || SessionWiring::ANCHOR.matches?(source)
          "#{app_file} has no `Azu::Handler::RequestId.new,` line to put the session handler after; add #{SessionWiring::HANDLER} to its handlers and run again."
        end
      end

      def self.auth_initializer?(root : String, source : String) : Bool
        source.includes?(Auth::INITIALIZER_MARKER) || source.includes?("def authenticated?") ||
          AUTH_FILES.any? { |path| File.exists?(File.join(root, path)) }
      end

      def store_type : String
        {"cookie" => "CookieStore", "redis" => "RedisStore", "memory" => "MemoryStore"}[@backend]
      end

      def render(out_dir : String, force : Bool = false, interactive : Bool = true, list : Bool = false, color : Bool = false)
        super
        SessionWiring.add_handler(File.join(out_dir, "src", "#{Utils.project_name}.cr"))
        SessionWiring.add_secret(File.join(out_dir, ".env"))
      end
    end
  end
end
