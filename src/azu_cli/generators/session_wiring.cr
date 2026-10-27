module AzuCLI
  module Generate
    # Wires a cookie-session initializer into a generated app: the session handler in the app file's handler
    # list and a random SESSION_SECRET in the git-ignored .env. Used by `generate auth` and `session:setup`.
    module SessionWiring
      extend self

      HANDLER = "Session::SessionHandler(UserSession).new(Session.session),"

      # The handler list line the session handler goes after; a commented-out line does not count.
      ANCHOR = /^( *)Azu::Handler::RequestId\.new,/m

      def add_handler(app_file : String) : Nil
        return unless File.exists?(app_file)

        source = File.read(app_file)
        return if source.includes?("Session::SessionHandler")

        File.write(app_file, source.sub(ANCHOR) { "#{$1}Azu::Handler::RequestId.new,\n#{$1}#{HANDLER}" })
      end

      # The .env (created if missing) lists a random secret and is git-ignored; the app loads it at boot (`Azu::Env.load_all`).
      def add_secret(env_file : String) : Nil
        if File.symlink?(env_file)
          Logger.warn("#{env_file} is a symlink: SESSION_SECRET was not written; set it in your environment")
          return
        end

        content = File.exists?(env_file) ? File.read(env_file) : ""
        return if content.includes?("SESSION_SECRET=")

        separator = content.empty? || content.ends_with?("\n") ? "" : "\n"
        File.write(env_file, "#{content}#{separator}SESSION_SECRET=#{Random::Secure.hex(32)}\n", perm: 0o600) # a new file is never readable by others
        File.chmod(env_file, 0o600)                                                                           # nor an existing one
      end
    end
  end
end
