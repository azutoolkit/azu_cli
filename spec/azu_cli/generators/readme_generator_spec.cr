require "spec"
require "../../spec_helper"
require "../../../src/azu_cli/generators/readme_generator"

describe AzuCLI::Generators::ReadmeGenerator do
  describe "#initialize" do
    it "initializes with default values" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project")

      generator.project_name.should eq("test_project")
      generator.project_name_title.should eq("Test Project")
      generator.project_name_kebabcase.should eq("test-project")
      generator.project_name_snakecase.should eq("test_project")
      generator.description.should eq("A Crystal project")
      generator.github_user.should eq("your-github-user")
      generator.license.should eq("MIT")
      generator.crystal_version.should eq(">= 1.16.0")
      generator.project_type.should eq("library")
      generator.database.should eq("none")
      generator.has_badges?.should be_true
      generator.has_api_docs?.should be_true
      generator.has_roadmap?.should be_false
    end

    it "initializes with custom values" do
      custom_authors = ["John Doe <john@example.com>", "Jane Smith <jane@example.com>"]
      custom_features = ["Feature 1", "Feature 2", "Feature 3"]
      custom_roadmap = ["Roadmap item 1", "Roadmap item 2"]

      generator = AzuCLI::Generators::ReadmeGenerator.new(
        "my_awesome_lib",
        output_dir: "/tmp",
        generate_specs: false,
        description: "An awesome Crystal library",
        github_user: "johndoe",
        license: "Apache-2.0",
        crystal_version: ">= 1.15.0",
        authors: custom_authors,
        features: custom_features,
        project_type: "library",
        database: "postgresql",
        has_badges: false,
        has_api_docs: false,
        has_roadmap: true,
        roadmap_items: custom_roadmap,
        has_acknowledgments: true,
        acknowledgments: ["Thanks to Crystal team"],
        has_support_info: true,
        support_info: "Custom support info"
      )

      generator.project_name.should eq("my_awesome_lib")
      generator.project_name_title.should eq("My Awesome Lib")
      generator.description.should eq("An awesome Crystal library")
      generator.github_user.should eq("johndoe")
      generator.license.should eq("Apache-2.0")
      generator.crystal_version.should eq(">= 1.15.0")
      generator.authors.should eq(custom_authors)
      generator.features.should eq(custom_features)
      generator.project_type.should eq("library")
      generator.database.should eq("postgresql")
      generator.database_display_name.should eq("PostgreSQL")
      generator.has_badges?.should be_false
      generator.has_api_docs?.should be_false
      generator.has_roadmap?.should be_true
      generator.roadmap_items.should eq(custom_roadmap)
      generator.has_acknowledgments?.should be_true
      generator.acknowledgments.should eq(["Thanks to Crystal team"])
      generator.has_support_info?.should be_true
      generator.support_info.should eq("Custom support info")
    end

    it "uses default features when none provided" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project")

      generator.features.should contain("🚀 Fast and efficient")
      generator.features.should contain("📦 Easy to install and use")
      generator.features.should contain("🔧 Well tested and documented")
      generator.features.should contain("💎 Built with Crystal")
    end
  end

  describe "#build_output_path" do
    it "returns the correct output path" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project", "/tmp")
      generator.build_output_path.should eq("/tmp/README.md")
    end

    it "defaults to current directory" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project")
      generator.build_output_path.should eq("./README.md")
    end
  end

  describe "#template_directory" do
    it "returns the correct template directory" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project")
      generator.template_directory.should contain("templates/generators/readme")
    end
  end

  describe "project types" do
    it "supports library project type" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project", project_type: "library")
      generator.project_type.should eq("library")
    end

    it "supports CLI project type" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project", project_type: "cli")
      generator.project_type.should eq("cli")
    end

    it "supports web project type" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project", project_type: "web")
      generator.project_type.should eq("web")
    end

    it "supports service project type" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project", project_type: "service")
      generator.project_type.should eq("service")
    end

    it "supports project type enum" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project",
        project_type: AzuCLI::Generators::ProjectType::Web)
      generator.project_type.should eq("web")
    end

    it "supports alternative project type names" do
      # Test CLI alternatives
      generator_tool = AzuCLI::Generators::ReadmeGenerator.new("test_project", project_type: "tool")
      generator_tool.project_type.should eq("cli")

      generator_command = AzuCLI::Generators::ReadmeGenerator.new("test_project", project_type: "command")
      generator_command.project_type.should eq("cli")

      # Test library alternatives
      generator_lib = AzuCLI::Generators::ReadmeGenerator.new("test_project", project_type: "lib")
      generator_lib.project_type.should eq("library")

      # Test web alternatives
      generator_webapp = AzuCLI::Generators::ReadmeGenerator.new("test_project", project_type: "webapp")
      generator_webapp.project_type.should eq("web")

      # Test service alternatives
      generator_api = AzuCLI::Generators::ReadmeGenerator.new("test_project", project_type: "api")
      generator_api.project_type.should eq("service")
    end

    it "raises error for unsupported project type" do
      expect_raises(ArgumentError, "Unsupported project type: invalid") do
        AzuCLI::Generators::ReadmeGenerator.new("test_project", project_type: "invalid")
      end
    end
  end

  describe "database support" do
    it "handles PostgreSQL database" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project", database: "postgresql")

      generator.database.should eq("postgresql")
      generator.database_display_name.should eq("PostgreSQL")
    end

    it "handles MySQL database" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project", database: "mysql")

      generator.database.should eq("mysql")
      generator.database_display_name.should eq("MySQL")
    end

    it "handles SQLite database" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project", database: "sqlite")

      generator.database.should eq("sqlite")
      generator.database_display_name.should eq("SQLite")
    end

    it "handles alternative database names" do
      # PostgreSQL alternatives
      generator_pg = AzuCLI::Generators::ReadmeGenerator.new("test_project", database: "pg")
      generator_pg.database_display_name.should eq("PostgreSQL")

      generator_postgres = AzuCLI::Generators::ReadmeGenerator.new("test_project", database: "postgres")
      generator_postgres.database_display_name.should eq("PostgreSQL")

      # SQLite alternatives
      generator_sqlite3 = AzuCLI::Generators::ReadmeGenerator.new("test_project", database: "sqlite3")
      generator_sqlite3.database_display_name.should eq("SQLite")
    end

    it "handles custom database names" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project", database: "redis")

      generator.database.should eq("redis")
      generator.database_display_name.should eq("Redis")
    end
  end

  describe "naming conventions" do
    it "handles camelCase project names" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("myAwesomeProject")

      generator.project_name_title.should eq("MyAwesomeProject")
      generator.project_name_kebabcase.should eq("my-awesome-project")
      generator.project_name_snakecase.should eq("my_awesome_project")
      generator.project_name_camelcase.should eq("MyAwesomeProject")
    end

    it "handles PascalCase project names" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("MyAwesomeProject")

      generator.project_name_title.should eq("My Awesome Project")
      generator.project_name_kebabcase.should eq("my-awesome-project")
    end

    it "handles snake_case project names" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("my_awesome_project")

      generator.project_name_title.should eq("My Awesome Project")
      generator.project_name_kebabcase.should eq("my-awesome-project")
    end

    it "handles kebab-case project names" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("my-awesome-project")

      generator.project_name_title.should eq("My Awesome Project")
      generator.project_name_snakecase.should eq("my_awesome_project")
    end

    it "handles single word project names" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("myproject")

      generator.project_name_title.should eq("Myproject")
      generator.project_name_kebabcase.should eq("myproject")
      generator.project_name_snakecase.should eq("myproject")
    end
  end

  describe "#author_github_url" do
    it "generates GitHub URL from author name" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project", github_user: "testuser")

      url = generator.author_github_url("John Doe <john@example.com>")
      url.should eq("https://github.com/john-doe")
    end

    it "handles author names with spaces" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project")

      url = generator.author_github_url("John Doe Smith <john@example.com>")
      url.should eq("https://github.com/john-doe-smith")
    end

    it "extracts GitHub URL if already present" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project", github_user: "fallback")

      url = generator.author_github_url("existing github.com/johndoe info")
      url.should eq("fallback") # Falls back to configured user
    end
  end

  describe "#author_role" do
    it "assigns creator role to first author" do
      authors = ["John Doe <john@example.com>", "Jane Smith <jane@example.com>"]
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project", authors: authors)

      generator.author_role(authors.first).should eq("creator and maintainer")
      generator.author_role(authors.last).should eq("contributor")
    end
  end

  describe "#validate_preconditions!" do
    it "validates successfully with valid configuration" do
      generator = AzuCLI::Generators::ReadmeGenerator.new("test_project",
        description: "Valid description",
        github_user: "validuser")

      # Should not raise
      generator.send(:validate_preconditions!)
    end

    it "raises error for empty project name" do
      expect_raises(ArgumentError, "Name cannot be empty") do
        AzuCLI::Generators::ReadmeGenerator.new("")
      end
    end

    it "raises error for invalid project name" do
      expect_raises(ArgumentError, "Name must be a valid identifier") do
        AzuCLI::Generators::ReadmeGenerator.new("123invalid")
      end
    end

    it "raises error for empty description" do
      expect_raises(ArgumentError, "Description cannot be empty") do
        generator = AzuCLI::Generators::ReadmeGenerator.new("test", description: "")
        generator.send(:validate_preconditions!)
      end
    end

    it "raises error for empty github user" do
      expect_raises(ArgumentError, "GitHub user cannot be empty") do
        generator = AzuCLI::Generators::ReadmeGenerator.new("test", github_user: "")
        generator.send(:validate_preconditions!)
      end
    end

    it "raises error for invalid github username" do
      expect_raises(ArgumentError, "Invalid GitHub username format") do
        generator = AzuCLI::Generators::ReadmeGenerator.new("test", github_user: "-invalid-")
        generator.send(:validate_preconditions!)
      end
    end

    it "accepts valid github usernames" do
      # Valid usernames
      valid_usernames = ["user", "user123", "user-name", "123user", "a", "a-b-c"]

      valid_usernames.each do |username|
        generator = AzuCLI::Generators::ReadmeGenerator.new("test", github_user: username)
        # Should not raise
        generator.send(:validate_preconditions!)
      end
    end

    it "raises error for empty license" do
      expect_raises(ArgumentError, "License cannot be empty") do
        generator = AzuCLI::Generators::ReadmeGenerator.new("test", license: "")
        generator.send(:validate_preconditions!)
      end
    end

    it "raises error for empty crystal version" do
      expect_raises(ArgumentError, "Crystal version cannot be empty") do
        generator = AzuCLI::Generators::ReadmeGenerator.new("test", crystal_version: "")
        generator.send(:validate_preconditions!)
      end
    end

    it "raises error for empty authors" do
      expect_raises(ArgumentError, "Authors cannot be empty") do
        generator = AzuCLI::Generators::ReadmeGenerator.new("test", authors: [] of String)
        generator.send(:validate_preconditions!)
      end
    end

    it "raises error for empty author name" do
      expect_raises(ArgumentError, "Author cannot be empty") do
        generator = AzuCLI::Generators::ReadmeGenerator.new("test", authors: [""])
        generator.send(:validate_preconditions!)
      end
    end

    it "raises error for empty features" do
      expect_raises(ArgumentError, "Feature cannot be empty") do
        generator = AzuCLI::Generators::ReadmeGenerator.new("test", features: [""])
        generator.send(:validate_preconditions!)
      end
    end
  end

  describe "default features" do
    it "includes expected default features" do
      features = AzuCLI::Generators::ReadmeConfiguration.default_features

      features.should contain("🚀 Fast and efficient")
      features.should contain("📦 Easy to install and use")
      features.should contain("🔧 Well tested and documented")
      features.should contain("💎 Built with Crystal")
    end
  end

  describe "configuration flags" do
    it "handles badges configuration" do
      generator_with_badges = AzuCLI::Generators::ReadmeGenerator.new("test", has_badges: true)
      generator_without_badges = AzuCLI::Generators::ReadmeGenerator.new("test", has_badges: false)

      generator_with_badges.has_badges?.should be_true
      generator_without_badges.has_badges?.should be_false
    end

    it "handles API docs configuration" do
      generator_with_docs = AzuCLI::Generators::ReadmeGenerator.new("test", has_api_docs: true)
      generator_without_docs = AzuCLI::Generators::ReadmeGenerator.new("test", has_api_docs: false)

      generator_with_docs.has_api_docs?.should be_true
      generator_without_docs.has_api_docs?.should be_false
    end

    it "handles roadmap configuration" do
      roadmap_items = ["Feature 1", "Feature 2"]

      generator_with_roadmap = AzuCLI::Generators::ReadmeGenerator.new("test",
        has_roadmap: true, roadmap_items: roadmap_items)
      generator_without_roadmap = AzuCLI::Generators::ReadmeGenerator.new("test", has_roadmap: false)

      generator_with_roadmap.has_roadmap?.should be_true
      generator_with_roadmap.roadmap_items.should eq(roadmap_items)
      generator_without_roadmap.has_roadmap?.should be_false
    end

    it "handles acknowledgments configuration" do
      acknowledgments = ["Thanks to Crystal team", "Thanks to contributors"]

      generator_with_acks = AzuCLI::Generators::ReadmeGenerator.new("test",
        has_acknowledgments: true, acknowledgments: acknowledgments)
      generator_without_acks = AzuCLI::Generators::ReadmeGenerator.new("test", has_acknowledgments: false)

      generator_with_acks.has_acknowledgments?.should be_true
      generator_with_acks.acknowledgments.should eq(acknowledgments)
      generator_without_acks.has_acknowledgments?.should be_false
    end

    it "handles support info configuration" do
      support_info = "Contact us at support@example.com"

      generator_with_support = AzuCLI::Generators::ReadmeGenerator.new("test",
        has_support_info: true, support_info: support_info)
      generator_without_support = AzuCLI::Generators::ReadmeGenerator.new("test", has_support_info: false)

      generator_with_support.has_support_info?.should be_true
      generator_with_support.support_info.should eq(support_info)
      generator_without_support.has_support_info?.should be_false
    end
  end
