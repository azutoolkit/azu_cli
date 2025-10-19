require "../spec_helper"

describe AzuCLI::Config do
  describe "#load!" do
    it "loads default configuration" do
      config = AzuCLI::Config.new
      config.load!

      config.environment.should eq("development")
      config.debug_mode.should be_true # development mode sets debug to true
      config.database_adapter.should eq("postgresql")
      config.dev_server_port.should eq(4000)
      config.colored_output?.should be_true
    end

    it "loads configuration from environment variables" do
      ENV["AZU_DEBUG"] = "1"
      ENV["AZU_DB_PORT"] = "5433"
      ENV["AZU_HOST"] = "0.0.0.0"

      config = AzuCLI::Config.new
      config.load!

      config.debug_mode.should be_true
      config.database_port.should eq(5433)
      config.dev_server_host.should eq("0.0.0.0")
    ensure
      ENV.delete("AZU_DEBUG")
      ENV.delete("AZU_DB_PORT")
      ENV.delete("AZU_HOST")
    end

    it "detects environment correctly" do
      config = AzuCLI::Config.new

      config.environment = "development"
      config.development?.should be_true
      config.test?.should be_false
      config.production?.should be_false

      config.environment = "test"
      config.development?.should be_false
      config.test?.should be_true
      config.production?.should be_false

      config.environment = "production"
      config.development?.should be_false
      config.test?.should be_false
      config.production?.should be_true
    end

    it "generates full database URL" do
      config = AzuCLI::Config.new
      config.database_user = "testuser"
      config.database_password = "testpass"
      config.database_host = "localhost"
      config.database_port = 5432
      config.project_name = "testapp"

      expected_url = "postgresql://testuser:testpass@localhost:5432/testapp"
      config.full_database_url.should eq(expected_url)
    end

    it "uses database_url when provided" do
      config = AzuCLI::Config.new
      config.database_url = "postgresql://custom:url@example.com:5432/customdb"

      config.full_database_url.should eq("postgresql://custom:url@example.com:5432/customdb")
    end
  end

  describe "#validate!" do
    it "validates successfully with default configuration" do
      config = AzuCLI::Config.new
      # Create the templates directory for validation
      Dir.mkdir_p(config.templates_path) unless Dir.exists?(config.templates_path)

      config.validate!
    end

    it "raises error for invalid port" do
      config = AzuCLI::Config.new
      config.dev_server_port = 99999

      expect_raises(Exception, /Invalid server port/) do
        config.validate!
      end
    end
  end

  describe "#generate_sample_config" do
    it "generates a sample configuration file" do
      temp_file = "/tmp/test_azu_config.yml"
      AzuCLI::Config.generate_sample_config(temp_file)

      File.exists?(temp_file).should be_true
      content = File.read(temp_file)
      content.should contain("environment: development")
      content.should contain("database:")
      content.should contain("server:")

      File.delete(temp_file)
    end
  end
end
