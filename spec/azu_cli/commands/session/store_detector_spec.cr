require "../../../spec_helper"

private alias Detector = AzuCLI::Commands::Session::StoreDetector

# A detection the command acts on: exactly one of the session shard's stores.
private def readable?(backends : Array(String)) : Bool
  backends.size == 1 && Detector::BACKENDS.includes?(backends.first)
end

describe AzuCLI::Commands::Session::StoreDetector do
  describe "stores it reads" do
    {
      "the shard's three stores"                       => {"Session.use_store(Session::MemoryStore(UserSession))\n", ["memory"]},
      "a top-level ::Session qualifier"                => {"Session.use_store(::Session::RedisStore(UserSession))\n", ["redis"]},
      "use_store without parentheses"                  => {"Session.use_store Session::RedisStore(UserSession)\n", ["redis"]},
      "a store without a generic and without .new"     => {"Session.configure do |config|\n  config.store = Session::CookieStore\nend\n", ["cookie"]},
      "CRLF line ends"                                 => {"# Session::RedisStore\r\nSession.use_store(Session::CookieStore(UserSession))\r\nSession.configure do |config|\r\n  config.store = Session::CookieStore(UserSession).new\r\nend\r\n", ["cookie"]},
      "tabs"                                           => {"Session.configure do |config|\n\tconfig.store\t=\tSession::MemoryStore(UserSession).new\nend\n", ["memory"]},
      "unicode in comments, strings and identifiers"   => {"# café ☕ config.store = Session::RedisStore(U).new\nnom_é = \"ünï config.store = Session::RedisStore\"\nSession.use_store(Session::CookieStore(UserSession))\n", ["cookie"]},
      "nested parentheses in .new"                     => {"Session.configure do |config|\n  config.store = Session::RedisStore(UserSession).new(Redis.new(url: (ENV[\"A\"]? || \"r\"), pool: (1 + (2))))\nend\n", ["redis"]},
      "a store line after `end`"                       => {"class UserSession < Session::Base\n  def authenticated? : Bool\n    true\n  end\nend\nSession.configure do |config|\n  config.timeout = 1.hour\nend\nSession.use_store(Session::RedisStore(UserSession))\n", ["redis"]},
      "a string next to the store"                     => {"puts \"config.store = Session::RedisStore\"\nSession.use_store(Session::CookieStore(UserSession))\n", ["cookie"]},
      "a heredoc (<<-)"                                => {"DOC = <<-TXT\n  config.store = Session::RedisStore(U).new\n  TXT\nSession.use_store(Session::CookieStore(UserSession))\n", ["cookie"]},
      "a heredoc (<<~)"                                => {"DOC = <<~TXT\n  config.store = Session::RedisStore(U).new\nTXT\nSession.use_store(Session::CookieStore(UserSession))\n", ["cookie"]},
      "a heredoc (<<ID)"                               => {"DOC = <<TXT\nconfig.store = Session::RedisStore(U).new\nTXT\nSession.use_store(Session::CookieStore(UserSession))\n", ["cookie"]},
      "a quoted heredoc and two on one line"           => {"puts(<<-'A', <<-B)\n  config.store = Session::RedisStore(U).new\n  A\n  Session.use_store(Session::RedisStore(U))\n  B\nSession.use_store(Session::CookieStore(UserSession))\n", ["cookie"]},
      "%q, %w and %Q literals"                         => {"A = %q(config.store = (Session::RedisStore(U).new))\nB = %w[config.store = Session::RedisStore]\nC = %Q{\#{1} config.store = Session::RedisStore(U).new}\nSession.use_store(Session::CookieStore(UserSession))\n", ["cookie"]},
      "a regex literal"                                => {"R = /config.store = Session::RedisStore(U).new # x/\nSession.use_store(Session::CookieStore(UserSession))\n", ["cookie"]},
      "a char literal holding a quote"                 => {"Q = '\"'\nSession.use_store(Session::CookieStore(UserSession))\nX = \"config.store = Session::RedisStore\"\n", ["cookie"]},
      "an escaped backslash before a comment"          => {"SEP = \"\\\\\" # config.store = Session::RedisStore(U).new\nSession.use_store(Session::CookieStore(UserSession))\n", ["cookie"]},
      "an escaped quote inside a string"               => {"puts \"say \\\" config.store = Session::RedisStore(U).new\"\nSession.use_store(Session::CookieStore(UserSession))\n", ["cookie"]},
      "an interpolation holding a string with a brace" => {"puts \"\#{\"}\"} config.store = Session::RedisStore(U).new\"\nSession.use_store(Session::CookieStore(UserSession))\n", ["cookie"]},
      "a store named only in comments"                 => {"# config.store = Session::RedisStore(U).new\n# Session.use_store(Session::RedisStore(U))\n", [] of String},
      "a read of the store, not a write"               => {"puts Session.config.store\nSession.config.store == x\nSession.use_store(Session::CookieStore(UserSession))\n", ["cookie"]},
    }.each do |name, (source, expected)|
      it "reads #{name}" do
        Detector.backends(source).should eq expected
      end
    end

    it "reports two different stores" do
      Detector.backends("Session.use_store(Session::CookieStore(U))\nSession.configure do |config|\n  config.store = Session::RedisStore(U).new\nend\n")
        .should eq ["cookie", "redis"]
    end
  end

  describe "stores it refuses to guess (fail-closed)" do
    {
      "a parenthesised store"                                               => "config.store = (Session::CookieStore(U).new)\n",
      "store=( ... )"                                                       => "config.store=(Session::CookieStore(U).new)\n",
      "store ||="                                                           => "config.store ||= Session::RedisStore(U).new\n",
      "a store that is not the shard's"                                     => "config.store = MyApp::RedisStore.new\n",
      "an unqualified RedisStore"                                           => "config.store = RedisStore(U).new\n",
      "a store kept in a variable"                                          => "store = Session::RedisStore(U).new\nconfig.store = store\n",
      "a store named as an argument"                                        => "Session.configure(store: Session::RedisStore(U).new)\n",
      "a store behind a modifier"                                           => "Session.use_store(Session::RedisStore(U)) if ENV[\"R\"]?\n",
      "a store inside an if"                                                => "if ENV[\"R\"]?\n  Session.use_store(Session::RedisStore(U))\nend\n",
      "a store inside a def"                                                => "def self.redis!\n  Session.use_store(Session::RedisStore(U))\nend\n",
      "a store inside a brace block"                                        => "Session.configure { |c| c.store = Session::RedisStore(U).new }\n",
      "a store inside macro conditionals"                                   => "{% if flag?(:release) %}\nSession.use_store(Session::RedisStore(U))\n{% end %}\n",
      "a store inside =begin text"                                          => "=begin\nSession.use_store(Session::RedisStore(U))\n=end\n",
      "an unterminated string"                                              => "x = \"config.store = Session::RedisStore\nSession.use_store(Session::RedisStore(U))\n",
      "an unterminated heredoc"                                             => "x = <<-TXT\nSession.use_store(Session::RedisStore(U))\n",
      "an end without a block"                                              => "end\nSession.use_store(Session::RedisStore(U))\n",
      "a block without an end"                                              => "Session.configure do |config|\n  config.store = Session::RedisStore(U).new\n",
      "the review's combination (cookie in parentheses, redis in a string)" => "config.store = (Session::CookieStore(U).new)\nputs \"use config.store = Session::RedisStore for revocation\"\n",
    }.each do |name, source|
      it "refuses #{name}" do
        backends = Detector.backends(source)
        backends.should_not be_empty
        readable?(backends).should be_false
      end
    end
  end

  it "names macro conditionals and =begin text as code it cannot read" do
    Detector.backends("{% if flag?(:release) %}\nSession.use_store(Session::RedisStore(U))\n{% end %}\n").first.should contain("macro")
    Detector.backends("=begin\nSession.use_store(Session::RedisStore(U))\n=end\n").first.should contain("=begin")
  end

  it "reads a 200k-line file in under 2 seconds" do
    source = String.build do |io|
      200_000.times { |i| io << "x" << i << " = \"config.store = Session::RedisStore\" # Session::RedisStore\n" }
      io << "Session.use_store(Session::CookieStore(UserSession))\n"
    end
    elapsed = Time.measure { Detector.backends(source).should eq ["cookie"] }
    elapsed.should be < 2.seconds
  end
end
