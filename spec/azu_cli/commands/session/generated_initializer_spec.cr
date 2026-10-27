require "../../../spec_helper"
require "../../../support/generator_helpers"

include GeneratorHelpers

private alias Initializer = AzuCLI::Commands::Session::GeneratedInitializer

# What `azu session:setup --backend <backend>` writes for the project "blog".
private def setup_file(backend : String) : String
  Initializer.renderings("blog").find! { |rendered, _| rendered == backend }.last
end

# What `azu generate auth` writes into the project in the current directory.
private def auth_file : String
  File.write("src/blog.cr", "handlers = [\n  Azu::Handler::RequestId.new,\n]\n")
  AzuCLI::Generate::Auth.new.render(File.expand_path("."), force: true, interactive: false)
  File.read("src/initializers/session.cr")
end

# Every string one character away from `source`: each character replaced, removed, or preceded by another one.
# Removing the final newline is left out: a file without it is the same file.
private def one_char_changes(source : String) : Array(String)
  changes = [] of String
  source.each_char_with_index do |char, index|
    before, after = source[0, index], source[(index + 1)..]
    changes << before + (char == 'x' ? 'y' : 'x') + after
    changes << before + after unless index == source.size - 1
    changes << before + '#' + char + after
  end
  changes
end

describe AzuCLI::Commands::Session::GeneratedInitializer do
  it "knows the file session:setup writes for each backend, with LF or CRLF line ends and trailing blank lines" do
    in_generated_project do
      renderings = Initializer.renderings("blog")
      AzuCLI::Generate::Session::BACKENDS.each do |backend|
        AzuCLI::Generate::Session.new(project: "blog", backend: backend).render(".", force: true, interactive: false)
        written = File.read("src/initializers/session.cr")
        written.should eq setup_file(backend)
        [written, written.gsub("\n", "\r\n"), written + "\n\n", written + "  \n \n", written.rstrip,
         written.gsub("\n", "\r\n") + "\r\n\r\n"].each do |variant|
          Initializer.backend(variant, renderings).should eq backend
        end
      end
    end
  end

  it "refuses each file session:setup writes with any one character changed" do
    renderings = Initializer.renderings("blog")
    AzuCLI::Generate::Session::BACKENDS.each do |backend|
      one_char_changes(setup_file(backend)).each do |changed|
        Initializer.backend(changed, renderings).should be_nil
      end
    end
  end

  it "refuses a file with a comment line, a blank line or a statement added, or its store changed" do
    renderings = Initializer.renderings("blog")
    redis = setup_file("redis")
    cookie = setup_file("cookie")
    lines = redis.lines(chomp: false)
    [
      "# notes\n" + redis,
      lines[0] + "# notes\n" + lines[1..].join,
      lines[0] + "\n" + lines[1..].join,
      lines[0] + "\r\n" + lines[1..].join,
      redis + "# notes\n",
      redis + "Session.use_store(Session::CookieStore(UserSession))\n",
      redis.sub("config.store = Session::RedisStore(UserSession)", "config.store = Session::CookieStore(UserSession)"),
      cookie.sub("Session.use_store(Session::CookieStore(UserSession))", "Session.use_store(Session::RedisStore(UserSession))"),
      cookie.gsub("CookieStore", "RedisStore"),
      "\n" + redis,
      " " + redis,
      "",
    ].each do |source|
      Initializer.backend(source, renderings).should be_nil
    end
  end

  it "refuses the file session:setup writes for another project (its session key differs)" do
    Initializer.backend(setup_file("redis"), Initializer.renderings("shop")).should be_nil
  end

  it "reads the initializer of azu generate auth as cookie, with and without its marker line, and nothing edited" do
    in_generated_project do
      auth = auth_file
      renderings = Initializer.renderings("blog")
      without_marker = auth.lines(chomp: false)[1..].join
      auth.should start_with(AzuCLI::Generate::Auth::INITIALIZER_MARKER)
      without_marker.should_not contain(AzuCLI::Generate::Auth::INITIALIZER_MARKER)

      Initializer.backend(auth, renderings).should eq "cookie"
      Initializer.backend(auth.gsub("\n", "\r\n") + "\r\n", renderings).should eq "cookie"
      Initializer.backend(without_marker, renderings).should eq "cookie"
      Initializer.backend(auth.sub("config.store = Session::CookieStore(UserSession).new",
        "config.store = Session::RedisStore(UserSession).new(Redis.new)"), renderings).should be_nil
      Initializer.backend(auth.sub("8.hours", "9.hours"), renderings).should be_nil
    end
  end
end
