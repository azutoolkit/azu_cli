require "../../spec_helper"
require "file_utils"

# Test directory for auth generator integration tests
AUTH_TEST_DIR = "./tmp/auth_test"

describe "Auth Generator Integration" do
  # Setup and teardown
  before_each do
    Dir.mkdir_p(AUTH_TEST_DIR) unless Dir.exists?(AUTH_TEST_DIR)
  end

  after_each do
    FileUtils.rm_rf(AUTH_TEST_DIR) if Dir.exists?(AUTH_TEST_DIR)
  end

  describe "Session Strategy with Custom User Model" do
    it "generates complete auth system with session support" do
      Dir.cd(AUTH_TEST_DIR) do
        # Setup test project structure
        FileUtils.mkdir_p("src/db/migrations")
        FileUtils.mkdir_p("src/models")
        FileUtils.mkdir_p("src/endpoints/auth")

        # Create a basic shard.yml
        File.write("shard.yml", <<-YAML
        name: test_app
        version: 0.1.0
        dependencies:
        YAML
        )

        # Generate auth with session strategy and custom user model
        generator = AzuCLI::Generate::Auth.new(
          project: "TestApp",
          strategy: "session",
          user_model: "Account",
          enable_rbac: true,
          enable_csrf: true
        )

        generator.render(".")

        # Verify session config was created
        File.exists?("src/initializers/session.cr").should be_true
        session_config = File.read("src/initializers/session.cr")
        session_config.should contain("TestApp::Sessions::AccountSession")
        session_config.should contain("account_id : Int64?")
        session_config.should contain("Session::MemoryStore")
        session_config.should contain("SESSION_SECRET")

        # Verify session handler middleware was created
        File.exists?("src/middleware/session_handler.cr").should be_true
        session_handler = File.read("src/middleware/session_handler.cr")
        session_handler.should contain("TestApp::Middleware::SessionHandler")
        session_handler.should contain("HTTP::Handler")

        # Verify Account model was created
        File.exists?("src/models/user.cr").should be_true
        model_content = File.read("src/models/user.cr")
        model_content.should contain("class Account")
        model_content.should contain("db_context TestAppDB, :accounts")

        # Verify migrations use Account naming
        migrations = Dir.glob("src/db/migrations/*.cr")
        migrations.size.should eq(5) # accounts, roles, permissions, account_roles, role_permissions

        # Check accounts migration
        accounts_migration = migrations.find { |m| m.includes?("create_accounts") }
        accounts_migration.should_not be_nil
        accounts_content = File.read(accounts_migration.not_nil!)
        accounts_content.should contain("class CreateAccounts")
        accounts_content.should contain("schema.table :accounts")
        accounts_content.should contain("schema.accounts.create!")

        # Check account_roles migration (not user_roles)
        account_roles_migration = migrations.find { |m| m.includes?("account_roles") }
        account_roles_migration.should_not be_nil
        roles_content = File.read(account_roles_migration.not_nil!)
        roles_content.should contain("class CreateAccountRoles")
        roles_content.should contain("schema.table :account_roles")
        roles_content.should contain("column :account_id")

        # Verify endpoints use session
        login_endpoint = File.read("src/endpoints/auth/login_endpoint.cr")
        login_endpoint.should contain("current_session.data.account_id")
        login_endpoint.should contain("current_session : Session::Provider")
        login_endpoint.should contain("TestApp.session")
        login_endpoint.should_not contain("JWT.encode")

        # Verify register endpoint
        register_endpoint = File.read("src/endpoints/auth/register_endpoint.cr")
        register_endpoint.should contain("current_session.data.account_id")
        register_endpoint.should contain("reset_login_attempts")

        # Verify me endpoint
        me_endpoint = File.read("src/endpoints/auth/me_endpoint.cr")
        me_endpoint.should contain("current_session.data.account_id")
        me_endpoint.should contain("::Account.find")

        # Verify change password endpoint
        change_pwd_endpoint = File.read("src/endpoints/auth/change_password_endpoint.cr")
        change_pwd_endpoint.should contain("current_session.data.account_id")

        # Verify logout endpoint exists
        File.exists?("src/endpoints/auth/logout_endpoint.cr").should be_true
        logout_endpoint = File.read("src/endpoints/auth/logout_endpoint.cr")
        logout_endpoint.should contain("current_session.delete")

        # Verify OAuth endpoints were NOT created for session strategy
        File.exists?("src/endpoints/auth/oauth_callback_endpoint.cr").should be_false
        File.exists?("src/initializers/authly.cr").should be_false

        # Verify README documentation
        File.exists?("README.md").should be_true
        readme = File.read("README.md")
        readme.should contain("Session-Based Authentication")
        readme.should contain("github.com/azutoolkit/session")

        # Verify env.example
        File.exists?("env.example").should be_true
        env_example = File.read("env.example")
        env_example.should contain("SESSION_SECRET")
      end
    end

    it "generates migrations with unique incremental timestamps" do
      Dir.cd(AUTH_TEST_DIR) do
        FileUtils.mkdir_p("src/db/migrations")

        generator = AzuCLI::Generate::Auth.new(
          project: "TestApp",
          strategy: "session",
          user_model: "User"
        )

        generator.render(".")

        migrations = Dir.glob("src/db/migrations/*.cr").map { |f| File.basename(f) }

        # Extract timestamps
        timestamps = migrations.map do |filename|
          if match = filename.match(/^(\d+)_/)
            match[1].to_i64
          end
        end.compact

        # Verify all timestamps are unique
        timestamps.uniq.size.should eq(timestamps.size)

        # Verify timestamps are sequential
        timestamps.sort.should eq(timestamps)

        # Verify increments are by 1
        timestamps.each_cons(2) do |pair|
          (pair[1] - pair[0]).should eq(1)
        end
      end
    end

    it "generates correct migration order" do
      Dir.cd(AUTH_TEST_DIR) do
        FileUtils.mkdir_p("src/db/migrations")

        generator = AzuCLI::Generate::Auth.new(
          project: "TestApp",
          strategy: "session",
          user_model: "Account"
        )

        generator.render(".")

        migrations = Dir.glob("src/db/migrations/*.cr").sort
        basenames = migrations.map { |f| File.basename(f) }

        # Verify order: users, roles, permissions, user_roles, role_permissions
        basenames[0].should contain("create_accounts")
        basenames[1].should contain("create_roles")
        basenames[2].should contain("create_permissions")
        basenames[3].should contain("create_account_roles")
        basenames[4].should contain("create_role_permissions")
      end
    end
  end

  describe "JWT Strategy" do
    it "generates JWT-based auth without session config" do
      Dir.cd(AUTH_TEST_DIR) do
        FileUtils.mkdir_p("src/db/migrations")

        generator = AzuCLI::Generate::Auth.new(
          project: "TestApp",
          strategy: "jwt",
          user_model: "User"
        )

        generator.render(".")

        # Verify no session config
        File.exists?("src/initializers/session.cr").should be_false
        File.exists?("src/middleware/session_handler.cr").should be_false

        # Verify JWT endpoints
        login_endpoint = File.read("src/endpoints/auth/login_endpoint.cr")
        login_endpoint.should contain("JWT.encode")
        login_endpoint.should contain("generate_access_token")
        login_endpoint.should contain("generate_refresh_token")
        login_endpoint.should_not contain("current_session")

        # Verify refresh endpoint exists
        File.exists?("src/endpoints/auth/refresh_endpoint.cr").should be_true
      end
    end
  end

  describe "RBAC Configuration" do
    it "generates RBAC tables when enabled" do
      Dir.cd(AUTH_TEST_DIR) do
        FileUtils.mkdir_p("src/db/migrations")

        generator = AzuCLI::Generate::Auth.new(
          project: "TestApp",
          strategy: "session",
          user_model: "User",
          enable_rbac: true
        )

        generator.render(".")

        # Verify RBAC migrations exist
        Dir.glob("src/db/migrations/*_create_roles.cr").size.should eq(1)
        Dir.glob("src/db/migrations/*_create_permissions.cr").size.should eq(1)
        Dir.glob("src/db/migrations/*_create_user_roles.cr").size.should eq(1)
        Dir.glob("src/db/migrations/*_create_role_permissions.cr").size.should eq(1)

        # Verify RBAC seed file
        File.exists?("src/db/seed_rbac.cr").should be_true

        # Verify permissions endpoint
        File.exists?("src/endpoints/auth/permissions_endpoint.cr").should be_true
      end
    end

    it "skips RBAC tables when disabled" do
      Dir.cd(AUTH_TEST_DIR) do
        FileUtils.mkdir_p("src/db/migrations")

        generator = AzuCLI::Generate::Auth.new(
          project: "TestApp",
          strategy: "session",
          user_model: "User",
          enable_rbac: false
        )

        generator.render(".")

        # Verify no RBAC migrations
        Dir.glob("src/db/migrations/*_create_roles.cr").size.should eq(0)
        Dir.glob("src/db/migrations/*_create_permissions.cr").size.should eq(0)
        Dir.glob("src/db/migrations/*_create_user_roles.cr").size.should eq(0)

        # Verify no RBAC seed
        File.exists?("src/db/seed_rbac.cr").should be_false

        # Verify no permissions endpoint
        File.exists?("src/endpoints/auth/permissions_endpoint.cr").should be_false
      end
    end
  end

  describe "Migration File Naming" do
    it "matches filenames to class names" do
      Dir.cd(AUTH_TEST_DIR) do
        FileUtils.mkdir_p("src/db/migrations")

        generator = AzuCLI::Generate::Auth.new(
          project: "TestApp",
          strategy: "session",
          user_model: "Account"
        )

        generator.render(".")

        migrations = Dir.glob("src/db/migrations/*.cr")

        migrations.each do |migration_file|
          content = File.read(migration_file)
          filename = File.basename(migration_file, ".cr")

          # Extract class name from content
          if match = content.match(/class\s+(\w+)\s+<\s+CQL::Migration/)
            class_name = match[1]

            # Convert class name to snake_case
            expected_name = class_name
              .gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
              .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
              .downcase

            # Filename should end with the snake_case class name
            filename.should end_with(expected_name)
          end
        end
      end
    end
  end

  describe "Conditional File Generation" do
    it "removes empty conditional files" do
      Dir.cd(AUTH_TEST_DIR) do
        FileUtils.mkdir_p("src/db/migrations")

        # Session strategy should not create OAuth migrations
        generator = AzuCLI::Generate::Auth.new(
          project: "TestApp",
          strategy: "session",
          user_model: "User"
        )

        generator.render(".")

        # Should not have OAuth application migrations (conditional on authly)
        Dir.glob("src/db/migrations/*oauth_applications*").size.should eq(0)
      end
    end
  end

  describe "Helper Methods" do
    it "provides correct user model transformations" do
      generator = AzuCLI::Generate::Auth.new(
        project: "TestApp",
        strategy: "session",
        user_model: "Account"
      )

      generator.user_model_class.should eq("Account")
      generator.user_model_singular.should eq("account")
      generator.user_model_plural.should eq("accounts")
      generator.user_model_table.should eq("accounts")
    end

    it "handles multi-word user models" do
      generator = AzuCLI::Generate::Auth.new(
        project: "TestApp",
        strategy: "session",
        user_model: "UserAccount"
      )

      generator.user_model_class.should eq("UserAccount")
      generator.user_model_singular.should eq("useraccount")
      generator.user_model_plural.should eq("useraccounts")
    end
  end

  describe "Dependencies" do
    it "includes session dependency for session strategy" do
      generator = AzuCLI::Generate::Auth.new(
        project: "TestApp",
        strategy: "session"
      )

      deps = generator.dependencies
      deps.should contain("session")
      deps.should contain("crypto/bcrypt")
      deps.should contain("uuid")
      deps.should_not contain("jwt")
    end

    it "includes JWT dependency for jwt strategy" do
      generator = AzuCLI::Generate::Auth.new(
        project: "TestApp",
        strategy: "jwt"
      )

      deps = generator.dependencies
      deps.should contain("jwt")
      deps.should_not contain("session")
    end

    it "includes authly dependency for authly strategy" do
      generator = AzuCLI::Generate::Auth.new(
        project: "TestApp",
        strategy: "authly"
      )

      deps = generator.dependencies
      deps.should contain("authly")
      deps.should contain("jwt")
    end
  end

  describe "End-to-End Generation" do
    it "generates working auth system directly" do
      Dir.cd(AUTH_TEST_DIR) do
        FileUtils.mkdir_p("src/db/migrations")
        File.write("shard.yml", "name: blog\nversion: 0.1.0\ndependencies:\n")

        # Generate auth using the generator directly
        generator = AzuCLI::Generate::Auth.new(
          project: "Blog",
          strategy: "session",
          user_model: "Account",
          enable_rbac: true
        )

        generator.render(".")

        # Verify all expected files were created
        File.exists?("src/models/user.cr").should be_true
        File.exists?("src/initializers/session.cr").should be_true
        File.exists?("src/middleware/session_handler.cr").should be_true
        File.exists?("src/endpoints/auth/login_endpoint.cr").should be_true
        File.exists?("src/endpoints/auth/register_endpoint.cr").should be_true
        File.exists?("src/endpoints/auth/logout_endpoint.cr").should be_true
        File.exists?("src/endpoints/auth/me_endpoint.cr").should be_true
        File.exists?("src/endpoints/auth/change_password_endpoint.cr").should be_true

        # Verify validators were created
        File.exists?("src/validators/email_validator.cr").should be_true
        File.exists?("src/validators/strong_password_validator.cr").should be_true
        File.exists?("src/validators/password_confirmation_validator.cr").should be_true

        # Verify migrations
        migrations = Dir.glob("src/db/migrations/*.cr")
        migrations.size.should be >= 5

        # Verify each migration has unique timestamp
        timestamps = migrations.map do |f|
          File.basename(f).match(/^(\d+)_/).try(&.[1])
        end.compact

        timestamps.uniq.size.should eq(timestamps.size)
      end
    end
  end
end