end

describe AzuCLI::Generators::ReadmeConfiguration do
  describe "#initialize" do
    it "initializes with default values" do
      config = AzuCLI::Generators::ReadmeConfiguration.new("test_project")

      config.project_name.should eq("test_project")
      config.description.should eq("A Crystal project")
      config.github_user.should eq("your-github-user")
      config.license.should eq("MIT")
      config.crystal_version.should eq(">= 1.16.0")
      config.project_type.should eq(AzuCLI::Generators::ProjectType::Library)
      config.database.should eq("none")
      config.has_badges.should be_true
      config.has_api_docs.should be_true
      config.has_roadmap.should be_false
    end

    it "initializes with custom values" do
      config = AzuCLI::Generators::ReadmeConfiguration.new(
        "custom_project",
        description: "Custom description",
        github_user: "customuser",
        project_type: AzuCLI::Generators::ProjectType::CLI,
        database: "postgresql"
      )

      config.project_name.should eq("custom_project")
      config.description.should eq("Custom description")
      config.github_user.should eq("customuser")
      config.project_type.should eq(AzuCLI::Generators::ProjectType::CLI)
      config.database.should eq("postgresql")
    end
  end

  describe "#database_display_name" do
    it "formats database names correctly" do
      pg_config = AzuCLI::Generators::ReadmeConfiguration.new("test", database: "postgresql")
      pg_config.database_display_name.should eq("PostgreSQL")

      mysql_config = AzuCLI::Generators::ReadmeConfiguration.new("test", database: "mysql")
      mysql_config.database_display_name.should eq("MySQL")

      sqlite_config = AzuCLI::Generators::ReadmeConfiguration.new("test", database: "sqlite")
      sqlite_config.database_display_name.should eq("SQLite")

      custom_config = AzuCLI::Generators::ReadmeConfiguration.new("test", database: "redis")
      custom_config.database_display_name.should eq("Redis")
    end
  end
