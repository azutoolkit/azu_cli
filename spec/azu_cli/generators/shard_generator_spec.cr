require "spec"
require "../../spec_helper"
require "../../../src/azu_cli/generators/shard_generator"

describe AzuCLI::Generators::ShardGenerator do
  describe "#initialize" do
    it "initializes with default values" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app")

      generator.name.should eq("test_app")
      generator.app_name.should eq("test_app")
      generator.app_name_kebabcase.should eq("test-app")
      generator.version.should eq("0.1.0")
      generator.crystal_version.should eq(">= 1.16.0")
      generator.license.should eq("MIT")
      generator.authors.should eq(["Your Name <your@email.com>"])
    end

    it "initializes with custom values" do
      custom_authors = ["John Doe <john@example.com>", "Jane Smith <jane@example.com>"]
      custom_deps = {"custom" => "user/custom"}

      generator = AzuCLI::Generators::ShardGenerator.new(
        "my_app",
        output_dir: "/tmp",
        generate_specs: false,
        version: "1.0.0",
        crystal_version: ">= 1.15.0",
        license: "Apache-2.0",
        authors: custom_authors,
        dependencies: custom_deps,
        database: "mysql"
      )

      generator.app_name.should eq("my_app")
      generator.app_name_kebabcase.should eq("my-app")
      generator.version.should eq("1.0.0")
      generator.crystal_version.should eq(">= 1.15.0")
      generator.license.should eq("Apache-2.0")
      generator.authors.should eq(custom_authors)
      generator.database.should eq("mysql")
      generator.database_shard.should eq("mysql")
      # Should include both custom deps and framework deps + database deps
      generator.dependencies.should have_key("custom")
      generator.dependencies.should have_key("azu")
      generator.dependencies.should have_key("mysql")
    end
  end

  describe "#build_output_path" do
    it "returns the correct output path" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app", "/tmp")
      generator.build_output_path.should eq("/tmp/shard.yml")
    end

    it "defaults to current directory" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app")
      generator.build_output_path.should eq("./shard.yml")
    end
  end

  describe "#template_directory" do
    it "returns the correct template directory" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app")
      generator.template_directory.should contain("templates/generators/shard")
    end
  end

  describe "#validate_preconditions!" do
    it "validates successfully with valid configuration" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app")
      expect_raises(ArgumentError) { generator.validate_preconditions! }
    end

    it "raises error for empty app name" do
      expect_raises(ArgumentError, "Name cannot be empty") do
        AzuCLI::Generators::ShardGenerator.new("")
      end
    end

    it "raises error for invalid app name" do
      expect_raises(ArgumentError, "Name must be a valid identifier") do
        AzuCLI::Generators::ShardGenerator.new("123invalid")
      end
    end

    it "raises error for empty version" do
      expect_raises(ArgumentError, "Version cannot be empty") do
        generator = AzuCLI::Generators::ShardGenerator.new("test", version: "")
        generator.send(:validate_preconditions!)
      end
    end

    it "raises error for empty crystal version" do
      expect_raises(ArgumentError, "Crystal version cannot be empty") do
        generator = AzuCLI::Generators::ShardGenerator.new("test", crystal_version: "")
        generator.send(:validate_preconditions!)
      end
    end

    it "raises error for empty license" do
      expect_raises(ArgumentError, "License cannot be empty") do
        generator = AzuCLI::Generators::ShardGenerator.new("test", license: "")
        generator.send(:validate_preconditions!)
      end
    end

    it "raises error for empty authors" do
      expect_raises(ArgumentError, "Authors cannot be empty") do
        generator = AzuCLI::Generators::ShardGenerator.new("test", authors: [] of String)
        generator.send(:validate_preconditions!)
      end
    end

    it "raises error for empty author name" do
      expect_raises(ArgumentError, "Author cannot be empty") do
        generator = AzuCLI::Generators::ShardGenerator.new("test", authors: [""])
        generator.send(:validate_preconditions!)
      end
    end

    it "raises error for invalid dependency format" do
      expect_raises(ArgumentError, "Invalid GitHub repository format") do
        invalid_deps = {"test" => "invalid/repo/format"}
        generator = AzuCLI::Generators::ShardGenerator.new("test", dependencies: invalid_deps)
        generator.send(:validate_preconditions!)
      end
    end
  end

  describe "configuration methods" do
    it "checks for dependencies" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app")
      generator.has_dependencies?.should be_true
    end

    it "checks for dev dependencies" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app")
      generator.has_dev_dependencies?.should be_true
    end

    it "checks for targets" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app")
      generator.has_targets?.should be_true
    end

    it "handles empty dependencies" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app", dependencies: {} of String => String)
      generator.has_dependencies?.should be_false
    end
  end

  describe "naming conventions" do
    it "handles camelCase app names" do
      generator = AzuCLI::Generators::ShardGenerator.new("testApp")
      generator.app_name_kebabcase.should eq("test-app")
    end

    it "handles PascalCase app names" do
      generator = AzuCLI::Generators::ShardGenerator.new("TestApp")
      generator.app_name_kebabcase.should eq("test-app")
    end

    it "handles snake_case app names" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app")
      generator.app_name_kebabcase.should eq("test-app")
    end

    it "handles already kebab-case app names" do
      generator = AzuCLI::Generators::ShardGenerator.new("test-app")
      generator.app_name_kebabcase.should eq("test-app")
    end
  end

  describe "database support" do
    it "defaults to PostgreSQL" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app")

      generator.database.should eq("postgresql")
      generator.database_shard.should eq("pg")
      generator.dependencies.should have_key("pg")
      generator.dependencies["pg"].should eq("will/crystal-pg")
    end

    it "supports MySQL" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app", database: "mysql")

      generator.database.should eq("mysql")
      generator.database_shard.should eq("mysql")
      generator.dependencies.should have_key("mysql")
      generator.dependencies["mysql"].should eq("crystal-lang/crystal-mysql")
      generator.dependencies.should_not have_key("pg")
      generator.dependencies.should_not have_key("sqlite3")
    end

    it "supports SQLite" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app", database: "sqlite")

      generator.database.should eq("sqlite")
      generator.database_shard.should eq("sqlite3")
      generator.dependencies.should have_key("sqlite3")
      generator.dependencies["sqlite3"].should eq("crystal-lang/crystal-sqlite3")
      generator.dependencies.should_not have_key("pg")
      generator.dependencies.should_not have_key("mysql")
    end

    it "supports database enum types" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app", database: AzuCLI::Generators::DatabaseType::MySQL)

      generator.database.should eq("mysql")
      generator.database_shard.should eq("mysql")
      generator.dependencies.should have_key("mysql")
    end

    it "supports alternative database names" do
      # Test PostgreSQL alternatives
      generator_pg = AzuCLI::Generators::ShardGenerator.new("test_app", database: "postgres")
      generator_pg.database.should eq("postgresql")

      generator_pg2 = AzuCLI::Generators::ShardGenerator.new("test_app", database: "pg")
      generator_pg2.database.should eq("postgresql")

      # Test SQLite alternatives
      generator_sqlite = AzuCLI::Generators::ShardGenerator.new("test_app", database: "sqlite3")
      generator_sqlite.database.should eq("sqlite")
    end

    it "raises error for unsupported database" do
      expect_raises(ArgumentError, "Unsupported database type: mongodb") do
        AzuCLI::Generators::ShardGenerator.new("test_app", database: "mongodb")
      end
    end
  end

  describe "default dependencies" do
    it "includes Azu framework dependencies" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app")

      generator.dependencies.should have_key("azu")
      generator.dependencies.should have_key("topia")
      generator.dependencies.should have_key("cql")
      generator.dependencies.should have_key("session")
    end

    it "includes development dependencies" do
      generator = AzuCLI::Generators::ShardGenerator.new("test_app")

      generator.dev_dependencies.should have_key("webmock")
      generator.dev_dependencies.should have_key("ameba")
    end

    it "includes database-specific dependencies" do
      pg_generator = AzuCLI::Generators::ShardGenerator.new("test_app", database: "postgresql")
      pg_generator.dependencies.should have_key("pg")

      mysql_generator = AzuCLI::Generators::ShardGenerator.new("test_app", database: "mysql")
      mysql_generator.dependencies.should have_key("mysql")

      sqlite_generator = AzuCLI::Generators::ShardGenerator.new("test_app", database: "sqlite")
      sqlite_generator.dependencies.should have_key("sqlite3")
    end
  end

  describe "target generation" do
    it "generates correct targets" do
      generator = AzuCLI::Generators::ShardGenerator.new("my_cool_app")

      generator.targets.should have_key("my-cool-app")
      generator.targets["my-cool-app"].should eq("src/my_cool_app.cr")
    end
  end
end

describe AzuCLI::Generators::ShardConfiguration do
  describe "#initialize" do
    it "initializes with default values" do
      config = AzuCLI::Generators::ShardConfiguration.new

      config.version.should eq("0.1.0")
      config.crystal_version.should eq(">= 1.16.0")
      config.license.should eq("MIT")
      config.authors.should eq(["Your Name <your@email.com>"])
      config.has_dependencies?.should be_true
      config.has_dev_dependencies?.should be_true
    end

    it "initializes with custom values" do
      custom_deps = {"custom" => "user/custom"}
      config = AzuCLI::Generators::ShardConfiguration.new(
        version: "2.0.0",
        dependencies: custom_deps
      )

      config.version.should eq("2.0.0")
      config.dependencies.should eq(custom_deps)
    end
  end

  describe "helper methods" do
    it "detects empty dependencies" do
      config = AzuCLI::Generators::ShardConfiguration.new(dependencies: {} of String => String)
      config.has_dependencies?.should be_false
    end

    it "detects empty dev dependencies" do
      config = AzuCLI::Generators::ShardConfiguration.new(dev_dependencies: {} of String => String)
      config.has_dev_dependencies?.should be_false
    end
  end
end
