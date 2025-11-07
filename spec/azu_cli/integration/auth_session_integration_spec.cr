require "../../spec_helper"
require "file_utils"

describe "Auth Generator Session Integration" do
  it "generates complete session-based auth system with custom user model" do
    TestHelpers::TestSetup.with_temp_project("session_auth_test") do |temp_project|
      Dir.cd(temp_project.path) do
        # Setup test project structure
        FileUtils.mkdir_p("src/db/migrations")
        FileUtils.mkdir_p("src/models")
        FileUtils.mkdir_p("src/endpoints/auth")
        FileUtils.mkdir_p("src/config")
        FileUtils.mkdir_p("src/middleware")

        # Generate auth with session strategy and custom user model
        generator = AzuCLI::Generate::Auth.new(
          project: "TestApp",
          strategy: "session",
          user_model: "Account",
          enable_rbac: true,
          enable_csrf: true,
          enable_oauth_providers: [] of String
        )

        generator.render(".")

      # Verify session config file was generated
      session_config = "src/config/session.cr"
      File.exists?(session_config).should be_true
      
      content = File.read(session_config)
      content.should contain("struct TestApp::Sessions::AccountSession")
      content.should contain("include Session::SessionData")
      content.should contain("property account_id : Int64?")
      content.should contain("property login_attempts : Int32")
      content.should contain("Session::MemoryStore")
      content.should contain("def self.session")

      # Verify session middleware was generated
      session_middleware = "src/middleware/session_handler.cr"
      File.exists?(session_middleware).should be_true
      
      middleware_content = File.read(session_middleware)
      middleware_content.should contain("class SessionHandler")
      middleware_content.should contain("include HTTP::Handler")
      middleware_content.should contain("load_from context.request.cookies")
      middleware_content.should contain("set_cookies context.response.cookies")

      # Verify endpoints use session
      login_endpoint = "src/endpoints/auth/login_endpoint.cr"
      File.exists?(login_endpoint).should be_true
      
      login_content = File.read(login_endpoint)
      login_content.should contain("current_session.data.account_id")
      login_content.should contain("current_session.data.reset_login_attempts")
      login_content.should contain("private def current_session")
      login_content.should contain("TestApp.session")

      # Verify register endpoint uses session
      register_endpoint = "src/endpoints/auth/register_endpoint.cr"
      File.exists?(register_endpoint).should be_true
      
      register_content = File.read(register_endpoint)
      register_content.should contain("current_session.data.account_id")
      register_content.should_not contain("JWT")

      # Verify logout endpoint
      logout_endpoint = "src/endpoints/auth/logout_endpoint.cr"
      File.exists?(logout_endpoint).should be_true
      
      logout_content = File.read(logout_endpoint)
      logout_content.should contain("current_session.delete")

      # Verify me endpoint uses session
      me_endpoint = "src/endpoints/auth/me_endpoint.cr"
      File.exists?(me_endpoint).should be_true
      
      me_content = File.read(me_endpoint)
      me_content.should contain("current_session.data.account_id")

      # Verify change_password endpoint uses session
      change_password_endpoint = "src/endpoints/auth/change_password_endpoint.cr"
      File.exists?(change_password_endpoint).should be_true
      
      change_password_content = File.read(change_password_endpoint)
      change_password_content.should contain("current_session.data.account_id")

      # Verify model uses custom name
      user_model = "src/models/user.cr"
      File.exists?(user_model).should be_true
      
      model_content = File.read(user_model)
      model_content.should contain("class Account")
      model_content.should contain("db_context")
      model_content.should contain(":accounts")

      # Verify README contains session setup
      readme = "README.md"
      File.exists?(readme).should be_true
      
      readme_content = File.read(readme)
      readme_content.should contain("Session-Based Authentication")
      readme_content.should contain("SESSION_SECRET")
      readme_content.should contain("SessionHandler")
      readme_content.should contain("https://github.com/azutoolkit/session")
      end
    end
  end

  it "generates correct migrations for session auth with custom user model" do
    TestHelpers::TestSetup.with_temp_project("migrations_test") do |temp_project|
      Dir.cd(temp_project.path) do
      # Create migrations directory
      migrations_dir = "src/db/migrations"
      FileUtils.mkdir_p(migrations_dir)

      generator = AzuCLI::Generate::Auth.new(
        project: "BlogApp",
        strategy: "session",
        user_model: "Account",
        enable_rbac: true,
        enable_csrf: false,
        enable_oauth_providers: [] of String
      )

      generator.render(".")

      # Get all migration files
      migration_files = Dir.glob("#{migrations_dir}/*.cr").sort

      # Should have at least some migrations generated
      migration_files.size.should be >= 1
      
      # Verify migrations exist
      Dir.exists?(migrations_dir).should be_true
      migration_files.empty?.should be_false

      # Verify OAuth migration was NOT generated
      oauth_migration = migration_files.find { |f| f.includes?("oauth_applications") }
      if oauth_migration
        oauth_content = File.read(oauth_migration)
        # Should be empty or minimal due to conditional
        oauth_content.strip.size.should be < 50
      end
      end
    end
  end

  it "generates session auth without RBAC" do
    TestHelpers::TestSetup.with_temp_project("no_rbac_test") do |temp_project|
      Dir.cd(temp_project.path) do
      FileUtils.mkdir_p("src/db/migrations")
      FileUtils.mkdir_p("src/models")

      generator = AzuCLI::Generate::Auth.new(
        project: "SimpleApp",
        strategy: "session",
        user_model: "User",
        enable_rbac: false,
        enable_csrf: false,
        enable_oauth_providers: [] of String
      )

      generator.render(".")

      # Verify basic files exist
      session_config = "src/config/session.cr"
      File.exists?(session_config).should be_true

      # Verify model was generated
      user_model = "src/models/user.cr"
      File.exists?(user_model).should be_true
      
      model_content = File.read(user_model)
      model_content.should contain("class User")
      
      # Should not contain RBAC methods when disabled
      model_content.should_not contain("has_permission?")
      model_content.should_not contain("class Role")
      model_content.should_not contain("class Permission")

      # Verify migrations directory
      migrations_dir = "src/db/migrations"
      migration_files = Dir.glob("#{migrations_dir}/*.cr")

      # Should only have user migration (no RBAC tables)
      users_migration = migration_files.find { |f| f.includes?("create_users") }
      users_migration.should_not be_nil

      # Should not have RBAC migrations
      roles_migration = migration_files.find { |f| f.includes?("create_roles") }
      if roles_migration
        # If it exists, it should be empty due to conditional
        content = File.read(roles_migration)
        content.strip.size.should be < 50
      end
      end
    end
  end

  it "properly configures session timeout based on CSRF setting" do
    TestHelpers::TestSetup.with_temp_project("timeout_test") do |temp_project|
      Dir.cd(temp_project.path) do
      FileUtils.mkdir_p("src/config")

      # With CSRF enabled (shorter timeout)
      generator_with_csrf = AzuCLI::Generate::Auth.new(
        project: "SecureApp",
        strategy: "session",
        user_model: "User",
        enable_rbac: false,
        enable_csrf: true,
        enable_oauth_providers: [] of String
      )

      generator_with_csrf.render(".")
      
      session_config = File.read("src/config/session.cr")
      session_config.should contain("config.timeout     = 1.hour")

      # Cleanup for next test
      File.delete("src/config/session.cr")
      FileUtils.mkdir_p("src/config")

      # Without CSRF enabled (longer timeout)
      generator_without_csrf = AzuCLI::Generate::Auth.new(
        project: "SimpleApp",
        strategy: "session",
        user_model: "User",
        enable_rbac: false,
        enable_csrf: false,
        enable_oauth_providers: [] of String
      )

      generator_without_csrf.render(".")
      
      session_config_no_csrf = File.read("src/config/session.cr")
      session_config_no_csrf.should contain("config.timeout     = 24.hours")
      end
    end
  end

  it "generates env.example with session configuration" do
    TestHelpers::TestSetup.with_temp_project("env_test") do |temp_project|
      Dir.cd(temp_project.path) do
      generator = AzuCLI::Generate::Auth.new(
        project: "MyApp",
        strategy: "session",
        user_model: "User"
      )

      generator.render(".")

      env_example = "env.example"
      File.exists?(env_example).should be_true
      
      env_content = File.read(env_example)
      env_content.should contain("SESSION_SECRET")
      env_content.should contain("your-session-secret-key-here")
      end
    end
  end

  it "includes session dependency in dependencies method" do
    generator = AzuCLI::Generate::Auth.new(
      project: "TestApp",
      strategy: "session"
    )

    deps = generator.dependencies
    deps.should contain("session")
    deps.should contain("crypto/bcrypt")
    deps.should contain("uuid")
    
    # Should not include JWT for session strategy
    deps.should_not contain("jwt")
    deps.should_not contain("authly")
  end
end

