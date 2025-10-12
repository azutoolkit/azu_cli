require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Project do
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
      "GitLab CI",
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
    generator.ci_setup.should eq("GitLab CI")
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
end
