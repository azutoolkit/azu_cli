require "../../spec_helper"
require "file_utils"

# Test directory for isolating file generation
INIT_TEST_DIR = "./tmp_init_test"

describe AzuCLI::Commands::Init do
  # Clean up before and after each test
  before_each do
    FileUtils.rm_rf(INIT_TEST_DIR) if Dir.exists?(INIT_TEST_DIR)
    FileUtils.mkdir_p(INIT_TEST_DIR)
    Dir.cd(INIT_TEST_DIR)

    # Create a minimal shard.yml to simulate a valid project directory
    File.write("shard.yml", <<-YAML
      name: test_project
      version: 0.1.0
      YAML
    )
  end

  after_each do
    Dir.cd("..")
    FileUtils.rm_rf(INIT_TEST_DIR) if Dir.exists?(INIT_TEST_DIR)
  end

  describe "#execute" do
    it "initializes Azu in existing project" do
      command = AzuCLI::Commands::Init.new
      command.parse_args([] of String)

      result = command.execute

      result.success?.should be_true
      result.message.should contain("Azu initialized")
    end

    it "creates config directory" do
      command = AzuCLI::Commands::Init.new

      command.execute

      Dir.exists?("config").should be_true
    end

    it "creates azu.yml configuration file" do
      command = AzuCLI::Commands::Init.new

      command.execute

      File.exists?("config/azu.yml").should be_true
    end

    it "creates project directory structure" do
      command = AzuCLI::Commands::Init.new

      command.execute

      Dir.exists?("src/models").should be_true
      Dir.exists?("src/endpoints").should be_true
      Dir.exists?("src/services").should be_true
      Dir.exists?("src/db/migrations").should be_true
      Dir.exists?("public/templates").should be_true
    end

    it "fails when not in valid project directory" do
      # Remove shard.yml to simulate invalid project
      File.delete("shard.yml")

      command = AzuCLI::Commands::Init.new
      result = command.execute

      result.success?.should be_false
      result.error.should contain("Not in a valid Crystal project directory")
    end

    it "uses project name from shard.yml" do
      File.write("shard.yml", <<-YAML
        name: my_custom_project
        version: 1.0.0
        YAML
      )

      command = AzuCLI::Commands::Init.new
      result = command.execute

      result.success?.should be_true

      # Check that config file was created with project name
      File.exists?("config/azu.yml").should be_true
      config_content = File.read("config/azu.yml")
      config_content.should contain("my_custom_project")
    end
  end

  describe "#show_help" do
    it "displays help information" do
      command = AzuCLI::Commands::Init.new

      # Just ensure it doesn't crash
      command.show_help
    end
  end
end
