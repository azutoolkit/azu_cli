require "../../spec_helper"
require "file_utils"

# Test directory for isolating file generation
TEST_DIR = "./tmp_generate_test"

describe AzuCLI::Commands::Generate do
  # Clean up before and after each test
  before_each do
    FileUtils.rm_rf(TEST_DIR) if Dir.exists?(TEST_DIR)
    FileUtils.mkdir_p(TEST_DIR)
    Dir.cd(TEST_DIR)
  end

  after_each do
    Dir.cd("..")
    FileUtils.rm_rf(TEST_DIR) if Dir.exists?(TEST_DIR)
  end

  describe "directory output validation" do
    it "generates model files in correct output directory" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["model", "User", "name:string", "email:string"])

      result = command.execute

      result.success?.should be_true
      # Model should be generated in ./src/models directory
      File.exists?("./src/models/user.cr").should be_true
      Dir.exists?("./src/models").should be_true
    end

    it "generates endpoint files in correct output directory" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["endpoint", "Users", "index", "show"])

      result = command.execute

      result.success?.should be_true
      # Endpoints should be generated in ./src/endpoints directory
      Dir.exists?("./src/endpoints").should be_true
      exit 1
      # Should create subdirectory and files for each action
      Dir.exists?("./src/endpoints/user").should be_true
      File.exists?("./src/endpoints/user/user_index_endpoint.cr").should be_true
      File.exists?("./src/endpoints/user/user_show_endpoint.cr").should be_true
    end

    it "generates job files in correct output directory" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["job", "EmailNotification", "user_id:int32", "template:string"])

      result = command.execute

      result.success?.should be_true
      # Jobs should be generated in ./src/jobs directory
      File.exists?("./src/jobs/email_notification_job.cr").should be_true
      Dir.exists?("./src/jobs").should be_true
    end

    it "generates middleware files in correct output directory" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["middleware", "Authentication"])

      result = command.execute
      result.success?.should be_true
      # Middleware should be generated in ./src/middleware directory
      File.exists?("./src/middleware/authentication_middleware.cr").should be_true
      Dir.exists?("./src/middleware").should be_true
    end

    it "generates migration files in correct output directory" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["migration", "CreateUsers", "name:string", "email:string"])

      result = command.execute

      result.success?.should be_true
      # Migrations should be generated in ./src/db/migrations directory
      Dir.exists?("./src/db/migrations").should be_true

      # Find the migration file (it has a timestamp prefix)
      migration_files = Dir.entries("./src/db/migrations").select { |f| f.includes?("create_users") }
      migration_files.size.should be > 0
    end

    it "generates component files in correct output directory" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["component", "UserCard", "name:string", "email:string"])

      result = command.execute

      result.success?.should be_true
      # Components should be generated in ./src/components directory
      File.exists?("./src/components/user_card.cr").should be_true
      Dir.exists?("./src/components").should be_true
    end



    it "generates response files in correct output directory" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["response", "UserResponse", "name:string", "email:string"])

      result = command.execute

      result.success?.should be_true
      # Responses should be generated in ./src/pages directory (merged with page generator)
      Dir.exists?("./src/pages").should be_true
      Dir.exists?("./src/pages/userresponses").should be_true
      File.exists?("./src/pages/userresponses/user_response_index_json.cr").should be_true
    end

    it "generates validator files in correct output directory" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["validator", "UserValidator"])

      result = command.execute

      result.success?.should be_true
      # Validators should be generated in ./src/validators directory
      File.exists?("./src/validators/user_validator.cr").should be_true
      Dir.exists?("./src/validators").should be_true
    end

    it "generates page files in correct output directory" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["page", "UserProfile", "name:string", "email:string"])

      result = command.execute

      result.success?.should be_true
      # Pages should be generated in ./src/pages directory
      Dir.exists?("./src/pages").should be_true
      Dir.exists?("./src/pages/userprofiles").should be_true
      File.exists?("./src/pages/userprofiles/page_response.cr").should be_true
    end

    it "generates template files in correct output directory" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["template", "UserList", "users:array"])

      result = command.execute

      result.success?.should be_true
      # Templates should be generated in ./public/templates/pages directory
      Dir.exists?("./public/templates/pages").should be_true
      Dir.exists?("./public/templates/pages/userlists").should be_true

      # Should generate CRUD template files
      File.exists?("./public/templates/pages/userlists/index.jinja").should be_true
      File.exists?("./public/templates/pages/userlists/show.jinja").should be_true
      File.exists?("./public/templates/pages/userlists/new.jinja").should be_true
      File.exists?("./public/templates/pages/userlists/edit.jinja").should be_true
    end
  end

  describe "scaffold directory validation" do
    it "generates scaffold files in multiple correct output directories" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["scaffold", "Post", "title:string", "content:text", "--web-only"])

      result = command.execute

      result.success?.should be_true

      # Scaffold should generate files in multiple directories

      # Model
      File.exists?("./src/models/post.cr").should be_true
      Dir.exists?("./src/models").should be_true

      # Endpoints
      Dir.exists?("./src/endpoints").should be_true

      # Contracts (for web mode)
      Dir.exists?("./src/contracts").should be_true

      # Pages (for web mode)
      Dir.exists?("./src/pages").should be_true
    end

    it "generates API scaffold files in correct directories" do
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["scaffold", "Product", "name:string", "price:float64", "--api-only"])

      result = command.execute

      result.success?.should be_true

      # Model
      File.exists?("./src/models/product.cr").should be_true
      Dir.exists?("./src/models").should be_true

      # Endpoints
      Dir.exists?("./src/endpoints").should be_true

      # Contracts (for API mode)
      Dir.exists?("./src/contracts").should be_true

      # Responses (for API mode) - now generated in pages directory
      Dir.exists?("./src/pages").should be_true
    end
  end

  describe "directory creation" do
    it "creates directories that don't exist" do
      # Ensure directories don't exist before running
      Dir.exists?("./src/models").should be_false
      Dir.exists?("./src/endpoints").should be_false

      command = AzuCLI::Commands::Generate.new
      command.parse_args(["model", "User", "name:string"])

      result = command.execute

      result.success?.should be_true

      # Directory should be created automatically
      Dir.exists?("./src/models").should be_true
    end

    it "handles nested directory creation" do
      # Migration directory is nested (./src/db/migrations)
      Dir.exists?("./src").should be_false
      Dir.exists?("./src/db").should be_false
      Dir.exists?("./src/db/migrations").should be_false

      command = AzuCLI::Commands::Generate.new
      command.parse_args(["migration", "CreatePosts", "title:string"])

      result = command.execute

      result.success?.should be_true

      # All nested directories should be created
      Dir.exists?("./src").should be_true
      Dir.exists?("./src/db").should be_true
      Dir.exists?("./src/db/migrations").should be_true
    end
  end

  describe "OUTPUT_DIR constant validation" do
    it "uses correct OUTPUT_DIR for each generator type" do
      # Test that the OUTPUT_DIR constants match expected directories
      AzuCLI::Generate::Model::OUTPUT_DIR.should eq("./src/models")
      AzuCLI::Generate::Endpoint::OUTPUT_DIR.should eq("./src/endpoints")
      AzuCLI::Generate::Job::OUTPUT_DIR.should eq("./src/jobs")
      AzuCLI::Generate::Middleware::OUTPUT_DIR.should eq("./src/middleware")
      AzuCLI::Generate::Migration::OUTPUT_DIR.should eq("./src/db/migrations")
      AzuCLI::Generate::Component::OUTPUT_DIR.should eq("./src/components")
      AzuCLI::Generate::Validator::OUTPUT_DIR.should eq("./src/validators")
      AzuCLI::Generate::Page::OUTPUT_DIR.should eq("./src/pages")
      AzuCLI::Generate::Template::OUTPUT_DIR.should eq("./public/templates/pages")
    end
  end

  describe "error handling for directory issues" do
    it "handles permission errors gracefully" do
      # This test would need special setup for permission testing
      # For now, just ensure the command doesn't crash
      command = AzuCLI::Commands::Generate.new
      command.parse_args(["model", "User", "name:string"])

      # Should not raise an exception
      result = command.execute
      result.should be_a(AzuCLI::Commands::Result)
    end

    it "validates arguments before attempting directory creation" do
      command = AzuCLI::Commands::Generate.new
      # Missing required arguments
      command.parse_args(["model"])

      result = command.execute

      result.success?.should be_false
      result.error.should contain("Usage: azu generate")

      # Should not create any directories for failed commands
      Dir.exists?("./src/models").should be_false
    end
  end
end
