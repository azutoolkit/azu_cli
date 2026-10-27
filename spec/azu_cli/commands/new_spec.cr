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
      command.database.should eq("sqlite")
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
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
          result.message.should contain("Project 'test_project' created successfully")
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

      TestHelpers::TestSetup.with_captured_output do |_|
        result = command.execute
        result.success?.should be_false
        result.error.should contain("Invalid project name")
        result.error.should contain("Start with a letter")
      end
    end

    it "requires project name" do
      command = AzuCLI::Commands::New.new
      command.parse_args([] of String)

      TestHelpers::TestSetup.with_captured_output do |_|
        result = command.execute
        result.success?.should be_false
        result.error.should contain("Project name is required")
        result.error.should contain("Usage: azu new <project-name>")
      end
    end

    it "handles existing directory" do
      TestHelpers::TestSetup.with_temp_project("existing_project") do |temp_project|
        # Create a directory that already exists
        Dir.cd(temp_project.path)
        Dir.mkdir_p("existing_project")

        command = AzuCLI::Commands::New.new
        command.parse_args(["existing_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_false
          result.error.should contain("Directory 'existing_project' already exists")
        end
      end
    end

    it "generates module name from project name" do
      TestHelpers::TestSetup.with_temp_project("module_test") do |temp_project|
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        # Verify module name was generated
        command.module_name.should eq("TestProject")
      end
    end

    it "handles non-interactive mode" do
      TestHelpers::TestSetup.with_temp_project("non_interactive_test") do |temp_project|
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        # Should use default values without prompting
        command.non_interactive.should be_true
      end
    end

    it "handles project type selection" do
      TestHelpers::TestSetup.with_temp_project("api_project") do |temp_project|
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "--type", "api", "test_api"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        command.project_type.should eq("api")
      end
    end

    it "handles database selection" do
      TestHelpers::TestSetup.with_temp_project("mysql_project") do |temp_project|
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "--db", "mysql", "test_mysql"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        command.database.should eq("mysql")
      end
    end

    it "handles author and email options" do
      TestHelpers::TestSetup.with_temp_project("author_test") do |temp_project|
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "--author", "Test Author", "--email", "test@example.com", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        command.author.should eq("Test Author")
        command.email.should eq("test@example.com")
      end
    end

    it "handles license selection" do
      TestHelpers::TestSetup.with_temp_project("license_test") do |temp_project|
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "--license", "Apache-2.0", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        command.license.should eq("Apache-2.0")
      end
    end

    it "handles docker support flag" do
      TestHelpers::TestSetup.with_temp_project("docker_test") do |temp_project|
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "--docker", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        command.docker_support.should be_true
      end
    end

    it "writes a Dockerfile with --docker and a workflow by default" do
      TestHelpers::TestSetup.with_temp_project("delivery_test") do |temp_project|
        Dir.cd(temp_project.path) do
          command = AzuCLI::Commands::New.new
          command.parse_args(["--yes", "--docker", "--no-git", "delivery_app"])

          TestHelpers::TestSetup.with_captured_output do |_|
            command.execute.success?.should be_true
          end

          File.exists?("delivery_app/Dockerfile").should be_true
          File.exists?("delivery_app/.dockerignore").should be_true
          File.exists?("delivery_app/.github/workflows/ci.yml").should be_true
        end
      end
    end

    it "writes neither with --no-ci and without --docker" do
      TestHelpers::TestSetup.with_temp_project("no_delivery_test") do |temp_project|
        Dir.cd(temp_project.path) do
          command = AzuCLI::Commands::New.new
          command.parse_args(["--yes", "--no-ci", "--no-git", "plain_app"])

          TestHelpers::TestSetup.with_captured_output do |_|
            command.execute.success?.should be_true
          end

          File.exists?("plain_app/Dockerfile").should be_false
          Dir.exists?("plain_app/.github").should be_false
        end
      end
    end

    it "creates a cli project without a database, also with --db sqlite --yes" do
      TestHelpers::TestSetup.with_temp_project("cli_sqlite_test") do |temp_project|
        Dir.cd(temp_project.path) do
          cli = AzuCLI::Commands::New.new
          cli.parse_args(["--yes", "--type", "cli", "--db", "sqlite", "--no-git", "tool_app"])
          TestHelpers::TestSetup.with_captured_output do |_|
            cli.execute.success?.should be_true
          end

          File.exists?("tool_app/src/tool_app.cr").should be_true
          File.read("tool_app/shard.yml").should_not contain("sqlite3")
          File.exists?("tool_app/src/server.cr").should be_false
          File.exists?("tool_app/.env").should be_false
        end
      end
    end

    it "tells a cli project to build with shards and run bin/<name>" do
      command = AzuCLI::Commands::New.new
      command.project_name = "my-tool"
      command.project_type = "cli"
      command.next_steps.should eq ["cd my-tool", "shards build", "./bin/my_tool --help"]
    end

    it "refuses a project type that is not web, api or cli" do
      TestHelpers::TestSetup.with_temp_project("bad_type_test") do |temp_project|
        Dir.cd(temp_project.path) do
          cli = AzuCLI::Commands::New.new
          cli.parse_args(["--yes", "--type", "worker", "--no-git", "tool_app"])
          TestHelpers::TestSetup.with_captured_output do |_|
            result = cli.execute
            result.success?.should be_false
            result.error.should contain("Unknown project type 'worker'")
            result.error.should contain("web, api, cli")
            result.exit_code.should eq(2) # invalid usage
          end

          Dir.exists?("tool_app").should be_false
        end
      end
    end

    it "refuses --docker for a cli project and an unknown CI setup" do
      TestHelpers::TestSetup.with_temp_project("bad_delivery_test") do |temp_project|
        Dir.cd(temp_project.path) do
          cli = AzuCLI::Commands::New.new
          cli.parse_args(["--yes", "--docker", "--type", "cli", "tool_app"])
          TestHelpers::TestSetup.with_captured_output do |_|
            result = cli.execute
            result.success?.should be_false
            result.error.should contain("--docker is for web and api projects")
            result.exit_code.should eq(2)
          end

          gitlab = AzuCLI::Commands::New.new
          gitlab.parse_args(["--yes", "--ci", "GitLab CI", "lab_app"])
          TestHelpers::TestSetup.with_captured_output do |_|
            result = gitlab.execute
            result.success?.should be_false
            result.error.should contain("Unknown CI setup 'GitLab CI'")
            result.exit_code.should eq(2)
          end
          Dir.exists?("tool_app").should be_false
          Dir.exists?("lab_app").should be_false
        end
      end
    end

    it "refuses a database adapter it does not know instead of generating a PostgreSQL project" do
      TestHelpers::TestSetup.with_temp_project("bad_db_test") do |temp_project|
        Dir.cd(temp_project.path) do
          cli = AzuCLI::Commands::New.new
          cli.parse_args(["--yes", "--db", "sqllite", "typo_app"])
          TestHelpers::TestSetup.with_captured_output do |_|
            result = cli.execute
            result.success?.should be_false
            result.error.should contain("Unknown database adapter 'sqllite'. Choose one of: sqlite, postgresql, mysql.")
            result.exit_code.should eq(2)
          end
          Dir.exists?("typo_app").should be_false
        end
      end
    end

    it "ignores --db for a cli project, which has no database" do
      TestHelpers::TestSetup.with_temp_project("cli_any_db_test") do |temp_project|
        Dir.cd(temp_project.path) do
          cli = AzuCLI::Commands::New.new
          cli.parse_args(["--yes", "--type", "cli", "--db", "none", "--no-git", "any_db_tool"])
          TestHelpers::TestSetup.with_captured_output do |_|
            cli.execute.success?.should be_true
          end
          File.exists?("any_db_tool/src/any_db_tool.cr").should be_true
        end
      end
    end

    it "handles skip git flag" do
      TestHelpers::TestSetup.with_temp_project("no_git_test") do |temp_project|
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "--no-git", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        command.git_init.should be_false
      end
    end

    it "handles skip example flag" do
      TestHelpers::TestSetup.with_temp_project("no_example_test") do |temp_project|
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "--no-example", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        command.include_example.should be_false
      end
    end

    it "handles skip joobq flag" do
      TestHelpers::TestSetup.with_temp_project("no_joobq_test") do |temp_project|
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "--no-joobq", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
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
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
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
        File.exists?(File.join(project_path, "src/db/schema.cr")).should be_true # migrations are created by `azu generate`
        File.exists?(File.join(project_path, "src/db/seed.cr")).should be_true
        Dir.exists?(File.join(project_path, "public")).should be_true
      end
    end

    it "creates web project structure" do
      TestHelpers::TestSetup.with_temp_project("web_structure_test") do |temp_project|
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "--type", "web", "test_web"])

        TestHelpers::TestSetup.with_captured_output do |_|
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
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "--type", "api", "test_api"])

        TestHelpers::TestSetup.with_captured_output do |_|
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
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "--author", "Test Author", "--email", "test@example.com", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
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
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
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
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        project_path = File.join(parent_dir, "test_project")
        Dir.exists?(File.join(project_path, ".git")).should be_true
      end
    end

    it "skips git initialization when --no-git flag is used" do
      TestHelpers::TestSetup.with_temp_project("no_git_test") do |temp_project|
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "--no-git", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
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
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
          capture.stdout.should match(/^\[ok\] Shards +\d+ installed/m)
        end
      end
    end
  end

  describe "project name validation" do
    it "rejects names starting with numbers" do
      invalid_names = ["123invalid", "1app", "9project"]

      invalid_names.each do |name|
        command = AzuCLI::Commands::New.new
        command.parse_args([name])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_false
          result.error.should contain("Invalid project name")
          result.error.should contain("Start with a letter")
        end
      end
    end

    it "rejects names with special characters" do
      invalid_names = ["invalid name", "invalid@name", "invalid.name", "my-app!", "app$name"]

      invalid_names.each do |name|
        command = AzuCLI::Commands::New.new
        command.parse_args([name])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_false
          result.error.should contain("Invalid project name")
        end
      end
    end

    it "rejects Crystal reserved words" do
      reserved_names = ["class", "module", "def", "end", "begin", "rescue", "ensure", "if", "else", "elsif"]

      reserved_names.each do |name|
        command = AzuCLI::Commands::New.new
        command.parse_args([name])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_false
          result.error.should contain("Invalid project name")
          result.error.should contain("reserved word")
        end
      end
    end

    it "rejects names starting with underscore" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["_invalid"])

      TestHelpers::TestSetup.with_captured_output do |_|
        result = command.execute
        result.success?.should be_false
        result.error.should contain("Invalid project name")
      end
    end

    it "rejects names ending with underscore" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["invalid_"])

      TestHelpers::TestSetup.with_captured_output do |_|
        result = command.execute
        result.success?.should be_false
        result.error.should contain("Invalid project name")
      end
    end

    it "rejects names starting with hyphen" do
      command = AzuCLI::Commands::New.new
      # Need to handle this differently because "-invalid" is parsed as a flag
      # Use the project_name setter directly to bypass option parsing
      command.project_name = "-invalid"
      command.parse_args([] of String)

      TestHelpers::TestSetup.with_captured_output do |_|
        result = command.execute
        result.success?.should be_false
        result.error.should contain("Invalid project name")
      end
    end

    it "rejects names ending with hyphen" do
      command = AzuCLI::Commands::New.new
      command.parse_args(["invalid-"])

      TestHelpers::TestSetup.with_captured_output do |_|
        result = command.execute
        result.success?.should be_false
        result.error.should contain("Invalid project name")
      end
    end

    it "rejects empty names" do
      command = AzuCLI::Commands::New.new
      command.parse_args([""])

      TestHelpers::TestSetup.with_captured_output do |_|
        result = command.execute
        result.success?.should be_false
        result.error.should contain("Invalid project name")
      end
    end

    it "accepts valid project names" do
      valid_names = ["myapp", "my_app", "my-app", "MyApp", "app123", "web_service_2024"]

      valid_names.each do |name|
        TestHelpers::TestSetup.with_temp_project("valid_name_test_#{name}") do |temp_project|
          parent_dir = temp_project.path
          Dir.cd(parent_dir)

          command = AzuCLI::Commands::New.new
          command.parse_args(["--yes", name])

          TestHelpers::TestSetup.with_captured_output do |_|
            result = command.execute
            result.success?.should be_true
          end

          # Clean up created project
          project_path = File.join(parent_dir, name)
          FileUtils.rm_rf(project_path) if Dir.exists?(project_path)
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

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_false
          result.error.should contain("Invalid project name")
        end
      end
    end

    it "handles existing directories" do
      TestHelpers::TestSetup.with_temp_project("existing_test") do |temp_project|
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        # Create existing directory
        existing_path = File.join(parent_dir, "existing_project")
        Dir.mkdir_p(existing_path)

        command = AzuCLI::Commands::New.new
        command.parse_args(["existing_project"])

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_false
          result.error.should contain("already exists")
        end
      end
    end
  end

  describe "logging" do
    it "logs project creation steps" do
      TestHelpers::TestSetup.with_temp_project("logging_test") do |temp_project|
        parent_dir = temp_project.path
        Dir.cd(parent_dir)

        command = AzuCLI::Commands::New.new
        command.parse_args(["--yes", "test_project"])

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
          capture.stdout.should contain("Creating new Azu project: test_project")
          %w(Files Secrets Git Shards Type-check).each do |step|
            capture.stdout.should match(/^\[ok\] #{step} /m)
          end
          capture.stdout.should contain("test_project is ready")
        end
      end
    end
  end
  # The hints printed after `azu new`: the app listens on 4000 (azu's default, the generated .env's PORT), and
  # `azu db:setup` creates the database before migrating, so it is the step that works on a fresh project.
  describe "#next_steps" do
    it "points a web project at the port it listens on, after setting up the database" do
      command = AzuCLI::Commands::New.new
      command.project_name = "blog"
      steps = command.next_steps
      steps.should contain("cd blog")
      steps.should contain("azu db:setup")
      steps.should contain("azu serve")
      steps.should contain("Visit: http://localhost:#{AzuCLI::Config::Ports::DEV_SERVER}")
      steps.index!("azu db:setup").should be < steps.index!("azu serve")
      steps.join("\n").should_not contain("3000")
      AzuCLI::Config::Ports::DEV_SERVER.should eq(4000)
    end

    it "points an api project at its health check on the same port" do
      command = AzuCLI::Commands::New.new
      command.project_name = "svc"
      command.project_type = "api"
      command.next_steps.should contain("Test: curl http://localhost:4000/health")
    end

    it "needs no database server by default, and says the default in --help" do
      command = AzuCLI::Commands::New.new
      command.database_hint.should be_nil
      output = TestHelpers::TestSetup.with_captured_output { command.show_help }
      output.stdout.should contain("--db DATABASE             Database adapter (postgresql, mysql, sqlite) [default: sqlite]")
    end

    it "tells a server-backed database to be running and has no database step for a cli" do
      command = AzuCLI::Commands::New.new
      command.project_name = "tool"
      command.database = "postgresql"
      command.database_hint.not_nil!.should contain("DATABASE_URL")
      command.database = "sqlite"
      command.database_hint.should be_nil
      command.database = "postgresql"
      command.project_type = "cli"
      command.database_hint.should be_nil
      command.next_steps.should_not contain("azu db:setup")
    end
  end
end
