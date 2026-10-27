require "teeplate"
require "yaml"
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

      # Why the session cannot be set up in `root`, if it cannot: authentication is generated (its files, or an
      # initializer that looks like its own), the initializer exists (replaced only with `force`) or the app file
      # has no place for the session handler.
      def self.conflict(root : String = ".", force : Bool = false) : String?
        auth_files = AUTH_FILES.select { |path| File.exists?(File.join(root, path)) }
        unless auth_files.empty?
          return "#{auth_files.join(" and ")} #{auth_files.size == 1 ? "is" : "are"} from `azu generate auth`, which needs its own " \
                 "UserSession (user_id, authenticated?) in #{INITIALIZER}: session:setup will not write that file, even with " \
                 "--force. To change the session store, edit `config.store` in it#{File.exists?(File.join(root, INITIALIZER)) ? "" : " (restore it from version control first)"}."
        end

        initializer = File.join(root, INITIALIZER)
        if File.exists?(initializer)
          if reason = auth_initializer_reason(File.read(initializer))
            return "#{INITIALIZER} looks like it was written by `azu generate auth` (#{reason}), so session:setup will not " \
                   "replace it, even with --force: sign-in needs that UserSession. To change its store, edit `config.store` " \
                   "in it; to have session:setup write a new one, delete the file and run it again (what UserSession has is lost)."
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

      # Why an initializer looks like the one `azu generate auth` writes, or nil.
      def self.auth_initializer_reason(source : String) : String?
        if source.includes?(Auth::INITIALIZER_MARKER)
          "it starts with its marker line"
        elsif source.includes?("def authenticated?")
          "its UserSession defines authenticated?"
        end
      end

      # The project name the initializer's session key is made from: shard.yml's `name`, else the directory's.
      def self.project_name(root : String = ".") : String
        shard_yml = File.join(root, "shard.yml")
        name = YAML.parse(File.read(shard_yml))["name"]?.try(&.as_s?) if File.exists?(shard_yml)
        name || File.basename(File.expand_path(root))
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
