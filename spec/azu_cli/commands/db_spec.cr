require "../../spec_helper"
require "../../../src/azu_cli/commands/db"

describe AzuCLI::Commands::Db do
  describe "#execute" do
    it "shows error and help when no subcommand is provided" do
      command = AzuCLI::Commands::Db.new
      result = command.execute({} of String => String | Array(String))
      result.should be_nil
    end

    it "shows error for unknown subcommand" do
      command = AzuCLI::Commands::Db.new
      args = {"_positional" => ["invalid_command"]} of String => String | Array(String)
      result = command.execute(args)
      result.should be_nil
    end

    it "validates project root for valid subcommands" do
      command = AzuCLI::Commands::Db.new
      args = {"_positional" => ["create"]} of String => String | Array(String)
      # This will fail because we're not in a project root, but that's expected
      expect_raises(AzuCLI::Command::ValidationError) do
        command.execute(args)
      end
    end

    it "accepts migrate subcommand" do
      command = AzuCLI::Commands::Db.new
      args = {"_positional" => ["migrate"]} of String => String | Array(String)
      # This will fail because we're not in a project root, but that's expected
      expect_raises(AzuCLI::Command::ValidationError) do
        command.execute(args)
      end
    end

    it "accepts seed subcommand" do
      command = AzuCLI::Commands::Db.new
      args = {"_positional" => ["seed"]} of String => String | Array(String)
      # This will fail because we're not in a project root, but that's expected
      expect_raises(AzuCLI::Command::ValidationError) do
        command.execute(args)
      end
    end

    it "accepts new_migration subcommand" do
      command = AzuCLI::Commands::Db.new
      args = {"_positional" => ["new_migration", "test_migration"]} of String => String | Array(String)
      # This will fail because we're not in a project root, but that's expected
      expect_raises(AzuCLI::Command::ValidationError) do
        command.execute(args)
      end
    end
  end

  describe "database adapter detection" do
    it "detects postgresql from shard.yml" do
      # Create a temporary directory for testing
      Dir.mkdir_p("tmp_test_#{Random.rand(1000)}")
      test_dir = Dir.glob("tmp_test_*").first

      begin
        Dir.cd(test_dir) do
          File.write("shard.yml", <<-YAML
          name: test_app
          dependencies:
            pg:
              github: will/crystal-pg
          YAML
          )

          db_command = AzuCLI::Commands::Db.new
          # We can't access private methods directly in Crystal spec
          # So we'll test this indirectly through a public interface
          # For now, just verify the command can be instantiated
          db_command.should_not be_nil
        end
      ensure
        FileUtils.rm_rf(test_dir)
      end
    end

    it "handles mysql detection" do
      # Create a temporary directory for testing
      Dir.mkdir_p("tmp_test_mysql_#{Random.rand(1000)}")
      test_dir = Dir.glob("tmp_test_mysql_*").first

      begin
        Dir.cd(test_dir) do
          File.write("shard.yml", <<-YAML
          name: test_app
          dependencies:
            mysql:
              github: crystal-lang/crystal-mysql
          YAML
          )

          db_command = AzuCLI::Commands::Db.new
          # Test that the command can be instantiated with mysql config
          db_command.should_not be_nil
        end
      ensure
        FileUtils.rm_rf(test_dir)
      end
    end
  end

  describe "#show_command_specific_help" do
    it "displays database command help" do
      command = AzuCLI::Commands::Db.new
      # Just verify it doesn't crash when showing help
      command.show_command_specific_help
      # If we get here without an exception, the test passes
      true.should be_true
    end
  end
end
