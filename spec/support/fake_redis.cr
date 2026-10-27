require "socket"

# A Redis stand-in on a free local port, for the paths of `session:clear` that reach a server. It records every
# command and answers AUTH, SELECT (a database above 15 does not exist, as on a default server) and SCAN (no keys).
# A `silent` one accepts connections and never answers. `connections` is 0 when nothing ever connected, which is
# how a spec shows that nothing could have been deleted.
class FakeRedis
  getter commands = [] of Array(String)
  getter connections = 0

  def initialize(@silent : Bool = false)
    @server = TCPServer.new("127.0.0.1", 0)
    spawn do
      while client = @server.accept?
        @connections += 1
        spawn serve(client)
      end
    end
  end

  def port : Int32
    @server.local_address.port
  end

  def url(path : String = "/0", userinfo : String = "", scheme : String = "redis") : String
    "#{scheme}://#{userinfo}127.0.0.1:#{port}#{path}"
  end

  def close : Nil
    @server.close
  end

  def self.open(silent : Bool = false, &)
    redis = new(silent)
    yield redis
  ensure
    redis.try(&.close)
  end

  private def serve(client : TCPSocket) : Nil
    if @silent
      IO.copy(client, IO::Memory.new)
      return
    end
    while request = read_command(client)
      @commands << request
      client << reply(request)
      client.flush
    end
  rescue IO::Error
    nil
  ensure
    client.close
  end

  private def read_command(client : TCPSocket) : Array(String)?
    count = client.gets(chomp: true).try(&.lchop('*').to_i?)
    return unless count
    Array.new(count) do
      client.gets
      client.gets(chomp: true).to_s
    end
  end

  private def reply(request : Array(String)) : String
    case request.first.upcase
    when "AUTH"   then "+OK\r\n"
    when "SELECT" then request[1].to_i > 15 ? "-ERR DB index is out of range\r\n" : "+OK\r\n"
    when "SCAN"   then "*2\r\n$1\r\n0\r\n*0\r\n"
    else               "-ERR unknown command\r\n"
    end
  end
end
