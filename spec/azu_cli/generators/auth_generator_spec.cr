require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Auth do
  it "creates an auth generator with default strategy" do
    generator = AzuCLI::Generate::Auth.new("myapp")

    generator.project.should eq("myapp")
    generator.strategy.should eq("jwt")
    generator.user_model.should eq("User")
  end

  it "creates an auth generator with custom strategy" do
    generator = AzuCLI::Generate::Auth.new("myapp", "session")

    generator.strategy.should eq("session")
  end

  it "creates an auth generator with custom user model" do
    generator = AzuCLI::Generate::Auth.new("myapp", "jwt", "Account")

    generator.user_model.should eq("Account")
  end

  describe "strategy detection" do
    it "detects JWT strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "jwt")

      generator.using_jwt?.should be_true
      generator.using_session?.should be_false
      generator.using_oauth?.should be_false
    end

    it "detects session strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "session")

      generator.using_jwt?.should be_false
      generator.using_session?.should be_true
      generator.using_oauth?.should be_false
    end

    it "detects OAuth strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "oauth")

      generator.using_jwt?.should be_false
      generator.using_session?.should be_false
      generator.using_oauth?.should be_true
    end
  end

  describe "#password_hash_method" do
    it "generates password hashing methods" do
      generator = AzuCLI::Generate::Auth.new("myapp")

      methods = generator.password_hash_method
      methods.should contain("hash_password")
      methods.should contain("verify_password")
      methods.should contain("Crypto::Bcrypt::Password")
    end
  end

  describe "#jwt_methods" do
    it "generates JWT methods for JWT strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "jwt")

      methods = generator.jwt_methods
      methods.should contain("generate_token")
      methods.should contain("verify_token")
      methods.should contain("JWT.encode")
      methods.should contain("JWT.decode")
    end

    it "returns empty string for non-JWT strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "session")

      methods = generator.jwt_methods
      methods.should be_empty
    end
  end

  describe "#dependencies" do
    it "includes bcrypt for all strategies" do
      generator = AzuCLI::Generate::Auth.new("myapp", "session")

      deps = generator.dependencies
      deps.should contain("crypto/bcrypt")
    end

    it "includes JWT for JWT strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "jwt")

      deps = generator.dependencies
      deps.should contain("crypto/bcrypt")
      deps.should contain("jwt")
    end

    it "does not include JWT for session strategy" do
      generator = AzuCLI::Generate::Auth.new("myapp", "session")

      deps = generator.dependencies
      deps.should_not contain("jwt")
    end
  end

  describe "#user_migration" do
    it "generates user migration content" do
      generator = AzuCLI::Generate::Auth.new("myapp")

      migration = generator.user_migration
      migration.should contain("schema.create :users")
      migration.should contain("column :email")
      migration.should contain("column :password_hash")
      migration.should contain("column :name")
      migration.should contain("column :role")
      migration.should contain("column :confirmed_at")
      migration.should contain("column :locked_at")
      migration.should contain("column :created_at")
      migration.should contain("column :updated_at")
      migration.should contain("add_index :users, :email")
      migration.should contain("add_index :users, :role")
    end
  end
end