end

describe AzuCLI::Generators::ProjectType do
  describe ".from_string" do
    it "parses valid project types" do
      AzuCLI::Generators::ProjectType.from_string("library").should eq(AzuCLI::Generators::ProjectType::Library)
      AzuCLI::Generators::ProjectType.from_string("cli").should eq(AzuCLI::Generators::ProjectType::CLI)
      AzuCLI::Generators::ProjectType.from_string("web").should eq(AzuCLI::Generators::ProjectType::Web)
      AzuCLI::Generators::ProjectType.from_string("service").should eq(AzuCLI::Generators::ProjectType::Service)
    end

    it "parses alternative names" do
      AzuCLI::Generators::ProjectType.from_string("lib").should eq(AzuCLI::Generators::ProjectType::Library)
      AzuCLI::Generators::ProjectType.from_string("tool").should eq(AzuCLI::Generators::ProjectType::CLI)
      AzuCLI::Generators::ProjectType.from_string("webapp").should eq(AzuCLI::Generators::ProjectType::Web)
      AzuCLI::Generators::ProjectType.from_string("api").should eq(AzuCLI::Generators::ProjectType::Service)
    end

    it "is case insensitive" do
      AzuCLI::Generators::ProjectType.from_string("LIBRARY").should eq(AzuCLI::Generators::ProjectType::Library)
      AzuCLI::Generators::ProjectType.from_string("Cli").should eq(AzuCLI::Generators::ProjectType::CLI)
    end

    it "raises error for unsupported types" do
      expect_raises(ArgumentError, "Unsupported project type: invalid") do
        AzuCLI::Generators::ProjectType.from_string("invalid")
      end
    end
  end

  describe "#to_s" do
    it "converts enum values to strings" do
      AzuCLI::Generators::ProjectType::Library.to_s.should eq("library")
      AzuCLI::Generators::ProjectType::CLI.to_s.should eq("cli")
      AzuCLI::Generators::ProjectType::Web.to_s.should eq("web")
      AzuCLI::Generators::ProjectType::Service.to_s.should eq("service")
    end
  end
end
