require "yaml"
require "uri"
require "./check"
require "./system"

module AzuCLI
  module Diagnostics
    # The diagnostics, run against the project in `root` and the environment `env` reads. None of them
    # changes anything, and none prints the value of a variable or the password of a URL.
    class Checks
      CONNECT_TIMEOUT = 3.seconds
      DEFAULT_PORT    = 4000
      # Variables the generated app reads that must not keep an example or a short value.
      SECRETS                = {"CSRF_SECRET" => nil, "SESSION_SECRET" => "src/initializers/session.cr"}
      PLACEHOLDER            = /change.?me|secret|password|default|example|xxx|todo|replace/i
      MIN_SECRET_SIZE        = 32
      DEFAULT_DATABASE_PORTS = {"postgres" => 5432, "postgresql" => 5432, "mysql" => 3306}

      getter root : String

      def initialize(@root : String, @env : String -> String?, @system : System = LocalSystem.new)
      end

      def run : Array(Check)
        [crystal, shards, dependencies, database, environment, secrets, port, docker, gitignore]
      end

      def production? : Bool
        environment_name == "production"
      end

      def environment_name : String
        (@env.call("CRYSTAL_ENV").presence || "development").downcase
      end

      # -- crystal and shards -------------------------------------------------------------------

      def crystal : Check
        result = @system.capture("crystal", ["--version"], root)
        return Check.fail("crystal", "crystal was not found", "install Crystal: https://crystal-lang.org/install") unless result && result[0].zero?

        installed = result[1][/Crystal (\d+\.\d+\.\d+)/, 1]?
        return Check.warn("crystal", "could not read the version from '#{result[1].lines.first?.to_s.strip}'", "run 'crystal --version'") unless installed

        floor = crystal_floor
        return Check.ok("crystal", "Crystal #{installed}") unless floor
        return Check.ok("crystal", "Crystal #{installed} (the project needs #{floor} or newer)") if at_least?(installed, floor)

        Check.fail("crystal", "Crystal #{installed} is older than the #{floor} the project needs (shard.yml)", "install Crystal #{floor} or newer")
      end

      # The lower bound in shard.yml's `crystal:` (`1.19.1`, `>= 1.19.1`, `~> 1.19`, `< 2.0, >= 1.19`), or nil when it
      # only has an upper bound.
      def crystal_floor : String?
        requirement = shard_yml.try(&.["crystal"]?).try(&.to_s)
        requirement.try { |text| text[/(?:>=|~>|==?)\s*(\d+\.\d+(?:\.\d+)?)/, 1]? || text[/(?<![<\d.])\s*(\d+\.\d+(?:\.\d+)?)/, 1]? }
      end

      private def at_least?(installed : String, floor : String) : Bool
        floor = "#{floor}.0" if floor.count('.') == 1
        SemanticVersion.parse(installed) >= SemanticVersion.parse(floor)
      end

      def shards : Check
        result = @system.capture("shards", ["--version"], root)
        return Check.fail("shards", "shards was not found", "shards ships with Crystal: https://crystal-lang.org/install") unless result && result[0].zero?

        Check.ok("shards", result[1].lines.first?.to_s.strip)
      end

      def dependencies : Check
        return Check.fail("dependencies", "shard.yml was not found in #{root}", "run 'azu doctor' in the root of the project") unless File.exists?(File.join(root, "shard.yml"))

        result = @system.capture("shards", ["check"], root)
        return Check.warn("dependencies", "could not run 'shards check'", "install shards") unless result
        return Check.fail("dependencies", "the installed shards do not match shard.yml / shard.lock", "run 'shards install'") unless result[0].zero?
        return Check.warn("dependencies", "installed, but there is no shard.lock", "run 'shards install' and commit shard.lock") unless File.exists?(File.join(root, "shard.lock"))

        Check.ok("dependencies", "installed and in sync with shard.lock")
      end

      # -- database -----------------------------------------------------------------------------

      def database : Check
        url = @env.call("DATABASE_URL").presence || @env.call("AZU_DATABASE_URL").presence
        return Check.ok("database", "no database configured: the project does not use CQL") if url.nil? && !uses_database?
        return Check.warn("database", "DATABASE_URL is not set", "set DATABASE_URL (see .env.example) or use 'azu db:*' flags") unless url

        url.matches?(/\Asqlite3?:/i) ? sqlite(url) : server_database(url)
      end

      private def uses_database? : Bool
        dependencies = shard_yml.try(&.["dependencies"]?).try(&.as_h?)
        !!dependencies && dependencies.keys.any? { |name| name.as_s == "cql" }
      end

      private def sqlite(url : String) : Check
        file = url.sub(/\Asqlite3?:(\/\/)?/i, "").split('?', 2).first
        return Check.ok("database", "SQLite in memory") if file.empty? || file.lstrip('/').starts_with?(":memory:")

        path = File.expand_path(file, root)
        return Check.ok("database", "SQLite file #{file} is writable") if File.exists?(path) && File::Info.writable?(path)
        return Check.fail("database", "SQLite file #{file} is not writable", "fix its permissions") if File.exists?(path)

        directory = File.dirname(path)
        return Check.fail("database", "the directory of the SQLite file #{file} does not exist", "create #{File.dirname(file)} or fix DATABASE_URL") unless Dir.exists?(directory)
        return Check.fail("database", "the directory of the SQLite file #{file} is not writable", "fix its permissions") unless File::Info.writable?(directory)

        Check.warn("database", "SQLite file #{file} does not exist yet", "run 'azu db:setup'")
      end

      # What is left of a URL once the user and password are cut off at its last "@". A password may hold "@", "/",
      # ":" or "?", so URI.parse would take pieces of it for the host, the port or the path; nothing parsed from the
      # part before the last "@" is ever printed.
      private record ServerUrl, scheme : String, host : String, port : Int32?, path : String, socket : Bool

      private def split_server_url(url : String) : ServerUrl?
        scheme, separator, rest = url.partition("://")
        scheme = scheme.downcase
        return unless !separator.empty? && DEFAULT_DATABASE_PORTS.has_key?(scheme)

        rest = rest[(rest.rindex('@').not_nil! + 1)..] if rest.includes?('@')
        location, _, query = rest.partition('?')
        authority, slash, path = location.partition('/')
        socket = authority.empty? || query.split('&').any? { |pair| pair.starts_with?("host=/") }
        host, port = authority_parts(authority)
        ServerUrl.new(scheme, host, port, "#{slash}#{path}", socket)
      end

      private def authority_parts(authority : String) : {String, Int32?}
        if authority.starts_with?('[') && (close = authority.index(']'))
          return {authority[1...close], authority[(close + 2)..]?.try(&.to_i?)}
        end

        host, _, port = authority.partition(':')
        {host, port.to_i?}
      end

      private def server_database(url : String) : Check
        parts = split_server_url(url)
        unless parts
          return Check.fail("database", "DATABASE_URL does not start with postgres:// or mysql://", "use scheme://user:password@host:port/name")
        end
        if parts.socket
          return Check.warn("database", "#{parts.scheme} through a unix socket: reachability is not checked", "run 'azu db:status' to test the connection")
        end
        return Check.fail("database", "DATABASE_URL has no usable host", "use scheme://user:password@host:port/name") unless parts.host.matches?(/\A[\w.:-]+\z/)

        port = parts.port || DEFAULT_DATABASE_PORTS[parts.scheme]
        name = parts.path.split('/').last? || ""
        shown = parts.host.includes?(':') ? "[#{parts.host}]" : parts.host
        target = "#{parts.scheme}://#{shown}:#{port}#{name.matches?(/\A[\w.-]+\z/) ? "/#{name}" : ""}"
        if @system.tcp_reachable?(parts.host, port, CONNECT_TIMEOUT)
          Check.ok("database", "#{target} accepts connections (credentials are not tried)")
        else
          Check.fail("database", "cannot connect to #{target} within #{CONNECT_TIMEOUT.total_seconds.to_i}s", "start the database server or fix DATABASE_URL")
        end
      end

      # -- environment --------------------------------------------------------------------------

      # The variables .env.example leaves blank must be set; names only, never values.
      def environment : Check
        example = File.join(root, ".env.example")
        return Check.ok("env", "no .env.example to check against") unless File.exists?(example)

        missing = blank_example_names(File.read(example)).reject { |name| @env.call(name).presence }
        return Check.ok("env", "every variable .env.example leaves blank is set") if missing.empty?

        Check.problem("env", "not set: #{missing.join(", ")}", "set them in .env, .env.local or the process environment (see .env.example)", production?)
      end

      # Names declared `NAME=` without a value, minus those that apply only to a feature the project lacks.
      def blank_example_names(text : String) : Array(String)
        names = text.lines.compact_map { |line| line[/\A([A-Z][A-Z0-9_]*)=\s*\z/, 1]? }
        names.select { |name| (feature = SECRETS[name]?).nil? || File.exists?(File.join(root, feature)) }
      end

      def secrets : Check
        weak = SECRETS.keys.select { |name| (value = @env.call(name).presence) && weak_secret?(value) }
        hardcoded = hardcoded_secret_files
        return Check.ok("secrets", "no weak or hard-coded secrets found") if weak.empty? && hardcoded.empty?

        message = [] of String
        message << "#{weak.join(", ")} look like a placeholder or are shorter than #{MIN_SECRET_SIZE} characters" unless weak.empty?
        message << "a secret is written into #{hardcoded.join(", ")}" unless hardcoded.empty?
        Check.problem("secrets", message.join("; "), "generate one with 'openssl rand -hex 32' and read it from the environment", production?)
      end

      private def weak_secret?(value : String) : Bool
        value.size < MIN_SECRET_SIZE || value.matches?(PLACEHOLDER)
      end

      private def hardcoded_secret_files : Array(String)
        Dir.glob(File.join(root, "src", "**", "*.cr")).select { |file| File.read(file).matches?(/\bsecret(_key)?\s*=\s*"[^"#]{8,}"/) }
          .map(&.sub("#{root}/", ""))
      end

      # -- machine ------------------------------------------------------------------------------

      def port : Check
        raw = @env.call("PORT").presence
        number = raw ? raw.to_i? : DEFAULT_PORT
        return Check.fail("port", "PORT is not a port number", "set PORT to a number between 1 and 65535") unless number && (1..65535).includes?(number)
        case @system.port_state(number)
        in .free?   then Check.ok("port", "port #{number} is free")
        in .in_use? then Check.warn("port", "port #{number} is in use (the application may be running)", "stop the process using it or set PORT")
        in .denied?
          Check.warn("port", "port #{number} cannot be used by this user (ports below 1024 need privileges)", "set PORT to a port above 1023 or run with the needed privileges")
        end
      end

      def docker : Check
        installed = @system.capture("docker", ["--version"], root).try(&.[0].zero?) || false
        return Check.ok("docker", "docker is installed") if installed
        return Check.ok("docker", "docker is not installed (optional)") unless File.exists?(File.join(root, "Dockerfile"))

        Check.warn("docker", "the project has a Dockerfile but docker is not installed", "install Docker to build the image")
      end

      def gitignore : Check
        env_file = File.join(root, ".env")
        return Check.ok("gitignore", "no .env file") unless File.exists?(env_file)

        ignored = git_ignored?
        return Check.fail("gitignore", ".env is tracked by git", "run 'git rm --cached .env' and rotate the secrets in it") if tracked?
        return Check.ok("gitignore", ".env is git-ignored") if ignored

        Check.fail("gitignore", ".env is not git-ignored", "add '.env' to .gitignore")
      end

      private def git_ignored? : Bool
        result = @system.capture("git", ["check-ignore", "-q", ".env"], root)
        return result[0].zero? if result && result[0] != 128

        gitignore = File.join(root, ".gitignore")
        File.exists?(gitignore) && File.read(gitignore).lines.any?(&.strip.in?(".env", "/.env"))
      end

      private def tracked? : Bool
        result = @system.capture("git", ["ls-files", "--error-unmatch", ".env"], root)
        !!result && result[0].zero?
      end

      private def shard_yml : YAML::Any?
        path = File.join(root, "shard.yml")
        File.exists?(path) ? YAML.parse(File.read(path)) : nil
      rescue YAML::ParseException
        nil
      end
    end
  end
end
