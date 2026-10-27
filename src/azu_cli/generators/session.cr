require "teeplate"
require "./session_wiring"

module AzuCLI
  module Generate
    # `azu session:setup`: a `UserSession` kept by the session shard in an encrypted cookie (default), Redis or
    # memory, its handler in the app's handler list and a random SESSION_SECRET in the git-ignored .env.
    class Session < Teeplate::FileTree
      directory "#{__DIR__}/../templates/session"
      OUTPUT_DIR = "."
      BACKENDS   = %w(cookie redis memory)

      getter project : String
      getter backend : String

      def initialize(@project : String, @backend : String = "cookie")
        unless BACKENDS.includes?(@backend)
          raise ArgumentError.new("Unknown session backend #{@backend.inspect}: use #{BACKENDS.join(", ")} (the session shard has no database store)")
        end
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
