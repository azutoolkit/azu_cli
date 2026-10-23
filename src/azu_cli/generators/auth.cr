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
    class Auth < Teeplate::FileTree
      directory "#{__DIR__}/../templates/auth"
      OUTPUT_DIR      = "."
      USER_ATTRIBUTES = {"email" => "string:unique", "password_digest" => "string"}
      SESSION_HANDLER = "Session::SessionHandler(UserSession).new(Session.session),"

      getter app_module : String
      getter app_dir : String

      def initialize
        @app_module = Utils.project_module_name
        @app_dir = @app_module.underscore
      end

      # Renders the tree, the `User` model with its migration, then wires the session into the app.
      def render(out_dir : String, force : Bool = false, interactive : Bool = true, list : Bool = false, color : Bool = false)
        super
        Model.new("User", USER_ATTRIBUTES).render(File.join(out_dir, "src", "models"), force: force, interactive: interactive, list: list, color: color)
        add_session_handler(File.join(out_dir, "src", "#{Utils.project_name}.cr"))
        add_session_secret(File.join(out_dir, ".env"))
      end

      private def add_session_handler(app_file : String)
        return unless File.exists?(app_file)

        source = File.read(app_file)
        return if source.includes?("Session::SessionHandler")

        marker = "Azu::Handler::RequestId.new,"
        unless source.includes?(marker)
          Logger.warn("Add #{SESSION_HANDLER} to the handlers of #{app_file}")
          return
        end
        File.write(app_file, source.sub(/^( *)#{Regex.escape(marker)}/m) { "#{$1}#{marker}\n#{$1}#{SESSION_HANDLER}" })
      end

      # The generated .env lists a random secret (and is git-ignored); nothing loads it, so it has to be exported.
      private def add_session_secret(env_file : String)
        return unless File.exists?(env_file)
        return if File.read(env_file).includes?("SESSION_SECRET=")

        File.open(env_file, "a") { |file| file.puts "SESSION_SECRET=#{Random::Secure.hex(32)}" }
      end
    end
  end
end
