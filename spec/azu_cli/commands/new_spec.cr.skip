require "../../spec_helper"
require "file_utils"

# Test directory for isolating project generation
NEW_TEST_DIR = "./tmp_new_test"

describe AzuCLI::Commands::New do
  # Clean up before and after each test
  before_each do
    FileUtils.rm_rf(NEW_TEST_DIR) if Dir.exists?(NEW_TEST_DIR)
    FileUtils.mkdir_p(NEW_TEST_DIR)
    Dir.cd(NEW_TEST_DIR)
  end

  after_each do
    Dir.cd("..")
    FileUtils.rm_rf(NEW_TEST_DIR) if Dir.exists?(NEW_TEST_DIR)
  end

  describe "#execute" do
    it "requires project name" do
      command = AzuCLI::Commands::New.new
      command.parse_args([] of String)

      result = command.execute

      result.success?.should be_false
      result.error.should contain("Project name is required")
    end

    it "validates project name format" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["invalid project name!"])

      result = command.execute

      result.success?.should be_false
      result.error.should contain("Invalid project name")
    end

    it "rejects project names with special characters" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["project@name"])

      result = command.execute

      result.success?.should be_false
    end

    it "accepts valid project names with underscores" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["my_project", "--yes"])

      result = command.execute

      result.success?.should be_true
    end

    it "accepts valid project names with hyphens" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["my-project", "--yes"])

      result = command.execute

      result.success?.should be_true
    end

    it "fails if directory already exists" do
      Dir.mkdir("existing_project")

      command = AzuCLI::Commands::New.new
      command.parse_args(["existing_project", "--yes"])

      result = command.execute

      result.success?.should be_false
      result.error.should contain("already exists")
    end

    it "parses --type option" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["test_api", "--type", "api", "--yes"])

      command.project_type.should eq("api")
    end

    it "parses --api shorthand" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["test_api", "--api", "--yes"])

      command.project_type.should eq("api")
    end

    it "parses --db option" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["test_project", "--db", "mysql", "--yes"])

      command.database.should eq("mysql")
    end

    it "parses --no-git option" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["test_project", "--no-git", "--yes"])

      command.git_init.should be_false
    end

    it "parses --docker option" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["test_project", "--docker", "--yes"])

      command.docker_support.should be_true
    end

    it "parses --no-joobq option" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["test_project", "--no-joobq", "--yes"])

      command.include_joobq.should be_false
    end

    it "uses non-interactive mode with --yes" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["test_project", "--yes"])

      command.non_interactive.should be_true
    end

    it "parses --name option" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["--name", "my_app", "--yes"])

      command.project_name.should eq("my_app")
    end

    it "parses --author and --email options" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["test_project", "--author", "John Doe", "--email", "john@example.com", "--yes"])

      command.author.should eq("John Doe")
      command.email.should eq("john@example.com")
    end

    it "parses --license option" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["test_project", "--license", "Apache-2.0", "--yes"])

      command.license.should eq("Apache-2.0")
    end
  end

  describe "#show_help" do
    it "displays help information" do
      command = AzuCLI::Commands::New.new

      # Just ensure it doesn't crash
      command.show_help
    end
  end
end
