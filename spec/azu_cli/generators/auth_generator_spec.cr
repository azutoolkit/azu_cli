require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Auth do
  it "creates an auth generator with default strategy" do
    generator = AzuCLI::Generate::Auth.new("myapp")

    generator.project.should eq("myapp")
    generator.strategy.should eq("authly")
    generator.user_model.should eq("User")
    generator.enable_rbac.should be_true
    generator.enable_csrf.should be_true
    generator.enable_oauth_providers.should eq(["google", "github"])
  end

  it "creates an auth generator with custom strategy" do
    generator = AzuCLI::Generate::Auth.new("myapp", "session")

    generator.strategy.should eq("session")
  end

  it "creates an auth generator with custom user model" do
    generator = AzuCLI::Generate::Auth.new("myapp", "jwt", "Account")

    generator.user_model.should eq("Account")
  end

  it "creates an auth generator with custom options" do
    generator = AzuCLI::Generate::Auth.new(
      "myapp", 
      "authly", 
      "User", 
      false, 
      false, 
      ["google"]
    )

    generator.enable_rbac.should be_false
    generator.enable_csrf.should be_false
    generator.enable_oauth_providers.should eq(["google"])
  end

  describe "strategy detection" do
    it "detects JWT strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "jwt")

      generator.using_jwt?.should be_true
      generator.using_session?.should be_false
      generator.using_oauth?.should be_false
      generator.using_authly?.should be_false
    end

    it "detects session strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "session")

      generator.using_jwt?.should be_false
      generator.using_session?.should be_true
      generator.using_oauth?.should be_false
      generator.using_authly?.should be_false
    end

    it "detects OAuth strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "oauth")

      generator.using_jwt?.should be_false
      generator.using_session?.should be_false
      generator.using_oauth?.should be_true
      generator.using_authly?.should be_false
    end

    it "detects Authly strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly")

      generator.using_jwt?.should be_false
      generator.using_session?.should be_false
      generator.using_oauth?.should be_false
      generator.using_authly?.should be_true
    end
  end

  describe "feature detection" do
    it "detects RBAC enabled" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly", "User", true)

      generator.rbac_enabled?.should be_true
    end

    it "detects RBAC disabled" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly", "User", false)

      generator.rbac_enabled?.should be_false
    end

    it "detects CSRF enabled" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly", "User", true, true)

      generator.csrf_enabled?.should be_true
    end

    it "detects CSRF disabled" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly", "User", true, false)

      generator.csrf_enabled?.should be_false
    end
  end

  describe "OAuth provider detection" do
    it "detects Google OAuth enabled" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly", "User", true, true, ["google"])

      generator.google_oauth_enabled?.should be_true
      generator.github_oauth_enabled?.should be_false
    end

    it "detects GitHub OAuth enabled" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly", "User", true, true, ["github"])

      generator.google_oauth_enabled?.should be_false
      generator.github_oauth_enabled?.should be_true
    end

    it "detects multiple OAuth providers" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly", "User", true, true, ["google", "github"])

      generator.google_oauth_enabled?.should be_true
      generator.github_oauth_enabled?.should be_true
    end
  end

  describe "#password_hash_method" do
    it "generates password hashing methods with enhanced security" do
      generator = AzuCLI::Generate::Auth.new("myapp")

      methods = generator.password_hash_method
      methods.should contain("hash_password")
      methods.should contain("verify_password")
      methods.should contain("generate_secure_password")
      methods.should contain("Crypto::Bcrypt::Password")
      methods.should contain("cost: 14")
    end
  end

  describe "#jwt_methods" do
    it "generates enhanced JWT methods for JWT strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "jwt")

      methods = generator.jwt_methods
      methods.should contain("generate_token")
      methods.should contain("verify_token")
      methods.should contain("generate_refresh_token")
      methods.should contain("verify_refresh_token")
      methods.should contain("validate_token_claims")
      methods.should contain("generate_jti")
      methods.should contain("JWT::Algorithm::HS256")
    end

    it "generates enhanced JWT methods for Authly strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly")

      methods = generator.jwt_methods
      methods.should contain("generate_token")
      methods.should contain("verify_token")
      methods.should contain("generate_refresh_token")
      methods.should contain("verify_refresh_token")
    end

    it "returns empty string for session strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "session")

      generator.jwt_methods.should eq("")
    end
  end

  describe "#dependencies" do
    it "includes basic dependencies" do
      generator = AzuCLI::Generate::Auth.new("myapp")

      deps = generator.dependencies
      deps.should contain("crypto/bcrypt")
      deps.should contain("uuid")
    end

    it "includes JWT dependency for JWT strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "jwt")

      deps = generator.dependencies
      deps.should contain("jwt")
    end

    it "includes Authly dependency for Authly strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly")

      deps = generator.dependencies
      deps.should contain("authly")
      deps.should contain("jwt")
    end

    it "includes session dependency for session strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "session")

      deps = generator.dependencies
      deps.should contain("secure_random")
    end

    it "includes CSRF dependency when CSRF is enabled" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly", "User", true, true)

      deps = generator.dependencies
      deps.should contain("openssl")
    end
  end

  describe "#user_migration" do
    it "generates enhanced user migration" do
      generator = AzuCLI::Generate::Auth.new("myapp")

      migration = generator.user_migration
      migration.should contain("schema.create :users")
      migration.should contain("column :email")
      migration.should contain("column :password_hash")
      migration.should contain("column :failed_login_attempts")
      migration.should contain("column :two_factor_enabled")
      migration.should contain("column :recovery_codes")
    end

    it "generates RBAC tables when RBAC is enabled" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly", "User", true)

      migration = generator.user_migration
      migration.should contain("schema.create :roles")
      migration.should contain("schema.create :permissions")
      migration.should contain("schema.create :user_roles")
      migration.should contain("schema.create :role_permissions")
    end

    it "generates OAuth tables when using Authly" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly")

      migration = generator.user_migration
      migration.should contain("schema.create :oauth_applications")
      migration.should contain("schema.create :oauth_access_tokens")
    end

    it "includes RBAC template when RBAC is enabled" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly", "User", true)

      migration = generator.user_migration
      migration.should contain("<%- if rbac_enabled? %>")
      migration.should contain("schema.create :roles")
      migration.should contain("schema.create :permissions")
    end

    it "includes RBAC template even when RBAC is disabled" do
      generator = AzuCLI::Generate::Auth.new("myapp", "authly", "User", false)

      migration = generator.user_migration
      # The template includes the conditional, but it will be processed during generation
      migration.should contain("<%- if rbac_enabled? %>")
      migration.should contain("schema.create :roles")
      migration.should contain("schema.create :permissions")
    end
  end
end
