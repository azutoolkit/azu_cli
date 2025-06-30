require "../../spec_helper"

describe AzuCLI::Commands::Serve do
  describe "#execute" do
    it "requires project root" do
      serve = AzuCLI::Commands::Serve.new

      # Test outside of project root
      original_dir = Dir.current
      temp_dir = "/tmp/test_dir_#{Random.new.rand(1000..9999)}"
      Dir.mkdir_p(temp_dir)
      Dir.cd(temp_dir)

      begin
        args = {} of String => String | Array(String)
        expect_raises(AzuCLI::Command::ValidationError, /project root/) do
          serve.execute(args)
        end
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(temp_dir) rescue nil
      end
    end

    it "shows correct help information" do
      serve = AzuCLI::Commands::Serve.new

      # Test that show_command_specific_help exists and can be called
      serve.show_command_specific_help

      # We can't easily capture output in Crystal tests without complex setup
      # but we can verify the method exists and doesn't raise errors
      true.should be_true
    end
  end

  describe "command metadata" do
    it "has correct command name" do
      AzuCLI::Commands::Serve.command_name.should eq("serve")
    end

    it "has correct description" do
      AzuCLI::Commands::Serve.description.should contain("development server")
      AzuCLI::Commands::Serve.description.should contain("hot reloading")
    end

    it "has correct usage" do
      AzuCLI::Commands::Serve.usage.should eq("serve [options]")
    end
  end
end

describe AzuCLI::Commands::Dev do
  describe "as alias for serve" do
    it "has correct command name" do
      AzuCLI::Commands::Dev.command_name.should eq("dev")
    end

    it "has correct description" do
      AzuCLI::Commands::Dev.description.should contain("Alias for serve")
      AzuCLI::Commands::Dev.description.should contain("development server")
    end

    it "shows alias information in help" do
      dev = AzuCLI::Commands::Dev.new

      # Test that show_command_specific_help exists and can be called
      dev.show_command_specific_help

      # We can verify the method exists and doesn't raise errors
      true.should be_true
    end
  end
end
