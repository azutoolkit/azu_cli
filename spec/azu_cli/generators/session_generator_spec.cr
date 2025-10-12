require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Session do
  it "creates a session generator with project name" do
    generator = AzuCLI::Generate::Session.new("myapp")

    generator.project.should eq("myapp")
    generator.backend.should eq("redis")
    generator.secret.should_not be_empty
  end

  it "creates a session generator with custom backend" do
    generator = AzuCLI::Generate::Session.new("myapp", "database")

    generator.backend.should eq("database")
  end

  it "creates a session generator with custom secret" do
    custom_secret = "my-secret-key-123"
    generator = AzuCLI::Generate::Session.new("myapp", "redis", custom_secret)

    generator.secret.should eq(custom_secret)
  end

  it "generates random secret by default" do
    generator = AzuCLI::Generate::Session.new("myapp")

    generator.secret.size.should eq(64) # hex(32) produces 64 chars
  end

  describe "#backend" do
    it "returns redis backend" do
      generator = AzuCLI::Generate::Session.new("myapp", "redis")

      generator.backend.should eq("redis")
    end

    it "returns database backend" do
      generator = AzuCLI::Generate::Session.new("myapp", "database")

      generator.backend.should eq("database")
    end

    it "returns memory backend" do
      generator = AzuCLI::Generate::Session.new("myapp", "memory")

      generator.backend.should eq("memory")
    end
  end

  describe "#dependencies" do
    it "returns redis for redis backend" do
      generator = AzuCLI::Generate::Session.new("myapp", "redis")

      generator.dependencies.should eq("redis")
    end

    it "returns cql for database backend" do
      generator = AzuCLI::Generate::Session.new("myapp", "database")

      generator.dependencies.should eq("cql")
    end

    it "returns empty string for memory backend" do
      generator = AzuCLI::Generate::Session.new("myapp", "memory")

      generator.dependencies.should be_empty
    end
  end

  describe "#needs_migration?" do
    it "returns true for database backend" do
      generator = AzuCLI::Generate::Session.new("myapp", "database")

      generator.needs_migration?.should be_true
    end

    it "returns false for redis backend" do
      generator = AzuCLI::Generate::Session.new("myapp", "redis")

      generator.needs_migration?.should be_false
    end

    it "returns false for memory backend" do
      generator = AzuCLI::Generate::Session.new("myapp", "memory")

      generator.needs_migration?.should be_false
    end
  end

  describe "#migration_content" do
    it "generates migration content" do
      generator = AzuCLI::Generate::Session.new("myapp", "database")

      migration = generator.migration_content
      migration.should contain("schema.create :sessions")
      migration.should contain("column :session_id")
      migration.should contain("column :data")
      migration.should contain("column :created_at")
      migration.should contain("column :updated_at")
      migration.should contain("column :expires_at")
      migration.should contain("add_index :sessions, :session_id")
      migration.should contain("add_index :sessions, :expires_at")
    end
  end
end
