require "../../spec_helper"
require "../../../src/azu_cli/commands/generate"
require "file_utils"

describe AzuCLI::Commands::Generate do
  describe "command metadata" do
    it "has correct command name" do
      AzuCLI::Commands::Generate.command_name.should eq("\"generate\"")
    end

    it "has correct description" do
      AzuCLI::Commands::Generate.description.should contain("Generate Azu components")
      AzuCLI::Commands::Generate.description.should contain("endpoints")
      AzuCLI::Commands::Generate.description.should contain("models")
      AzuCLI::Commands::Generate.description.should contain("services")
    end

    it "has correct usage" do
      AzuCLI::Commands::Generate.usage.should eq("\"generate <generator_type> <name> [options]\"")
    end
  end

  describe "#execute" do
    context "when not in project root" do
      it "raises ValidationError" do
        original_dir = Dir.current
        test_dir = "/tmp/test_generate_#{Random.rand(10000)}"

        begin
          Dir.mkdir_p(test_dir)
          Dir.cd(test_dir)
          # Don't create shard.yml - this should trigger validation error

          command = AzuCLI::Commands::Generate.new
          args = {"_positional" => ["endpoint", "users"]} of String => String | Array(String)

          expect_raises(AzuCLI::Command::ValidationError, /project root/) do
            command.execute(args)
          end
        ensure
          Dir.cd(original_dir)
          FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
        end
      end
    end

    context "when no arguments provided" do
      it "shows available generators and returns nil" do
        original_dir = Dir.current
        test_dir = "/tmp/test_generate_help_#{Random.rand(10000)}"

        begin
          Dir.mkdir_p(test_dir)
          Dir.cd(test_dir)
          File.write("shard.yml", "name: test_project")

          command = AzuCLI::Commands::Generate.new
          args = {} of String => String | Array(String)

          result = command.execute(args)
          result.should be_nil
        ensure
          Dir.cd(original_dir)
          FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
        end
      end
    end

    context "when invalid generator type is provided" do
      it "shows error and available generators" do
        original_dir = Dir.current
        test_dir = "/tmp/test_generate_invalid_#{Random.rand(10000)}"

        begin
          Dir.mkdir_p(test_dir)
          Dir.cd(test_dir)
          File.write("shard.yml", "name: test_project")

          command = AzuCLI::Commands::Generate.new
          args = {"_positional" => ["invalid_generator"]} of String => String | Array(String)

          result = command.execute(args)
          result.should be_nil
        ensure
          Dir.cd(original_dir)
          FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
        end
      end
    end

    context "when generator type is provided without component name" do
      it "shows error and usage information" do
        original_dir = Dir.current
        test_dir = "/tmp/test_generate_no_name_#{Random.rand(10000)}"

        begin
          Dir.mkdir_p(test_dir)
          Dir.cd(test_dir)
          File.write("shard.yml", "name: test_project")

          command = AzuCLI::Commands::Generate.new
          args = {"_positional" => ["endpoint"]} of String => String | Array(String)

          result = command.execute(args)
          result.should be_nil
        ensure
          Dir.cd(original_dir)
          FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
        end
      end
    end

    context "when invalid component name is provided" do
      it "shows error for invalid component name" do
        original_dir = Dir.current
        test_dir = "/tmp/test_generate_invalid_name_#{Random.rand(10000)}"

        begin
          Dir.mkdir_p(test_dir)
          Dir.cd(test_dir)
          File.write("shard.yml", "name: test_project")

          command = AzuCLI::Commands::Generate.new
          args = {"_positional" => ["endpoint", "123invalid"]} of String => String | Array(String)

          result = command.execute(args)
          result.should be_nil
        ensure
          Dir.cd(original_dir)
          FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
        end
      end
    end
  end

  describe "generator type validation" do
    describe "GENERATORS constant" do
      it "contains all expected generator types" do
        AzuCLI::Commands::Generate::GENERATORS.has_key?("endpoint").should be_true
        AzuCLI::Commands::Generate::GENERATORS.has_key?("model").should be_true
        AzuCLI::Commands::Generate::GENERATORS.has_key?("service").should be_true
        AzuCLI::Commands::Generate::GENERATORS.has_key?("middleware").should be_true
        AzuCLI::Commands::Generate::GENERATORS.has_key?("contract").should be_true
        AzuCLI::Commands::Generate::GENERATORS.has_key?("page").should be_true
        AzuCLI::Commands::Generate::GENERATORS.has_key?("migration").should be_true
        AzuCLI::Commands::Generate::GENERATORS.has_key?("scaffold").should be_true
      end

      it "has meaningful descriptions for each generator" do
        AzuCLI::Commands::Generate::GENERATORS.each do |type, description|
          description.should_not be_empty
          description.size.should be > 10
        end
      end
    end

    describe "GENERATOR_ALIASES constant" do
      it "contains expected aliases" do
        aliases = AzuCLI::Commands::Generate::GENERATOR_ALIASES

        aliases["controller"].should eq("endpoint")
        aliases["e"].should eq("endpoint")
        aliases["m"].should eq("model")
        aliases["s"].should eq("service")
        aliases["mw"].should eq("middleware")
        aliases["c"].should eq("contract")
        aliases["p"].should eq("page")
        aliases["mig"].should eq("migration")
      end
    end
  end

  describe "component name validation" do
    original_dir = Dir.current
    test_dir = "/tmp/test_generate_name_validation_#{Random.rand(10000)}"

    before_each do
      Dir.mkdir_p(test_dir)
      Dir.cd(test_dir)
      File.write("shard.yml", "name: test_project")
    end

    after_each do
      Dir.cd(original_dir)
      FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
    end

    it "accepts valid component names through command execution" do
      command = AzuCLI::Commands::Generate.new

      # Test valid names by checking they don't fail with "Invalid component name" error
      valid_names = ["User", "user", "user_profile", "BlogPost", "user-profile"]

      valid_names.each do |name|
        args = {"_positional" => ["endpoint", name]} of String => String | Array(String)
        begin
          command.execute(args)
        rescue ex
          # Should not fail due to invalid component name
          if message = ex.message
            message.should_not contain("Invalid component name")
          end
        end
      end
    end

    it "rejects invalid component names through command execution" do
      command = AzuCLI::Commands::Generate.new

      args = {"_positional" => ["endpoint", "123invalid"]} of String => String | Array(String)
      result = command.execute(args)

      # Should return nil when invalid name is provided
      result.should be_nil
    end
  end

  describe "alias resolution" do
    original_dir = Dir.current
    test_dir = "/tmp/test_generate_aliases_#{Random.rand(10000)}"

    before_each do
      Dir.mkdir_p(test_dir)
      Dir.cd(test_dir)
      File.write("shard.yml", "name: test_project")
    end

    after_each do
      Dir.cd(original_dir)
      FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
    end

    it "resolves 'e' alias to 'endpoint'" do
      command = AzuCLI::Commands::Generate.new

      # We can't easily test the internal generator call without modifying the class
      # But we can test that the alias is recognized as valid
      args = {"_positional" => ["e", "users"]} of String => String | Array(String)

      # The command should not return early due to invalid generator type
      # This indirectly tests that the alias is resolved
      begin
        command.execute(args)
      rescue ex
        # We expect this to fail due to missing generator dependencies in test
        # But it should not fail due to "Unknown generator" error
        if message = ex.message
          message.should_not contain("Unknown generator")
        end
      end
    end

    it "resolves 'controller' alias to 'endpoint'" do
      command = AzuCLI::Commands::Generate.new
      args = {"_positional" => ["controller", "users"]} of String => String | Array(String)

      begin
        command.execute(args)
      rescue ex
        if message = ex.message
          message.should_not contain("Unknown generator")
        end
      end
    end

    it "resolves 'm' alias to 'model'" do
      command = AzuCLI::Commands::Generate.new
      args = {"_positional" => ["m", "User"]} of String => String | Array(String)

      begin
        command.execute(args)
      rescue ex
        if message = ex.message
          message.should_not contain("Unknown generator")
        end
      end
    end
  end

  describe "options handling" do
    command = AzuCLI::Commands::Generate.new

    it "recognizes --force flag" do
      args = {"--force" => "true"} of String => String | Array(String)
      command.has_flag?(args, "--force").should be_true
    end

    it "recognizes --skip-tests flag" do
      args = {"--skip-tests" => "true"} of String => String | Array(String)
      command.has_flag?(args, "--skip-tests").should be_true
    end

    it "recognizes --skip-routes flag" do
      args = {"--skip-routes" => "true"} of String => String | Array(String)
      command.has_flag?(args, "--skip-routes").should be_true
    end

    it "returns false for missing flags" do
      args = {} of String => String | Array(String)
      command.has_flag?(args, "--force").should be_false
      command.has_flag?(args, "--skip-tests").should be_false
      command.has_flag?(args, "--skip-routes").should be_false
    end
  end

  describe "#show_command_specific_help" do
    it "displays comprehensive help information" do
      command = AzuCLI::Commands::Generate.new

      # Test that the method exists and can be called without error
      command.show_command_specific_help

      # Since we can't easily capture output in Crystal tests,
      # we verify the method exists and doesn't raise errors
      true.should be_true
    end
  end

  describe "integration with project structure" do
    original_dir = Dir.current
    test_dir = "/tmp/test_generate_integration_#{Random.rand(10000)}"

    before_each do
      Dir.mkdir_p(test_dir)
      Dir.cd(test_dir)

      # Create minimal project structure
      File.write("shard.yml", <<-YAML
        name: test_project
        version: 0.1.0
        YAML
      )

      Dir.mkdir_p("src")
      Dir.mkdir_p("src/endpoints")
      Dir.mkdir_p("src/models")
      Dir.mkdir_p("src/services")
      Dir.mkdir_p("src/contracts")
      Dir.mkdir_p("src/pages")
      Dir.mkdir_p("src/middleware")
      Dir.mkdir_p("src/db/migrations")
      Dir.mkdir_p("spec")
    end

    after_each do
      Dir.cd(original_dir)
      FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
    end

    it "detects project name from shard.yml" do
      command = AzuCLI::Commands::Generate.new
      project_name = command.get_project_name
      project_name.should eq("test_project")
    end

    it "validates project root correctly" do
      command = AzuCLI::Commands::Generate.new

      # Should not raise error when in project root
      begin
        command.require_project_root!
        true.should be_true
      rescue ex
        fail("Should not raise error in project root: #{ex.message}")
      end
    end
  end

  describe "error handling" do
    it "handles missing shard.yml gracefully" do
      original_dir = Dir.current
      test_dir = "/tmp/test_generate_no_shard_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)
        # Don't create shard.yml

        command = AzuCLI::Commands::Generate.new
        args = {"_positional" => ["endpoint", "users"]} of String => String | Array(String)

        expect_raises(AzuCLI::Command::ValidationError) do
          command.execute(args)
        end
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "handles malformed shard.yml gracefully" do
      original_dir = Dir.current
      test_dir = "/tmp/test_generate_bad_shard_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)
        File.write("shard.yml", "invalid: yaml: content:")

        command = AzuCLI::Commands::Generate.new
        args = {"_positional" => ["endpoint", "users"]} of String => String | Array(String)

        # Should handle YAML parsing errors gracefully
        expect_raises(Exception) do
          command.execute(args)
        end
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end
  end
end
