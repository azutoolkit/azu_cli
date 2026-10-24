require "../../spec_helper"
require "../../support/generator_helpers"

include GeneratorHelpers

describe AzuCLI::Generate::Auth do
  render = ->(dir : String) do
    AzuCLI::Generate::Auth.new.render(File.expand_path(dir), force: true, interactive: false)
  end

  it "generates the account endpoints, pages, requests and templates in the project module" do
    in_generated_project do
      render.call(".")

      %w(
        src/endpoints/registrations/new_endpoint.cr src/endpoints/registrations/create_endpoint.cr
        src/endpoints/sessions/new_endpoint.cr src/endpoints/sessions/create_endpoint.cr src/endpoints/sessions/destroy_endpoint.cr
        src/endpoints/account/show_endpoint.cr src/pages/registrations/new_page.cr src/pages/sessions/new_page.cr
        src/pages/account/show_page.cr src/requests/registrations/create_request.cr src/requests/sessions/create_request.cr
        src/initializers/session.cr src/middleware/authentication.cr
        public/templates/blog/registrations/new_page.jinja public/templates/blog/sessions/new_page.jinja
        public/templates/blog/account/show_page.jinja
      ).each { |path| File.exists?(path).should be_true }

      File.read("src/endpoints/sessions/create_endpoint.cr").should contain("struct Sessions::CreateEndpoint")
      File.read("src/endpoints/sessions/create_endpoint.cr").should contain("module Blog")
    end
  end

  it "stores a bcrypt digest of the password for a unique email" do
    in_generated_project do
      render.call(".")

      File.read("src/endpoints/registrations/create_endpoint.cr").should contain("Crypto::Bcrypt::Password.create(create_request.password)")
      File.read("src/models/user.cr").should contain("property password_digest : String")
      File.read(Dir.glob("src/db/migrations/*_create_users.cr").first).should contain("text :email, unique: true")
      File.read("src/db/schema.cr").should contain("table :users do")
    end
  end

  it "reads the session secret from the environment, with a random fallback outside production" do
    in_generated_project do
      render.call(".")

      session = File.read("src/initializers/session.cr")
      session.should contain(%(config.secret = Azu::Env.secret("SESSION_SECRET")))
      session.should contain("config.timeout = 8.hours")
      session.should contain("SameSite=Strict")
      session.should_not contain("Random::Secure")
      session.should_not match(/secret = "/)
    end
  end

  it "escapes what users typed and posts forms with a CSRF field" do
    in_generated_project do
      render.call(".")

      File.read("public/templates/blog/account/show_page.jinja").should contain("{{ email | e }}")
      File.read("public/templates/blog/sessions/new_page.jinja").should contain("{{ messages.error | e }}")
      File.read("public/templates/blog/sessions/new_page.jinja").should contain("{{ csrf_tag | safe }}")
    end
  end

  it "adds the session handler to the app and a secret to .env, once" do
    in_generated_project do
      File.write("src/blog.cr", "  def self.handlers\n    [\n      Azu::Handler::RequestId.new,\n    ]\n  end\n")
      File.write(".env", "PORT=4000")
      render.call(".")

      File.read("src/blog.cr").scan("Session::SessionHandler(UserSession)").size.should eq(1)
      File.read("src/blog.cr").should contain("      Azu::Handler::RequestId.new,\n      Session::SessionHandler(UserSession).new(Session.session),")
      File.read(".env").should match(/^PORT=4000\nSESSION_SECRET=[0-9a-f]{64}\n\z/)
    end
  end

  it "creates .env when the project has none" do
    in_generated_project do
      File.delete(".env") if File.exists?(".env")
      render.call(".")

      File.read(".env").should match(/\ASESSION_SECRET=[0-9a-f]{64}\n\z/)
    end
  end

  describe ".conflict" do
    it "is nil in a project without authentication" do
      in_generated_project do
        AzuCLI::Generate::Auth.conflict.should be_nil
      end
    end

    it "names what a second run would overwrite" do
      in_generated_project do
        render.call(".")

        message = AzuCLI::Generate::Auth.conflict.not_nil!
        message.should contain("src/models/user.cr")
        message.should contain("src/initializers/session.cr")
        message.should contain("_create_users.cr")
      end
    end

    it "refuses a User that a scaffold made" do
      in_generated_project do
        Dir.mkdir_p("src/models")
        File.write("src/models/user.cr", "struct User; end\n")

        AzuCLI::Generate::Auth.conflict.not_nil!.should contain("src/models/user.cr")
      end
    end

    it "refuses an app file with no RequestId handler to anchor on" do
      in_generated_project do
        File.write("src/blog.cr", "  # Azu::Handler::RequestId.new,\n")

        AzuCLI::Generate::Auth.conflict.not_nil!.should contain("RequestId.new")
      end
    end
  end

  it "validates passwords by bytes, because bcrypt rejects more than 72" do
    in_generated_project do
      render.call(".")

      File.read("src/requests/registrations/create_request.cr").should contain("max_bytes: 72")
      File.read("src/requests/sessions/create_request.cr").should contain("max_bytes: 72")
      File.read("src/requests/bytesize_predicate.cr").should contain("value.bytesize <= limit")
      File.read("src/middleware/authentication.cr").should contain("return if password.bytesize > 72")
    end
  end

  it "only knows the session strategy" do
    in_generated_project do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["auth", "--strategy", "jwt"])

      command.execute.success?.should be_false
      Dir.glob("src/**/*.cr").reject { |path| path.starts_with?("src/db") }.should be_empty
    end
  end
end
