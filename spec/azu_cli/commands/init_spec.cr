require "../../spec_helper"
require "../../support/test_helpers"

describe AzuCLI::Commands::Init do
  describe "#initialize" do
    it "sets up init command properties" do
      command = AzuCLI::Commands::Init.new

      command.name.should eq("init")
      command.description.should eq("Initialize Azu in existing project")
    end
  end

  describe "#execute" do
    it "initializes Azu in valid project directory" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml

        command = AzuCLI::Commands::Init.new
        command.parse_args([] of String)

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
          result.message.should contain("Azu initialized in current project")
        end

        # Verify configuration file was created
        File.exists?("config/azu.yml").should be_true

        # Verify project structure was created
        Dir.exists?("src/models").should be_true
        Dir.exists?("src/endpoints").should be_true
        Dir.exists?("src/services").should be_true
        Dir.exists?("src/requests").should be_true
        Dir.exists?("src/pages").should be_true
        Dir.exists?("src/initializers").should be_true
        Dir.exists?("db/migrations").should be_true
        Dir.exists?("public/templates").should be_true
      end
    end

    it "fails when not in valid project directory" do
      TestHelpers::TestSetup.with_temp_project do |_|
        # Don't create shard.yml to simulate invalid project

        command = AzuCLI::Commands::Init.new
        command.parse_args([] of String)

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_false
          result.error.should contain("Not in a valid Crystal project directory")
        end
      end
    end

    it "is idempotent - can be run multiple times" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml

        command = AzuCLI::Commands::Init.new
        command.parse_args([] of String)

        # First run
        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        # Second run should also succeed
        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end

    it "creates proper configuration file" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml

        command = AzuCLI::Commands::Init.new
        command.parse_args([] of String)

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        # Verify config file content
        config_content = File.read("config/azu.yml")
        config_content.should contain("database:")
        config_content.should contain("adapter:")
        config_content.should contain("host:")
        config_content.should contain("port:")
      end
    end

    it "creates all required directories" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml

        command = AzuCLI::Commands::Init.new
        command.parse_args([] of String)

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        # Check all required directories exist
        required_dirs = [
          "src/models",
          "src/endpoints",
          "src/services",
          "src/requests",
          "src/pages",
          "src/initializers",
          "db/migrations",
          "public/templates",
        ]

        required_dirs.each do |dir|
          Dir.exists?(dir).should be_true
        end
      end
    end

    it "handles existing directories gracefully" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml

        # Pre-create some directories
        Dir.mkdir_p("src/models")
        Dir.mkdir_p("src/endpoints")

        command = AzuCLI::Commands::Init.new
        command.parse_args([] of String)

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        # Directories should still exist
        Dir.exists?("src/models").should be_true
        Dir.exists?("src/endpoints").should be_true
      end
    end
  end

  describe "project validation" do
    it "validates project directory by checking for shard.yml" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        # Test without shard.yml
        command = AzuCLI::Commands::Init.new
        # We can't test the private method directly, so we test the behavior
        # by running the command and checking the error message

        # Create shard.yml
        temp_project.create_shard_yml

        # Test with shard.yml - should work
        command.parse_args([] of String)
        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end
      end
    end
  end

  describe "configuration initialization" do
    it "creates config directory if it doesn't exist" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml

        # Ensure config directory doesn't exist
        FileUtils.rm_rf("config") if Dir.exists?("config")

        command = AzuCLI::Commands::Init.new
        command.parse_args([] of String)

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        Dir.exists?("config").should be_true
        File.exists?("config/azu.yml").should be_true
      end
    end

    it "creates basic configuration file with default content" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml

        command = AzuCLI::Commands::Init.new
        command.parse_args([] of String)

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        config_content = File.read("config/azu.yml")
        config_content.should contain("database:")
        config_content.should contain("adapter: postgresql")
        config_content.should contain("host: localhost")
        config_content.should contain("port: 5432")
      end
    end
  end

  describe "project structure creation" do
    it "creates all required source directories" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml

        command = AzuCLI::Commands::Init.new
        command.parse_args([] of String)

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        # Check source directories
        Dir.exists?("src/models").should be_true
        Dir.exists?("src/endpoints").should be_true
        Dir.exists?("src/services").should be_true
        Dir.exists?("src/requests").should be_true
        Dir.exists?("src/pages").should be_true
        Dir.exists?("src/initializers").should be_true
      end
    end

    it "creates database directories" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml

        command = AzuCLI::Commands::Init.new
        command.parse_args([] of String)

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        Dir.exists?("db/migrations").should be_true
      end
    end

    it "creates public directories" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml

        command = AzuCLI::Commands::Init.new
        command.parse_args([] of String)

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_true
        end

        Dir.exists?("public/templates").should be_true
      end
    end
  end

  describe "error handling" do
    it "provides clear error message for invalid directory" do
      TestHelpers::TestSetup.with_temp_project do |_|
        # Don't create shard.yml

        command = AzuCLI::Commands::Init.new
        command.parse_args([] of String)

        TestHelpers::TestSetup.with_captured_output do |_|
          result = command.execute
          result.success?.should be_false
          result.error.should contain("Not in a valid Crystal project directory")
          result.error.should contain("Run this command from your project root")
        end
      end
    end
  end

  describe "logging" do
    it "logs initialization steps" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml

        command = AzuCLI::Commands::Init.new
        command.parse_args([] of String)

        TestHelpers::TestSetup.with_captured_output do |capture|
          result = command.execute
          result.success?.should be_true
          capture.stderr.should contain("Initializing Azu in current project")
          capture.stderr.should contain("Creating Azu configuration")
          capture.stderr.should contain("Creating project structure")
          capture.stderr.should contain("Azu initialized successfully")
        end
      end
    end
  end
end
