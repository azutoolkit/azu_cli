require "../../spec_helper"

describe "Authentication Integration" do
  describe "Auth Generator Integration" do
    it "generates complete authentication system with Authly" do
      # Test the complete auth generation flow
      generator = AzuCLI::Generate::Auth.new(
        "testapp",
        "authly",
        "User",
        true,                # RBAC enabled
        true,                # CSRF enabled
        ["google", "github"] # OAuth providers
      )

      # Verify all features are enabled
      generator.using_authly?.should be_true
      generator.rbac_enabled?.should be_true
      generator.csrf_enabled?.should be_true
      generator.google_oauth_enabled?.should be_true
      generator.github_oauth_enabled?.should be_true

      # Verify dependencies include all required shards
      deps = generator.dependencies
      deps.should contain("crypto/bcrypt")
      deps.should contain("uuid")
      deps.should contain("jwt")
      deps.should contain("authly")
      deps.should contain("openssl")

      # Verify migration includes all tables
      migration = generator.user_migration
      migration.should contain("schema.create :users")
      migration.should contain("schema.create :roles")
      migration.should contain("schema.create :permissions")
      migration.should contain("schema.create :user_roles")
      migration.should contain("schema.create :role_permissions")
      migration.should contain("schema.create :oauth_applications")
      migration.should contain("schema.create :oauth_access_tokens")

      # Verify JWT methods are generated
      jwt_methods = generator.jwt_methods
      jwt_methods.should contain("generate_token")
      jwt_methods.should contain("verify_token")
      jwt_methods.should contain("generate_refresh_token")
      jwt_methods.should contain("verify_refresh_token")
      jwt_methods.should contain("validate_token_claims")

      # Verify password hashing methods
      password_methods = generator.password_hash_method
      password_methods.should contain("hash_password")
      password_methods.should contain("verify_password")
      password_methods.should contain("generate_secure_password")
      password_methods.should contain("cost: 14")
    end

    it "generates authentication system with JWT strategy" do
      generator = AzuCLI::Generate::Auth.new(
        "testapp",
        "jwt",
        "User",
        true, # RBAC enabled
        true  # CSRF enabled
      )

      generator.using_jwt?.should be_true
      generator.rbac_enabled?.should be_true
      generator.csrf_enabled?.should be_true

      # Verify dependencies for JWT strategy
      deps = generator.dependencies
      deps.should contain("crypto/bcrypt")
      deps.should contain("jwt")
      deps.should contain("openssl")
      deps.should_not contain("authly")
      deps.should_not contain("secure_random")

      # Verify migration includes RBAC tables and OAuth template conditionals
      migration = generator.user_migration
      migration.should contain("schema.create :users")
      migration.should contain("schema.create :roles")
      migration.should contain("schema.create :permissions")
      migration.should contain("<%- if using_authly? %>")
      migration.should contain("schema.create :oauth_applications")
      migration.should contain("schema.create :oauth_access_tokens")
    end

    it "generates authentication system with session strategy" do
      generator = AzuCLI::Generate::Auth.new(
        "testapp",
        "session",
        "User",
        false, # RBAC disabled
        false  # CSRF disabled
      )

      generator.using_session?.should be_true
      generator.rbac_enabled?.should be_false
      generator.csrf_enabled?.should be_false

      # Verify dependencies for session strategy
      deps = generator.dependencies
      deps.should contain("crypto/bcrypt")
      deps.should contain("secure_random")
      deps.should_not contain("jwt")
      deps.should_not contain("authly")
      deps.should_not contain("openssl")

      # Verify migration includes users table and template conditionals
      migration = generator.user_migration
      migration.should contain("schema.create :users")
      migration.should contain("<%- if rbac_enabled? %>")
      migration.should contain("schema.create :roles")
      migration.should contain("schema.create :permissions")
      migration.should contain("<%- if using_authly? %>")
      migration.should contain("schema.create :oauth_applications")
    end

    it "generates minimal authentication system" do
      generator = AzuCLI::Generate::Auth.new(
        "testapp",
        "jwt",
        "User",
        false, # RBAC disabled
        false  # CSRF disabled
      )

      # Verify minimal dependencies
      deps = generator.dependencies
      deps.should contain("crypto/bcrypt")
      deps.should contain("jwt")
      deps.should_not contain("authly")
      deps.should_not contain("openssl")
      deps.should_not contain("secure_random")

      # Verify minimal migration includes template conditionals
      migration = generator.user_migration
      migration.should contain("schema.create :users")
      migration.should contain("<%- if rbac_enabled? %>")
      migration.should contain("schema.create :roles")
      migration.should contain("schema.create :permissions")
    end
  end

  describe "Security Features Integration" do
    it "validates CSRF protection integration" do
      generator = AzuCLI::Generate::Auth.new("testapp", "authly", "User", true, true)

      # CSRF should be enabled
      generator.csrf_enabled?.should be_true

      # Should include OpenSSL dependency for CSRF
      deps = generator.dependencies
      deps.should contain("openssl")
    end

    it "validates RBAC integration" do
      generator = AzuCLI::Generate::Auth.new("testapp", "authly", "User", true, true)

      # RBAC should be enabled
      generator.rbac_enabled?.should be_true

      # Migration should include RBAC tables
      migration = generator.user_migration
      migration.should contain("schema.create :roles")
      migration.should contain("schema.create :permissions")
      migration.should contain("schema.create :user_roles")
      migration.should contain("schema.create :role_permissions")
    end

    it "validates OAuth integration" do
      generator = AzuCLI::Generate::Auth.new("testapp", "authly", "User", true, true, ["google", "github"])

      # OAuth providers should be configured
      generator.oauth_providers.should eq(["google", "github"])
      generator.google_oauth_enabled?.should be_true
      generator.github_oauth_enabled?.should be_true

      # Should include Authly dependency
      deps = generator.dependencies
      deps.should contain("authly")

      # Migration should include OAuth tables
      migration = generator.user_migration
      migration.should contain("schema.create :oauth_applications")
      migration.should contain("schema.create :oauth_access_tokens")
    end
  end

  describe "Template Processing Integration" do
    it "processes all template conditionals correctly" do
      generator = AzuCLI::Generate::Auth.new("testapp", "authly", "User", true, true, ["google"])

      # Verify all template conditionals are present
      migration = generator.user_migration

      # RBAC conditional
      migration.should contain("<%- if rbac_enabled? %>")

      # Authly conditional
      migration.should contain("<%- if using_authly? %>")

      # Template should include all necessary tables
      migration.should contain("schema.create :users")
      migration.should contain("schema.create :roles")
      migration.should contain("schema.create :permissions")
      migration.should contain("schema.create :oauth_applications")
    end

    it "generates consistent output for same configuration" do
      generator1 = AzuCLI::Generate::Auth.new("testapp", "authly", "User", true, true, ["google"])
      generator2 = AzuCLI::Generate::Auth.new("testapp", "authly", "User", true, true, ["google"])

      # Should generate identical output
      generator1.user_migration.should eq(generator2.user_migration)
      generator1.jwt_methods.should eq(generator2.jwt_methods)
      generator1.password_hash_method.should eq(generator2.password_hash_method)
      generator1.dependencies.should eq(generator2.dependencies)
    end
  end

  describe "Error Handling Integration" do
    it "handles invalid strategy gracefully" do
      # Test with unsupported strategy
      generator = AzuCLI::Generate::Auth.new("testapp", "invalid", "User")

      # Should default to supported features
      generator.using_jwt?.should be_false
      generator.using_session?.should be_false
      generator.using_oauth?.should be_false
      generator.using_authly?.should be_false
    end

    it "handles empty OAuth providers list" do
      generator = AzuCLI::Generate::Auth.new("testapp", "authly", "User", true, true, [] of String)

      generator.oauth_providers.should eq([] of String)
      generator.google_oauth_enabled?.should be_false
      generator.github_oauth_enabled?.should be_false
    end
  end

  describe "Performance Integration" do
    it "generates templates efficiently" do
      start_time = Time.monotonic

      # Generate multiple configurations
      100.times do |i|
        generator = AzuCLI::Generate::Auth.new(
          "testapp#{i}",
          "authly",
          "User",
          i % 2 == 0, # Alternate RBAC
          i % 2 == 1, # Alternate CSRF
          ["google"]
        )

        # Access all methods to ensure they're computed
        generator.user_migration
        generator.jwt_methods
        generator.password_hash_method
        generator.dependencies
      end

      end_time = Time.monotonic
      duration = end_time - start_time

      # Should complete within reasonable time (less than 1 second for 100 generations)
      duration.should be < 1.second
    end
  end
end
