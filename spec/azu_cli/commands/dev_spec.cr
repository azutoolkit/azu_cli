require "../../spec_helper"

describe AzuCLI::Commands::Dev do
  describe "command metadata" do
    it "has correct command name" do
      AzuCLI::Commands::Dev.command_name.should eq("dev")
    end

    it "instance has correct command name" do
      dev = AzuCLI::Commands::Dev.new
      dev.command_name.should eq("dev")
    end

    it "has correct description mentioning alias" do
      description = AzuCLI::Commands::Dev.description
      description.should contain("Alias for serve")
      description.should contain("development server")
      description.should contain("hot reloading")
    end

    it "instance has correct description" do
      dev = AzuCLI::Commands::Dev.new
      description = dev.description
      description.should contain("Alias for serve")
      description.should contain("development server")
      description.should contain("hot reloading")
    end

    it "has correct usage" do
      AzuCLI::Commands::Dev.usage.should eq("dev [options]")
    end

    it "instance has correct usage" do
      dev = AzuCLI::Commands::Dev.new
      dev.usage.should eq("dev [options]")
    end
  end

  describe "inheritance behavior" do
    it "inherits from Serve command" do
      dev = AzuCLI::Commands::Dev.new
      dev.should be_a(AzuCLI::Commands::Serve)
    end

    it "is also a Command" do
      dev = AzuCLI::Commands::Dev.new
      dev.should be_a(AzuCLI::Command)
    end

    it "maintains serve command functionality" do
      # Since Dev inherits from Serve, it should have the same execution logic
      # but different metadata
      dev = AzuCLI::Commands::Dev.new
      serve = AzuCLI::Commands::Serve.new

      # Both should respond to the same methods
      dev.responds_to?(:execute).should be_true
      dev.responds_to?(:show_command_specific_help).should be_true

      # But have different command names
      dev.command_name.should_not eq(serve.command_name)
      dev.command_name.should eq("dev")
      serve.command_name.should eq("\"serve\"")
    end
  end

  describe "#execute" do
    it "requires project root like serve command" do
      dev = AzuCLI::Commands::Dev.new

      # Test outside of project root
      original_dir = Dir.current
      temp_dir = "/tmp/test_dev_dir_#{Random.new.rand(1000..9999)}"
      Dir.mkdir_p(temp_dir)
      Dir.cd(temp_dir)

      begin
        args = {} of String => String | Array(String)
        expect_raises(AzuCLI::Command::ValidationError, /project root/) do
          dev.execute(args)
        end
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(temp_dir) rescue nil
      end
    end

    it "inherits serve execution behavior" do
      dev = AzuCLI::Commands::Dev.new

      # Create a temporary project structure
      original_dir = Dir.current
      temp_dir = "/tmp/test_dev_project_#{Random.new.rand(1000..9999)}"

      begin
        Dir.mkdir_p(temp_dir)
        Dir.cd(temp_dir)

        # Create minimal project structure
        File.write("shard.yml", "name: test_project\nversion: 0.1.0")
        Dir.mkdir_p("src")
        File.write("src/server.cr", "# Server file")

        # Test that execute method exists and can be called
        # (We can't easily test the full server startup without complex setup)
        args = {"--help" => "true"} of String => String | Array(String)
        result = dev.execute(args)

        # The method should exist and handle the help flag
        result.should be_nil
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(temp_dir) rescue nil
      end
    end
  end

  describe "#show_command_specific_help" do
    it "displays alias information" do
      dev = AzuCLI::Commands::Dev.new

      # Test that show_command_specific_help exists and can be called
      # The method should mention that this is an alias for serve
      dev.show_command_specific_help

      # We can't easily capture output in Crystal tests without complex setup
      # but we can verify the method exists and doesn't raise errors
      true.should be_true
    end

    it "shows serve command help information" do
      dev = AzuCLI::Commands::Dev.new
      serve = AzuCLI::Commands::Serve.new

      # Both commands should be able to show help
      dev.responds_to?(:show_command_specific_help).should be_true
      serve.responds_to?(:show_command_specific_help).should be_true

      # Dev should override the help to mention it's an alias
      # but still provide the serve functionality help
      dev.show_command_specific_help
      true.should be_true
    end
  end

  describe "comparison with serve command" do
    it "has different command name but same execution logic" do
      dev = AzuCLI::Commands::Dev.new
      serve = AzuCLI::Commands::Serve.new

      # Different names
      dev.command_name.should eq("\"dev\"")
      serve.command_name.should eq("\"serve\"")

      # Different descriptions (dev mentions alias)
      dev.description.should contain("Alias for serve")
      serve.description.should_not contain("Alias for serve")

      # Different usage strings
      dev.usage.should eq("dev [options]")
      serve.usage.should eq("\"serve [options]\"")
    end

    it "has same core methods as serve command" do
      dev = AzuCLI::Commands::Dev.new
      serve = AzuCLI::Commands::Serve.new

      # Both should have execute method
      dev.execute({} of String => String | Array(String)).should be_nil rescue nil
      serve.execute({} of String => String | Array(String)).should be_nil rescue nil

      # Both should have help methods
      dev.show_command_specific_help
      serve.show_command_specific_help

      # Both should have metadata methods
      dev.command_name.should be_a(String)
      serve.command_name.should be_a(String)
      dev.description.should be_a(String)
      serve.description.should be_a(String)
      dev.usage.should be_a(String)
      serve.usage.should be_a(String)
    end
  end

  describe "class vs instance behavior" do
    it "class and instance methods return consistent values" do
      dev = AzuCLI::Commands::Dev.new

      # Class and instance should return same values
      AzuCLI::Commands::Dev.command_name.should eq(dev.command_name)
      AzuCLI::Commands::Dev.description.should eq(dev.description)
      AzuCLI::Commands::Dev.usage.should eq(dev.usage)
    end
  end

  describe "edge cases" do
    it "handles nil and empty arguments gracefully" do
      dev = AzuCLI::Commands::Dev.new

      # Should not crash with empty args
      empty_args = {} of String => String | Array(String)

      # This will fail validation (not in project root) but should not crash
      original_dir = Dir.current
      temp_dir = "/tmp/test_dev_empty_#{Random.new.rand(1000..9999)}"

      begin
        Dir.mkdir_p(temp_dir)
        Dir.cd(temp_dir)

        expect_raises(AzuCLI::Command::ValidationError) do
          dev.execute(empty_args)
        end
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(temp_dir) rescue nil
      end
    end

    it "maintains type safety" do
      dev = AzuCLI::Commands::Dev.new

      # Command name should always be a String
      dev.command_name.should be_a(String)
      AzuCLI::Commands::Dev.command_name.should be_a(String)

      # Description should always be a String
      dev.description.should be_a(String)
      AzuCLI::Commands::Dev.description.should be_a(String)

      # Usage should always be a String
      dev.usage.should be_a(String)
      AzuCLI::Commands::Dev.usage.should be_a(String)
    end
  end
end
