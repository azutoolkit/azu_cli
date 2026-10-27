require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Project do
  # The examples render projects into ./tmp_test_*; clear them before and after each, even when one fails.
  before_each { Dir.glob("./tmp_test_*").each { |dir| FileUtils.rm_rf(dir) } }
  after_each { Dir.glob("./tmp_test_*").each { |dir| FileUtils.rm_rf(dir) } }

  it "creates a project generator with required parameters" do
    generator = AzuCLI::Generate::Project.new(
      "myapp",
      "MyApp",
      "John Doe",
      "john@example.com"
    )

    generator.project.should eq("myapp")
    generator.module_name.should eq("MyApp")
    generator.author.should eq("John Doe")
    generator.email.should eq("john@example.com")
  end

  it "uses default values for optional parameters" do
    generator = AzuCLI::Generate::Project.new(
      "myapp",
      "MyApp",
      "John Doe",
      "john@example.com"
    )

    generator.license.should eq("MIT")
    generator.project_type.should eq("web")
    generator.database.should eq("postgresql")
    generator.test_framework.should eq("spec")
    generator.ci_setup.should eq("GitHub Actions")
    generator.docker_support.should be_false
    generator.git_init.should be_true
    generator.include_example.should be_true
    generator.include_joobq.should be_true
  end

  it "accepts custom values for all parameters" do
    generator = AzuCLI::Generate::Project.new(
      "myapi",
      "MyApi",
      "Jane Smith",
      "jane@example.com",
      "Apache-2.0",
      "api",
      "mysql",
      "minitest",
      "None",
      true,
      false,
      false,
      false
    )

    generator.project.should eq("myapi")
    generator.license.should eq("Apache-2.0")
    generator.project_type.should eq("api")
    generator.database.should eq("mysql")
    generator.test_framework.should eq("minitest")
    generator.ci_setup.should eq("None")
    generator.docker_support.should be_true
    generator.git_init.should be_false
    generator.include_example.should be_false
    generator.include_joobq.should be_false
  end

  describe "#database_adapter" do
    it "returns pg for postgresql" do
      generator = AzuCLI::Generate::Project.new("app", "App", "Author", "email", database: "postgresql")
      generator.database_adapter.should eq("pg")
    end

    it "returns pg for postgres" do
      generator = AzuCLI::Generate::Project.new("app", "App", "Author", "email", database: "postgres")
      generator.database_adapter.should eq("pg")
    end

    it "returns pg for pg" do
      generator = AzuCLI::Generate::Project.new("app", "App", "Author", "email", database: "pg")
      generator.database_adapter.should eq("pg")
    end

    it "returns mysql for mysql" do
      generator = AzuCLI::Generate::Project.new("app", "App", "Author", "email", database: "mysql")
      generator.database_adapter.should eq("mysql")
    end

    it "returns sqlite3 for sqlite" do
      generator = AzuCLI::Generate::Project.new("app", "App", "Author", "email", database: "sqlite")
      generator.database_adapter.should eq("sqlite3")
    end

    it "returns sqlite3 for sqlite3" do
      generator = AzuCLI::Generate::Project.new("app", "App", "Author", "email", database: "sqlite3")
      generator.database_adapter.should eq("sqlite3")
    end

    it "defaults to pg for unknown database" do
      generator = AzuCLI::Generate::Project.new("app", "App", "Author", "email", database: "unknown")
      generator.database_adapter.should eq("pg")
    end
  end

  describe "#database_adapter_uri_prefix" do
    it "returns postgresql for postgresql" do
      generator = AzuCLI::Generate::Project.new("app", "App", "Author", "email", database: "postgresql")
      generator.database_adapter_uri_prefix.should eq("postgresql")
    end

    it "returns mysql for mysql" do
      generator = AzuCLI::Generate::Project.new("app", "App", "Author", "email", database: "mysql")
      generator.database_adapter_uri_prefix.should eq("mysql")
    end

    it "returns sqlite3 for sqlite" do
      generator = AzuCLI::Generate::Project.new("app", "App", "Author", "email", database: "sqlite")
      generator.database_adapter_uri_prefix.should eq("sqlite3")
    end
  end

  describe "#database_env_url" do
    it "includes project name in database URL" do
      generator = AzuCLI::Generate::Project.new("myapp", "MyApp", "Author", "email")
      url = generator.database_env_url
      url.should contain("myapp")
    end

    it "generates postgresql URL format" do
      generator = AzuCLI::Generate::Project.new("myapp", "MyApp", "Author", "email", database: "postgresql")
      url = generator.database_env_url
      url.should contain("postgresql://")
    end

    it "generates mysql URL format" do
      generator = AzuCLI::Generate::Project.new("myapp", "MyApp", "Author", "email", database: "mysql")
      url = generator.database_env_url
      url.should contain("mysql://")
    end

    it "generates sqlite3 URL format" do
      generator = AzuCLI::Generate::Project.new("myapp", "MyApp", "Author", "email", database: "sqlite3")
      url = generator.database_env_url
      url.should contain("sqlite3://")
    end
  end

  describe "#database_dependency" do
    it "generates pg dependency" do
      generator = AzuCLI::Generate::Project.new("app", "App", "Author", "email", database: "postgresql")
      dep = generator.database_dependency
      dep.should contain("pg:")
      dep.should contain("github: will/crystal-pg")
    end

    it "generates mysql dependency" do
      generator = AzuCLI::Generate::Project.new("app", "App", "Author", "email", database: "mysql")
      dep = generator.database_dependency
      dep.should contain("mysql:")
      dep.should contain("github: crystal-lang/crystal-mysql")
    end

    it "generates sqlite3 dependency" do
      generator = AzuCLI::Generate::Project.new("app", "App", "Author", "email", database: "sqlite3")
      dep = generator.database_dependency
      dep.should contain("sqlite3:")
      dep.should contain("github: crystal-lang/crystal-sqlite3")
    end
  end

  describe "#github_name" do
    it "extracts username from email" do
      generator = AzuCLI::Generate::Project.new("app", "App", "Author", "john.doe@example.com")
      generator.github_name.should eq("johndoe")
    end

    it "falls back to author name when email is invalid" do
      generator = AzuCLI::Generate::Project.new("app", "App", "John Doe", "invalid-email")
      generator.github_name.should eq("johndoe")
    end
  end

  it "generates spec_helper that sets CRYSTAL_ENV before loading the app" do
    generator = AzuCLI::Generate::Project.new(
      "myapp",
      "MyApp",
      "John Doe",
      "john@example.com"
    )

    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    spec_helper_file = File.join(test_dir, "spec", "spec_helper.cr")
    File.exists?(spec_helper_file).should be_true

    content = File.read(spec_helper_file)
    content.should contain("require \"spec\"")
    content.should contain("ENV[\"CRYSTAL_ENV\"] = \"test\"")
    content.should_not contain("CQL.configure")
    content.index("ENV[\"CRYSTAL_ENV\"]").not_nil!.should be < content.index("require \"../src/myapp\"").not_nil!

    # Clean up
    FileUtils.rm_rf(test_dir)
  end

  describe "Azu + CQL setup" do
    it "generates a single cql_config initializer and no database initializer" do
      generator = AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com")

      test_dir = "./tmp_test_cql_config"
      FileUtils.mkdir_p(test_dir)
      generator.render(test_dir)

      File.exists?(File.join(test_dir, "src", "initializers", "database.cr")).should be_false

      content = File.read(File.join(test_dir, "src", "initializers", "cql_config.cr"))
      content.should contain("require \"pg\"")
      content.should contain("require \"azu/cql\"")
      content.should contain("Azu::CQL.configure do |c|")
      content.should contain("c.db = ENV[\"DATABASE_URL\"]? || \"postgresql://localhost/myapp_\#{ENV[\"CRYSTAL_ENV\"]? || \"development\"}\"")
      content.should contain("c.pool.size")
      content.should contain("Azu::CQL.attach { MyAppDB }")
      # Flags CQL never reads and the env assignment are gone
      content.should_not contain("auto_sync")
      content.should_not contain("bootstrap")
      content.should_not contain("config.env")

      FileUtils.rm_rf(test_dir)
    end

    it "generates a schema that takes its connection from CQL.config" do
      generator = AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com")

      test_dir = "./tmp_test_cql_schema"
      FileUtils.mkdir_p(test_dir)
      generator.render(test_dir)

      content = File.read(File.join(test_dir, "src", "db", "schema.cr"))
      content.should contain("MyAppDB = Azu::CQL.schema :myapp_db do")
      content.should contain("table :cql_schema_migrations do")
      content.should_not contain("CQL::Schema.define")
      content.should_not contain("DATABASE_URL")
      content.should_not contain("uri:")

      FileUtils.rm_rf(test_dir)
    end

    it "signs CSRF tokens with a per-project secret, never a fixed one" do
      test_dir = "./tmp_test_csrf_secret"
      FileUtils.mkdir_p(test_dir)
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com").render(test_dir)

      source = File.read(File.join(test_dir, "src", "myapp.cr"))
      source.should contain(%(csrf.secret_key = Azu::Env.secret("CSRF_SECRET")))
      source.should_not contain("Random::Secure")
      source.should_not contain("loads .env for you")
      source.should_not contain("1234567890")
      File.read(File.join(test_dir, ".env")).should match(/^CSRF_SECRET=[0-9a-f]{64}$/m)
      File.read(File.join(test_dir, ".gitignore")).lines.should contain("/.env")
      File.read(File.join(test_dir, ".gitignore")).lines.should contain("/.env.local")

      FileUtils.rm_rf(test_dir)
    end

    it "loads .env before azu is required, and keeps per-environment database URLs out of .env" do
      test_dir = "./tmp_test_dotenv"
      FileUtils.mkdir_p(test_dir)
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com", database: "sqlite").render(test_dir)

      source = File.read(File.join(test_dir, "src", "myapp.cr"))
      load = source.index(%(Azu::Env.load_all)) || fail("the app file does not load .env")
      (source.index(%(require "azu/env")) || fail("no require azu/env")).should be < load
      load.should be < (source.index(%(\nrequire "azu"\n)) || fail("no require azu"))

      env = File.read(File.join(test_dir, ".env"))
      env.should_not contain("DATABASE_URL")
      env.should_not match(/^\w+=$/m) # an empty value would replace a default once .env is loaded
      env.should_not contain("PERFORMANCE_MONITORING")
      env.should_not match(/^\s*#?\s*HOST=/m) # azu binds loopback in development and 0.0.0.0 elsewhere; .env must not pin either
      File.read(File.join(test_dir, ".env.development")).should contain("DATABASE_URL=sqlite3://./db/myapp_development.db")
      File.read(File.join(test_dir, ".env.test")).should contain("DATABASE_URL=sqlite3://./db/myapp_test.db")
      example = File.read(File.join(test_dir, ".env.example"))
      # the CLI applies a name only when it looks like a setting or .env.example lists it: every generated name must pass
      listed = example.scan(/^\s*#?\s*([A-Za-z_][A-Za-z0-9_]*)=/m).map(&.[1])
      env.scan(/^([A-Za-z_][A-Za-z0-9_]*)=/m).map(&.[1]).each do |name|
        (AzuCLI::DotEnv.app_name?(name) || listed.includes?(name)).should be_true
        AzuCLI::DotEnv.unsafe_name?(name).should be_false
      end
      example.should match(/^# HOST=127\.0\.0\.1 /m)
      example.should_not match(/^HOST=/m)
      example.should match(/^CSRF_SECRET=$/m)
      example.should_not match(/[0-9a-f]{64}/)

      FileUtils.rm_rf(test_dir)
    end

    it "pins the shards whose newer releases do not build with the generated app and loads channels" do
      test_dir = "./tmp_test_pins"
      FileUtils.mkdir_p(test_dir)
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com").render(test_dir)

      shard = File.read(File.join(test_dir, "shard.yml"))
      shard.should match(/cql:\n    github: azutoolkit\/cql\n    version: 0\.0\.604\n/)
      shard.should match(/session:\n    github: azutoolkit\/session\n    version: ~> 1\.0\.31\n/)
      File.read(File.join(test_dir, "src", "myapp.cr")).should contain(%(require "./channels/**"))
      File.exists?(File.join(test_dir, "src", "channels", ".gitkeep")).should be_true

      FileUtils.rm_rf(test_dir)
    end

    it "declares one Crystal floor, the version the project is pinned to, in the generated shard.yml and doctor reads it" do
      test_dir = "./tmp_test_floor"
      FileUtils.mkdir_p(test_dir)
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com").render(test_dir)

      File.read(File.join(test_dir, "shard.yml")).should contain("crystal: '>= #{AzuCLI::Generate::Project::CRYSTAL_VERSION}'\n")
      File.read("./shard.yml").should contain("crystal: '>= #{AzuCLI::Generate::Project::CRYSTAL_VERSION}'\n")
      checks = AzuCLI::Diagnostics::Checks.new(test_dir, ->(name : String) { ENV[name]? }, AzuCLI::Diagnostics::LocalSystem.new)
      checks.crystal_floor.should eq AzuCLI::Generate::Project::CRYSTAL_VERSION
    end

    it "uses the mysql and sqlite3 drivers in the initializer" do
      {"mysql" => "mysql", "sqlite3" => "sqlite3"}.each do |database, driver|
        generator = AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com", database: database)

        test_dir = "./tmp_test_cql_#{database}"
        FileUtils.mkdir_p(test_dir)
        generator.render(test_dir)

        content = File.read(File.join(test_dir, "src", "initializers", "cql_config.cr"))
        content.should contain("require \"#{driver}\"")
        content.should_not contain("require \"pg\"")

        FileUtils.rm_rf(test_dir)
      end
    end

    it "turns the JoobQ REST API off in production by CRYSTAL_ENV, the variable Azu reads" do
      FileUtils.mkdir_p("./tmp_test_joobq_env")
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com").render("./tmp_test_joobq_env")

      source = File.read("./tmp_test_joobq_env/src/initializers/joobq.cr")
      source.should contain(%(config.rest_api_enabled = ENV["CRYSTAL_ENV"]? != "production"))
      source.should_not contain(%(ENV["AZU_ENV"]))
      FileUtils.rm_rf("./tmp_test_joobq_env")
    end

    it "loads only the schema from src/db, so the seed file does not run on every boot" do
      FileUtils.mkdir_p("./tmp_test_db_require")
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com").render("./tmp_test_db_require")

      source = File.read("./tmp_test_db_require/src/myapp.cr")
      source.should contain(%(require "./db/schema"\n))
      source.should_not contain(%(require "./db/**"))
      FileUtils.rm_rf("./tmp_test_db_require")
    end

    it "pins azu to the first release with the loopback default, start-once, the container warning, Static's except:, unknown-type refusal and the host-independent type table" do
      FileUtils.mkdir_p("./tmp_test_azu_pin")
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com").render("./tmp_test_azu_pin")

      shard = File.read("./tmp_test_azu_pin/shard.yml")
      shard.should match(/github: azutoolkit\/azu\n\s+version: ~> 0\.5\.118\n/)
      shard.should_not contain("0.5.69")
      FileUtils.rm_rf("./tmp_test_azu_pin")
    end

    it "requires azu/dev in web and api apps, where DevDashboard lives, and not in a cli app" do
      {"web" => true, "api" => true, "cli" => false}.each do |type, requires|
        dir = "./tmp_test_azu_dev_#{type}"
        FileUtils.mkdir_p(dir)
        AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com", project_type: type).render(dir)

        source = File.read("#{dir}/src/myapp.cr")
        source.includes?(%(require "azu"\n# The development dashboard and performance monitor live behind azu/dev (needs azu >= 0.5.118).\nrequire "azu/dev"\n)).should eq(requires)
        FileUtils.rm_rf(dir)
      end
    end

    it "mounts the development handlers by the runtime environment, in one method" do
      test_dir = "./tmp_test_dev_handlers"
      FileUtils.mkdir_p(test_dir)
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com", env: "production").render(test_dir)

      source = File.read(File.join(test_dir, "src", "myapp.cr"))
      source.should contain("def self.dev_handlers : Array(HTTP::Handler)")
      source.should contain("return [] of HTTP::Handler unless Azu::CONFIG.env.development?")
      source.scan("DevDashboard").size.should eq(1)
      source.should contain("      *dev_handlers,\n")
      source.should contain("def self.handlers : Array(HTTP::Handler)")
      source.should contain("    ] of HTTP::Handler\n")

      FileUtils.rm_rf(test_dir)
    end

    it "feeds the dashboard from the monitor it mounts, which .env.development turns on" do
      test_dir = "./tmp_test_dev_dashboard"
      FileUtils.mkdir_p(test_dir)
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com", database: "sqlite").render(test_dir)

      # DevDashboard reads Azu::CONFIG.performance_monitor: a monitor of its own would record requests nobody shows
      source = File.read(File.join(test_dir, "src", "myapp.cr"))
      source.should_not contain("PerformanceMonitor.new")
      source.should contain("if monitor = Azu::CONFIG.performance_monitor")
      File.read(File.join(test_dir, ".env.development")).should match(/^PERFORMANCE_MONITORING=true$/m)
      File.read(File.join(test_dir, ".env.test")).should_not contain("PERFORMANCE_MONITORING")
      # not an application-looking name, so the CLI applies it only because .env.example lists it
      File.read(File.join(test_dir, ".env.example")).should match(/^#\s*PERFORMANCE_MONITORING=/m)

      FileUtils.rm_rf(test_dir)
    end
  end

  describe "static files" do
    it "serves public/ from the handler chain, after the logger and before the router, not from a /* route" do
      {"web" => true, "api" => false}.each do |type, serves|
        dir = "./tmp_test_static_#{type}"
        FileUtils.mkdir_p(dir)
        AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com", project_type: type).render(dir)

        source = File.read("#{dir}/src/myapp.cr")
        source.should_not contain(%(router.get "/*"))
        source.should_not contain("Handler::Static.new\n  end") # the route in the configure block
        source.includes?("      Azu::Handler::Logger.new,\n").should be_true
        handlers = source[/def self\.handlers.*?\] of HTTP::Handler/m]
        handlers.should contain("] of HTTP::Handler")
        handlers.includes?("      Azu::Handler::Static.new(except: [\"/templates\"]),\n").should eq(serves)
        if serves
          (handlers.index("Handler::Logger.new") || 0).should be < (handlers.index("Handler::Static.new") || 0)
        end
        FileUtils.rm_rf(dir)
      end
    end
  end

  describe "security headers and template exposure" do
    handler_block = ->(dir : String) { File.read("#{dir}/src/myapp.cr")[/def self\.handlers.*?\] of HTTP::Handler/m] }

    it "adds SecurityHeaders after the Rescuer, with HSTS only over TLS, in web and api" do
      %w[web api].each do |type|
        dir = "./tmp_test_secheaders_#{type}"
        FileUtils.mkdir_p(dir)
        AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com", project_type: type).render(dir)

        handlers = handler_block.call(dir)
        handlers.should contain("      Azu::Handler::SecurityHeaders.new(hsts: Azu::CONFIG.tls?),")
        # Logger outside Rescuer, as azu's default_handlers: it then sees the status the Rescuer set (404, not 200)
        (handlers.index("Handler::RequestId.new") || 0).should be < (handlers.index("Handler::Logger.new") || -1)
        (handlers.index("Handler::Logger.new") || 0).should be < (handlers.index("Handler::Rescuer.new") || -1)
        (handlers.index("Handler::Rescuer.new") || 0).should be < (handlers.index("Handler::SecurityHeaders.new") || -1)
        handlers.should contain("] of HTTP::Handler")
      end
    end

    it "mounts Static with except: [\"/templates\"] last in web projects, and no Static in api projects" do
      web = "./tmp_test_static_web"
      FileUtils.mkdir_p(web)
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com", project_type: "web").render(web)
      handlers = handler_block.call(web)
      handlers.should contain(%(      Azu::Handler::Static.new(except: ["/templates"]),))
      handlers.scan("Handler::Static.new").size.should eq(1)
      handlers.should_not contain("Static.new(\"") # no positional public dir: the default "public" applies
      (handlers.index("Handler::SecurityHeaders.new") || 0).should be < (handlers.index("Handler::Static.new") || -1)
      (handlers.index("Handler::Static.new") || 0).should be < (handlers.index("] of HTTP::Handler") || -1)
      File.exists?("#{web}/src/middleware/deny_templates.cr").should be_false
      Dir.glob("#{web}/src/**/*.cr").each { |file| File.read(file).should_not contain("DenyTemplates") }

      api = "./tmp_test_static_api"
      FileUtils.mkdir_p(api)
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com", project_type: "api").render(api)
      handler_block.call(api).should_not contain("Static")
    end
  end

  describe "port" do
    it "names the port the app listens on (azu's default, the .env's PORT) wherever a file gives its URL" do
      ["web", "api"].each do |type|
        dir = "./tmp_test_port_#{type}"
        FileUtils.mkdir_p(dir)
        AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com", project_type: type).render(dir)
        File.read("#{dir}/.env").should contain("PORT=#{AzuCLI::Config::Ports::DEV_SERVER}\n")
        File.read("#{dir}/README.md").should contain("http://localhost:4000/")
        Dir.glob("#{dir}/**/*", match: File::MatchOptions::DotFiles).each do |file|
          next unless File.file?(file) && !file.ends_with?(".map") && !file.ends_with?(".css") && !file.ends_with?(".js")
          File.read(file).should_not match(/localhost:3000/)
        end
      end
    end
  end

  describe "welcome page" do
    it "prints the CSRF meta tag as HTML (| safe), as the autoescaping .jinja templates need" do
      web = "./tmp_test_welcome_safe"
      FileUtils.mkdir_p(web)
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com", project_type: "web").render(web)
      page = File.read("#{web}/public/templates/my_app/welcome/index_page.jinja")
      page.should contain("{{ csrf_metatag | safe }}")
      page.should_not contain("{{ csrf_metatag }}")
    end
  end

  describe "delivery files" do
    it "generates a Dockerfile and .dockerignore only with docker support" do
      FileUtils.mkdir_p("./tmp_test_nodocker")
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com").render("./tmp_test_nodocker")
      File.exists?("./tmp_test_nodocker/Dockerfile").should be_false
      File.exists?("./tmp_test_nodocker/.dockerignore").should be_false
      FileUtils.rm_rf("./tmp_test_nodocker")
    end

    it "builds the web entry in a crystal stage and runs it as a non-root user in production" do
      FileUtils.mkdir_p("./tmp_test_docker")
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com", database: "sqlite", docker_support: true).render("./tmp_test_docker")

      dockerfile = File.read("./tmp_test_docker/Dockerfile")
      dockerfile.should contain("FROM crystallang/crystal:#{AzuCLI::Generate::Project::CRYSTAL_VERSION} AS build")
      dockerfile.should contain("libreadline-dev libevent-dev libssl-dev libxml2-dev libyaml-dev libgmp-dev libsqlite3-dev")
      dockerfile.should contain("RUN shards install\n")
      dockerfile.should_not contain("--ignore-crystal-version")
      dockerfile.should contain("mkdir -p bin && crystal build --release --no-debug src/server.cr -o bin/myapp")
      # The crystallang/crystal:1.22.1 build stage is Ubuntu 26.04 (libxml2.so.16): the runtime stage must match it.
      dockerfile.should contain("FROM ubuntu:26.04")
      dockerfile.should contain("libxml2-16")
      dockerfile.should_not contain("ubuntu:24.04")
      dockerfile.should contain("USER app")
      dockerfile.should contain("ENV CRYSTAL_ENV=production HOST=0.0.0.0 PORT=4000 TZ=UTC")
      File.exists?("./tmp_test_docker/docker-compose.yml").should be_false # the CLI generates no compose file
      dockerfile.should contain("tzdata")                                  # the app resolves time zones (Time::Location)
      dockerfile.should contain("HEALTHCHECK")
      dockerfile.should contain("/health")
      dockerfile.should contain("VOLUME /data")
      dockerfile.should contain("ENV DATABASE_URL=sqlite3:///data/myapp.db")
      dockerfile.should_not match(/CSRF_SECRET=|SESSION_SECRET=/)
      File.read("./tmp_test_docker/.dockerignore").lines.should contain(".env")
      File.read("./tmp_test_docker/.dockerignore").lines.should contain(".env.*")
      File.read("./tmp_test_docker/.dockerignore").lines.should contain("*.pem")
      File.read("./tmp_test_docker/.dockerignore").lines.should contain("*.key")
      dockerfile.should contain("bind mount")
      FileUtils.rm_rf("./tmp_test_docker")
    end

    it "builds src/api.cr for an api project and has no data volume on postgresql" do
      FileUtils.mkdir_p("./tmp_test_docker_api")
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com", project_type: "api", docker_support: true).render("./tmp_test_docker_api")

      dockerfile = File.read("./tmp_test_docker_api/Dockerfile")
      dockerfile.should contain("src/api.cr -o bin/myapp")
      dockerfile.should_not contain("VOLUME")
      dockerfile.should_not contain("libsqlite3")
      FileUtils.rm_rf("./tmp_test_docker_api")
    end

    it "generates a GitHub Actions workflow pinned to the template's Crystal version" do
      FileUtils.mkdir_p("./tmp_test_ci")
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com").render("./tmp_test_ci")

      workflow = File.read("./tmp_test_ci/.github/workflows/ci.yml")
      workflow.should contain("image: crystallang/crystal:#{AzuCLI::Generate::Project::CRYSTAL_VERSION}")
      workflow.should contain("run: shards install\n")
      workflow.should_not contain("--ignore-crystal-version")
      workflow.should contain("crystal tool format --check src spec")
      workflow.should contain("run: crystal spec")
      workflow.should contain("crystal build src/server.cr -o bin/myapp")
      workflow.should contain("permissions:\n  contents: read\n")
      File.read("./tmp_test_ci/.tool-versions").should contain("crystal #{AzuCLI::Generate::Project::CRYSTAL_VERSION}")
      FileUtils.rm_rf("./tmp_test_ci")
    end

    it "builds the cli project's own entry point in the workflow" do
      FileUtils.mkdir_p("./tmp_test_ci_cli")
      AzuCLI::Generate::Project.new("mytool", "MyTool", "John Doe", "john@example.com", project_type: "cli").render("./tmp_test_ci_cli")

      File.read("./tmp_test_ci_cli/.github/workflows/ci.yml").should contain("crystal build src/mytool.cr -o bin/mytool")
      FileUtils.rm_rf("./tmp_test_ci_cli")
    end

    it "lets the cli project's specs load it without running the program" do
      FileUtils.mkdir_p("./tmp_test_cli_run")
      AzuCLI::Generate::Project.new("mytool", "MyTool", "John Doe", "john@example.com", project_type: "cli").render("./tmp_test_cli_run")

      File.read("./tmp_test_cli_run/src/mytool.cr").should contain(%(MyTool.run(ARGV) unless ENV["CRYSTAL_ENV"]? == "test"))
      FileUtils.rm_rf("./tmp_test_cli_run")
    end

    it "skips the workflow with --ci None" do
      FileUtils.mkdir_p("./tmp_test_noci")
      AzuCLI::Generate::Project.new("myapp", "MyApp", "John Doe", "john@example.com", ci_setup: "None").render("./tmp_test_noci")
      Dir.exists?("./tmp_test_noci/.github").should be_false
      FileUtils.rm_rf("./tmp_test_noci")
    end
  end
end
