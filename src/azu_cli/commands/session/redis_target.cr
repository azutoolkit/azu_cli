require "uri"

module AzuCLI
  module Commands
    module Session
      # The Redis server and database a `redis[s]://[[user]:password@]host[:port][/database]` URL names. It prints
      # as scheme://host:port/database only: never the userinfo, never the URL as given, and a URL it cannot read
      # is answered with a reason that quotes none of it.
      struct RedisTarget
        DEFAULT_PORT = 6379
        HOSTNAME     = /\A[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?\z/
        IPV6         = /\A[0-9A-Fa-f:.]+\z/

        getter host : String
        getter port : Int32
        getter password : String?
        getter database : Int32
        getter? ssl : Bool

        def initialize(@host, @port, @password, @database, @ssl)
        end

        # The target, or why `url` is not one.
        def self.parse(url : String) : RedisTarget | String
          match = url.match(/\A(rediss?):\/\/([^\/?#]*)(?:\/([^?#]*))?(?:\?[^#]*)?\z/i)
          return "it is not a redis://host[:port][/database] URL" unless match
          authority = match[2]
          return "its password holds an unencoded @ (write it as %40)" if authority.count('@') > 1

          userinfo, _, hostport = authority.rpartition('@')
          host, port = host_and_port(hostport)
          return host unless port
          database = database_index(match[3]?)
          return database if database.is_a?(String)
          new(host, port, password(userinfo), database, match[1].downcase == "rediss")
        end

        # {host, port}, or {reason, nil}.
        private def self.host_and_port(hostport : String) : {String, Int32?}
          if hostport.starts_with?('[')
            host, bracket, rest = hostport.lchop('[').partition(']')
            return {"its IPv6 host is not a [address]", nil} unless bracket == "]" && host.matches?(IPV6) && host.includes?(':')
            return {"it has text after its IPv6 host", nil} unless rest.empty? || rest.starts_with?(':')
            port_text = rest.lchop(':') if rest.starts_with?(':')
          else
            host, colon, port_text = hostport.partition(':')
            port_text = nil if colon.empty?
            return {"it has no host", nil} if host.empty?
            return {"its host is not a host name or an address", nil} unless host.matches?(HOSTNAME)
          end
          port = port_text ? port_text.to_i?(whitespace: false, prefix: false, underscore: false) : DEFAULT_PORT
          return {"its port is not a number from 1 to 65535", nil} unless port && port_text.to_s.each_char.all?(&.ascii_number?) && 1 <= port <= 65535
          {host, port}
        end

        private def self.database_index(path : String?) : Int32 | String
          return 0 if path.nil? || path.empty?
          index = path.each_char.all?(&.ascii_number?) ? path.to_i? : nil
          index || "its database is not a number (0 to 15 on a default server)"
        end

        private def self.password(userinfo : String) : String?
          _, colon, password = userinfo.partition(':')
          return if colon.empty? || password.empty?
          URI.decode(password)
        end

        def to_s(io : IO) : Nil
          io << (ssl? ? "rediss" : "redis") << "://"
          host.includes?(':') ? (io << '[' << host << ']') : (io << host)
          io << ':' << port << '/' << database
        end

        # `message` with the password masked, for a server or socket error that might echo it.
        def scrub(message : String) : String
          secret = password
          secret.nil? || secret.empty? ? message : message.gsub(secret, "***")
        end
      end
    end
  end
end
