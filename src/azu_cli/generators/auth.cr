require "teeplate"
require "./model"

module AzuCLI
  module Generate
    # Authentication generator: sign up, sign in, sign out and a protected page for a web project.
    # The user is a `User` model (email, bcrypt digest) and the signed-in user lives in an encrypted
    # session cookie (the `session` shard), so there is nothing to run besides `azu db:migrate`.
    #
    #   Blog::Registrations::{New,Create}   GET, POST /register
    #   Blog::Sessions::{New,Create,Destroy} GET, POST /login, DELETE /logout
    #   Blog::Account::Show                 GET /account (needs a signed-in user)
    #   Blog::AuthThrottle                  429 with Retry-After after too many sign-in or sign-up attempts
    class Auth < Teeplate::FileTree
      directory "#{__DIR__}/../templates/auth"
      OUTPUT_DIR      = "."
      USER_ATTRIBUTES = {"email" => "string:unique", "password_digest" => "string"}
      SESSION_HANDLER = "Session::SessionHandler(UserSession).new(Session.session),"

      getter app_module : String
      getter app_dir : String

      # Why authentication cannot be generated into `root`, if it cannot: something it would write
      # exists already (a second run, or a `User` made by a scaffold), or the app file has no place for the handler.
      def self.conflict(root : String = ".") : String?
        existing = ["src/models/user.cr", "src/initializers/session.cr", "src/services/auth_throttle.cr", "spec/services/auth_throttle_spec.cr", "src/endpoints/sessions", "src/endpoints/registrations", "src/endpoints/account"]
          .select { |path| File.exists?(File.join(root, path)) }
        existing.concat(Dir.glob(File.join(root, AzuCLI::Config::Paths::MIGRATIONS, "*_create_users.cr")).map { |path| path.sub("#{root}/", "") })
        unless existing.empty?
          return "Authentication would overwrite or duplicate: #{existing.join(", ")}. Remove them (or the User you generated) first."
        end

        app_file = app_file_path(root)
        if File.exists?(app_file) && !handler_anchor.matches?(File.read(app_file))
          "#{app_file} has no `Azu::Handler::RequestId.new,` line to put the session handler after; add #{SESSION_HANDLER} to its handlers and run again."
        end
      end

      def self.app_file_path(root : String = ".") : String
        File.join(root, "src", "#{Utils.project_name}.cr")
      end

      # The handler list line the session handler goes after; a commented-out line does not count.
      def self.handler_anchor : Regex
        /^( *)Azu::Handler::RequestId\.new,/m
      end

      def initialize
        @app_module = Utils.project_module_name
        @app_dir = @app_module.underscore
      end

      # Renders the tree, the `User` model with its migration, then wires the session into the app.
      def render(out_dir : String, force : Bool = false, interactive : Bool = true, list : Bool = false, color : Bool = false)
        super
        Model.new("User", USER_ATTRIBUTES).render(File.join(out_dir, "src", "models"), force: force, interactive: interactive, list: list, color: color)
        add_session_handler(self.class.app_file_path(out_dir))
        add_session_secret(File.join(out_dir, ".env"))
      end

      private def add_session_handler(app_file : String)
        return unless File.exists?(app_file)

        source = File.read(app_file)
        return if source.includes?("Session::SessionHandler")

        File.write(app_file, source.sub(self.class.handler_anchor) { "#{$1}Azu::Handler::RequestId.new,\n#{$1}#{SESSION_HANDLER}" })
      end

      # The .env (created if missing) lists a random secret and is git-ignored; the app loads it at boot (`Azu::Env.load_all`).
      private def add_session_secret(env_file : String)
        content = File.exists?(env_file) ? File.read(env_file) : ""
        return if content.includes?("SESSION_SECRET=")

        separator = content.empty? || content.ends_with?("\n") ? "" : "\n"
        File.write(env_file, "#{content}#{separator}SESSION_SECRET=#{Random::Secure.hex(32)}\n")
      end
    end
  end
end
