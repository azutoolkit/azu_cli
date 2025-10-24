require "../../spec_helper"
require "../../support/test_helpers"

describe AzuCLI::Commands::New do
  describe "#initialize" do
    it "sets up new command properties" do
      command = AzuCLI::Commands::New.new

      command.name.should eq("new")
      command.description.should eq("Create a new Azu project")
      command.project_name.should eq("")
      command.module_name.should eq("")
      command.author.should eq("")
      command.email.should eq("")
      command.license.should eq("MIT")
      command.project_type.should eq("web")
      command.database.should eq("postgresql")
      command.test_framework.should eq("spec")
      command.ci_setup.should eq("GitHub Actions")
      command.docker_support.should be_false
      command.git_init.should be_true
      command.include_example.should be_true
      command.include_joobq.should be_true
      command.non_interactive.should be_false
    end
  end

  describe "#execute" do
    it "creates new project with valid name" do
      TestHelpers::TestSetup.with_temp_project("new_test_project") do |temp_project|
        # Change to parent directory to simulate creating new project
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
          result.message.should contain("Project created successfully")
        end

        # Verify project was created
        project_path = File.join(parent_dir, "test_project")
        Dir.exists?(project_path).should be_true
        File.exists?(File.join(project_path, "shard.yml")).should be_true
      end
    end

    it "validates project name format" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["invalid-project-name!"])

      TestHelpers::TestSetup.with_captured_output do |capture|
        result = command.execute
        result.success?.should be_false
        result.error.should contain("Invalid project name")
        result.error.should contain("Use only letters, numbers, underscores, and hyphens")
      end
    end

    it "requires project name" do
      command = AzuCLI::Commands::New.new
      command.parse_args([] of String)

      TestHelpers::TestSetup.with_captured_output do |capture|
        result = command.execute
        result.success?.should be_false
        result.error.should contain("Project name is required")
        result.error.should contain("Usage: azu new <project-name>")
      end
    end

    it "handles existing directory" do
      TestHelpers::TestSetup.with_temp_project("existing_project") do |temp_project|
        # Create a directory that already exists
        existing_path = File.join(File.dirname(temp_project.path), "existing_project")
        Dir.mkdir_p(existing_path)

        command = AzuCLI::Commands::New.new
        command.parse_args(["existing_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_false
          result.error.should contain("Directory already exists")
        end
      end
    end

    it "generates module name from project name" do
      TestHelpers::TestSetup.with_temp_project("module_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        # Verify module name was generated
        command.module_name.should eq("TestProject")
      end
    end

    it "handles non-interactive mode" do
      TestHelpers::TestSetup.with_temp_project("non_interactive_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--non-interactive", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        # Should use default values without prompting
        command.non_interactive.should be_true
      end
    end

    it "handles project type selection" do
      TestHelpers::TestSetup.with_temp_project("api_project") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--type", "api", "test_api"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        command.project_type.should eq("api")
      end
    end

    it "handles database selection" do
      TestHelpers::TestSetup.with_temp_project("mysql_project") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--database", "mysql", "test_mysql"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        command.database.should eq("mysql")
      end
    end

    it "handles author and email options" do
      TestHelpers::TestSetup.with_temp_project("author_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--author", "Test Author", "--email", "test@example.com", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        command.author.should eq("Test Author")
        command.email.should eq("test@example.com")
      end
    end

    it "handles license selection" do
      TestHelpers::TestSetup.with_temp_project("license_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--license", "Apache-2.0", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        command.license.should eq("Apache-2.0")
      end
    end

    it "handles docker support flag" do
      TestHelpers::TestSetup.with_temp_project("docker_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--docker", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        command.docker_support.should be_true
      end
    end

    it "handles skip git flag" do
      TestHelpers::TestSetup.with_temp_project("no_git_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--no-git", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        command.git_init.should be_false
      end
    end

    it "handles skip example flag" do
      TestHelpers::TestSetup.with_temp_project("no_example_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--no-example", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        command.include_example.should be_false
      end
    end

    it "handles skip joobq flag" do
      TestHelpers::TestSetup.with_temp_project("no_joobq_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--no-joobq", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        command.include_joobq.should be_false
      end
    end
  end

  describe "project structure creation" do
    it "creates complete project structure" do
      TestHelpers::TestSetup.with_temp_project("structure_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        project_path = File.join(parent_dir, "test_project")

        # Verify main files exist
        File.exists?(File.join(project_path, "shard.yml")).should be_true
        File.exists?(File.join(project_path, "README.md")).should be_true
        File.exists?(File.join(project_path, "LICENSE")).should be_true

        # Verify directory structure
        Dir.exists?(File.join(project_path, "src")).should be_true
        Dir.exists?(File.join(project_path, "spec")).should be_true
        Dir.exists?(File.join(project_path, "config")).should be_true
        Dir.exists?(File.join(project_path, "db")).should be_true
        Dir.exists?(File.join(project_path, "public")).should be_true
      end
    end

    it "creates web project structure" do
      TestHelpers::TestSetup.with_temp_project("web_structure_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--type", "web", "test_web"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        project_path = File.join(parent_dir, "test_web")

        # Verify web-specific structure
        Dir.exists?(File.join(project_path, "src/pages")).should be_true
        Dir.exists?(File.join(project_path, "public/templates")).should be_true
        Dir.exists?(File.join(project_path, "public/assets")).should be_true
      end
    end

    it "creates API project structure" do
      TestHelpers::TestSetup.with_temp_project("api_structure_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--type", "api", "test_api"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        project_path = File.join(parent_dir, "test_api")

        # Verify API-specific structure
        Dir.exists?(File.join(project_path, "src/endpoints")).should be_true
        Dir.exists?(File.join(project_path, "src/requests")).should be_true
        Dir.exists?(File.join(project_path, "src/responses")).should be_true
      end
    end
  end

  describe "template rendering" do
    it "renders shard.yml with project details" do
      TestHelpers::TestSetup.with_temp_project("template_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--author", "Test Author", "--email", "test@example.com", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        project_path = File.join(parent_dir, "test_project")
        shard_content = File.read(File.join(project_path, "shard.yml"))

        shard_content.should contain("name: test_project")
        shard_content.should contain("Test Author")
        shard_content.should contain("test@example.com")
      end
    end

    it "renders README with project information" do
      TestHelpers::TestSetup.with_temp_project("readme_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        project_path = File.join(parent_dir, "test_project")
        readme_content = File.read(File.join(project_path, "README.md"))

        readme_content.should contain("test_project")
        readme_content.should contain("Azu")
      end
    end
  end

  describe "git initialization" do
    it "initializes git repository by default" do
      TestHelpers::TestSetup.with_temp_project("git_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        project_path = File.join(parent_dir, "test_project")
        Dir.exists?(File.join(project_path, ".git")).should be_true
      end
    end

    it "skips git initialization when --no-git flag is used" do
      TestHelpers::TestSetup.with_temp_project("no_git_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--no-git", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
        end

        project_path = File.join(parent_dir, "test_project")
        Dir.exists?(File.join(project_path, ".git")).should be_false
      end
    end
  end

  describe "dependency installation" do
    it "installs dependencies after project creation" do
      TestHelpers::TestSetup.with_temp_project("deps_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
          capture.stderr.should contain("Installing dependencies")
        end
      end
    end
  end

  describe "error handling" do
    it "handles invalid project names" do
      invalid_names = ["", "invalid name", "invalid@name", "invalid.name", "123invalid"]

      invalid_names.each do |name|
        command = AzuCLI::Commands::New.new
        command.parse_args([name])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_false
          result.error.should contain("Invalid project name")
        end
      end
    end

    it "handles existing directories" do
      TestHelpers::TestSetup.with_temp_project("existing_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        # Create existing directory
        existing_path = File.join(parent_dir, "existing_project")
        Dir.mkdir_p(existing_path)

        command = AzuCLI::Commands::New.new
        command.parse_args(["existing_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_false
          result.error.should contain("Directory already exists")
        end
      end
    end
  end

  describe "logging" do
    it "logs project creation steps" do
      TestHelpers::TestSetup.with_temp_project("logging_test") do |temp_project|
        parent_dir = File.dirname(temp_project.path)
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
          capture.stderr.should contain("Creating project")
          capture.stderr.should contain("Project created successfully")
        end
      end
    end
  end
end
