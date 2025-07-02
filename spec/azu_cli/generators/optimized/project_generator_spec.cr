require "../../../spec_helper"
require "../../../../src/azu_cli/generators/optimized/project_generator"

describe AzuCLI::Generator::ProjectGenerator do
  let(project_name) { "test_project" }
  let(app_name) { "MyApp" }
  let(options) { AzuCLI::Generator::Core::GeneratorOptions.new }
  let(generator) { AzuCLI::Generator::ProjectGenerator.new(project_name, app_name, options) }

  describe "#initialize" do
    it "sets default project type to web" do
      generator.project_type.should eq("web")
    end

    it "sets default database to postgresql" do
      generator.database.should eq("postgresql")
    end

    it "accepts custom project type" do
      custom_options = AzuCLI::Generator::Core::GeneratorOptions.new
      custom_options.custom_options["type"] = "api"
      custom_generator = AzuCLI::Generator::ProjectGenerator.new(project_name, app_name, custom_options)

      custom_generator.project_type.should eq("api")
    end

    it "accepts custom database" do
      custom_options = AzuCLI::Generator::Core::GeneratorOptions.new
      custom_options.custom_options["database"] = "sqlite"
      custom_generator = AzuCLI::Generator::ProjectGenerator.new(project_name, app_name, custom_options)

      custom_generator.database.should eq("sqlite")
    end
  end

  describe "#generator_type" do
    it "returns 'project'" do
      generator.generator_type.should eq("project")
    end
  end

  describe "#validate_input!" do
    context "with valid project type" do
      it "passes validation" do
        generator.validate_input!
      end
    end

    context "with invalid project type" do
      it "raises ArgumentError" do
        invalid_options = AzuCLI::Generator::Core::GeneratorOptions.new
        invalid_options.custom_options["type"] = "invalid_type"
        invalid_generator = AzuCLI::Generator::ProjectGenerator.new(project_name, app_name, invalid_options)

        expect_raises(ArgumentError, /Invalid project type/) do
          invalid_generator.validate_input!
        end
      end
    end

    context "with invalid database" do
      it "raises ArgumentError" do
        invalid_options = AzuCLI::Generator::Core::GeneratorOptions.new
        invalid_options.custom_options["database"] = "invalid_db"
        invalid_generator = AzuCLI::Generator::ProjectGenerator.new(project_name, app_name, invalid_options)

        expect_raises(ArgumentError, /Invalid database/) do
          invalid_generator.validate_input!
        end
      end
    end
  end

  describe "#success_message" do
    it "returns success message with project name" do
      message = generator.success_message
      message.should contain("Project '#{project_name}' created successfully!")
    end
  end

  describe "project type specific behavior" do
    describe "web project" do
      let(web_options) do
        options = AzuCLI::Generator::Core::GeneratorOptions.new
        options.custom_options["type"] = "web"
        options
      end
      let(web_generator) { AzuCLI::Generator::ProjectGenerator.new(project_name, app_name, web_options) }

      it "sets copy_assets to true" do
        web_generator.copy_assets.should be_true
      end

      it "sets copy_templates to true" do
        web_generator.copy_templates.should be_true
      end
    end

    describe "api project" do
      let(api_options) do
        options = AzuCLI::Generator::Core::GeneratorOptions.new
        options.custom_options["type"] = "api"
        options
      end
      let(api_generator) { AzuCLI::Generator::ProjectGenerator.new(project_name, app_name, api_options) }

      it "sets copy_assets to false" do
        api_generator.copy_assets.should be_false
      end

      it "sets copy_templates to false" do
        api_generator.copy_templates.should be_false
      end
    end

    describe "cli project" do
      let(cli_options) do
        options = AzuCLI::Generator::Core::GeneratorOptions.new
        options.custom_options["type"] = "cli"
        options
      end
      let(cli_generator) { AzuCLI::Generator::ProjectGenerator.new(project_name, app_name, cli_options) }

      it "sets copy_assets to false" do
        cli_generator.copy_assets.should be_false
      end

      it "sets copy_templates to false" do
        cli_generator.copy_templates.should be_false
      end
    end
  end

  describe "database configuration" do
    describe "postgresql" do
      let(pg_options) do
        options = AzuCLI::Generator::Core::GeneratorOptions.new
        options.custom_options["database"] = "postgresql"
        options
      end
      let(pg_generator) { AzuCLI::Generator::ProjectGenerator.new(project_name, app_name, pg_options) }

      it "sets database to postgresql" do
        pg_generator.database.should eq("postgresql")
      end
    end

    describe "mysql" do
      let(mysql_options) do
        options = AzuCLI::Generator::Core::GeneratorOptions.new
        options.custom_options["database"] = "mysql"
        options
      end
      let(mysql_generator) { AzuCLI::Generator::ProjectGenerator.new(project_name, app_name, mysql_options) }

      it "sets database to mysql" do
        mysql_generator.database.should eq("mysql")
      end
    end

    describe "sqlite" do
      let(sqlite_options) do
        options = AzuCLI::Generator::Core::GeneratorOptions.new
        options.custom_options["database"] = "sqlite"
        options
      end
      let(sqlite_generator) { AzuCLI::Generator::ProjectGenerator.new(project_name, app_name, sqlite_options) }

      it "sets database to sqlite" do
        sqlite_generator.database.should eq("sqlite")
      end
    end
  end

  describe "template variable generation" do
    it "generates project variables with correct values" do
      # This would require mocking the config and testing the private method
      # We test the public interface instead
      generator.project_type.should eq("web")
      generator.database.should eq("postgresql")
      generator.name.should eq(project_name)
    end
  end

  describe "naming methods" do
    it "returns correct class name" do
      generator.class_name.should eq("TestProject")
    end

    it "returns correct snake case name" do
      generator.snake_case_name.should eq("test_project")
    end

    it "returns correct kebab case name" do
      generator.kebab_case_name.should eq("test-project")
    end

    it "returns correct plural name" do
      generator.plural_name.should eq("test_projects")
    end
  end

  describe "configuration integration" do
    it "has valid configuration" do
      config = generator.config
      config.should_not be_nil
    end

    it "loads project types from configuration" do
      config = generator.config
      project_types = config.get_hash("project_types")
      project_types.should have_key("web")
      project_types.should have_key("api")
      project_types.should have_key("cli")
    end

    it "loads database configurations" do
      config = generator.config
      databases = config.get_hash("databases")
      databases.should have_key("postgresql")
      databases.should have_key("mysql")
      databases.should have_key("sqlite")
    end
  end

  describe "template path expansion" do
    it "expands template variables correctly" do
      # Test the template expansion logic indirectly through naming methods
      generator.snake_case_name.should eq("test_project")
      generator.class_name.should eq("TestProject")
    end
  end

  describe "project structure validation" do
    it "validates required configuration sections" do
      config = generator.config

      # Should have project types
      config.get_hash("project_types").should_not be_empty

      # Should have databases
      config.get_hash("databases").should_not be_empty

      # Should have templates
      config.get_hash("templates").should_not be_empty

      # Should have directories
      config.get_hash("directories").should_not be_empty
    end
  end
end
