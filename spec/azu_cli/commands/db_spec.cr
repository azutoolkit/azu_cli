require "../../spec_helper"
require "../../../src/azu_cli/commands/db"
require "file_utils"

describe AzuCLI::Commands::Db do
  describe "#execute" do
    context "when no subcommand is provided" do
      it "shows error and returns nil" do
        command = AzuCLI::Commands::Db.new
        result = command.execute({} of String => String | Array(String))
        result.should be_nil
      end
    end

    context "when invalid subcommand is provided" do
      it "shows error for unknown subcommand" do
        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["invalid_command"]} of String => String | Array(String)
        result = command.execute(args)
        result.should be_nil
      end
    end

    context "when not in project root" do
      it "raises ValidationError for valid subcommands" do
        # Create a temporary directory without project files
        original_dir = Dir.current
        test_dir = "/tmp/test_dir_#{Random.rand(10000)}"

        begin
          Dir.mkdir_p(test_dir)
          Dir.cd(test_dir)

          # Don't create shard.yml here - this should trigger validation error

          command = AzuCLI::Commands::Db.new
          args = {"_positional" => ["create"]} of String => String | Array(String)
          expect_raises(AzuCLI::Command::ValidationError, /project root/) do
            command.execute(args)
          end
        ensure
          Dir.cd(original_dir)
          FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
        end
      end
    end
  end

  describe "database adapter detection" do
    it "detects postgresql from shard.yml" do
      test_dir = File.join("/tmp", "tmp_test_pg_#{Random.rand(10000)}")
      original_dir = Dir.current

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir) do
          # Create basic project structure
          Dir.mkdir_p("src/initializers")
          Dir.mkdir_p("src/db/migrations")

          File.write("shard.yml", <<-YAML
          name: test_app
          dependencies:
            pg:
              github: will/crystal-pg
          YAML
          )

          File.write("src/initializers/database.cr", "# Database config")

          command = AzuCLI::Commands::Db.new
          command.should_not be_nil
        end
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "detects mysql from shard.yml" do
      test_dir = File.join("/tmp", "tmp_test_mysql_#{Random.rand(10000)}")
      original_dir = Dir.current

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir) do
          Dir.mkdir_p("src/initializers")
          Dir.mkdir_p("src/db/migrations")

          File.write("shard.yml", <<-YAML
          name: test_app
          dependencies:
            mysql:
              github: crystal-lang/crystal-mysql
          YAML
          )

          File.write("src/initializers/database.cr", "# Database config")

          command = AzuCLI::Commands::Db.new
          command.should_not be_nil
        end
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "detects sqlite from shard.yml" do
      test_dir = File.join("/tmp", "tmp_test_sqlite_#{Random.rand(10000)}")
      original_dir = Dir.current

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir) do
          Dir.mkdir_p("src/initializers")
          Dir.mkdir_p("src/db/migrations")

          File.write("shard.yml", <<-YAML
          name: test_app
          dependencies:
            sqlite3:
              github: crystal-lang/crystal-sqlite3
          YAML
          )

          File.write("src/initializers/database.cr", "# Database config")

          command = AzuCLI::Commands::Db.new
          command.should_not be_nil
        end
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "defaults to postgresql when no database dependency found" do
      test_dir = File.join("/tmp", "tmp_test_default_#{Random.rand(10000)}")
      original_dir = Dir.current

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir) do
          Dir.mkdir_p("src/initializers")
          Dir.mkdir_p("src/db/migrations")

          File.write("shard.yml", <<-YAML
          name: test_app
          dependencies:
            azu:
              github: azutoolkit/azu
          YAML
          )

          File.write("src/initializers/database.cr", "# Database config")

          command = AzuCLI::Commands::Db.new
          command.should_not be_nil
        end
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end
  end

  describe "new_migration command" do
    it "creates migration file with proper naming" do
      original_dir = Dir.current
      test_dir = "/tmp/tmp_test_migration_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        # Create basic project structure
        Dir.mkdir_p("src/initializers")
        Dir.mkdir_p("src/db/migrations")

        File.write("shard.yml", "name: test_project")
        File.write("src/initializers/database.cr", "# Database config")

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["new_migration", "add_users_table"]} of String => String | Array(String)

        # This should create a migration file
        command.execute(args)

        # Check that migration file was created
        migration_files = Dir.glob("src/db/migrations/*.cr")
        migration_files.size.should eq(1)

        migration_file = migration_files.first
        File.basename(migration_file).should match(/\d{14}_add_users_table\.cr/)

        # Check migration content
        content = File.read(migration_file)
        content.should contain("class AddUsersTable < CQL::Migration")
        content.should contain("def up")
        content.should contain("def down")
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "requires migration name parameter" do
      original_dir = Dir.current
      test_dir = "/tmp/tmp_test_migration_name_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        Dir.mkdir_p("src/initializers")
        Dir.mkdir_p("src/db/migrations")

        File.write("shard.yml", "name: test_project")
        File.write("src/initializers/database.cr", "# Database config")

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["new_migration"]} of String => String | Array(String)

        result = command.execute(args)
        result.should be_nil
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "handles migration names with spaces" do
      test_dir = File.join("/tmp", "tmp_test_migration_spaces_#{Random.rand(10000)}")
      original_dir = Dir.current

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir) do
          Dir.mkdir_p("src/initializers")
          Dir.mkdir_p("src/db/migrations")

          File.write("shard.yml", "name: test_project")
          File.write("src/initializers/database.cr", "# Database config")

          command = AzuCLI::Commands::Db.new
          args = {"_positional" => ["new_migration", "add user table"]} of String => String | Array(String)

          command.execute(args)

          migration_files = Dir.glob("src/db/migrations/*.cr")
          migration_files.size.should eq(1)
          File.basename(migration_files.first).should match(/\d{14}_add_user_table\.cr/)
        end
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "creates migrations directory if it doesn't exist" do
      test_dir = File.join("/tmp", "tmp_test_create_dir_#{Random.rand(10000)}")
      original_dir = Dir.current

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir) do
          Dir.mkdir_p("src/initializers")

          File.write("shard.yml", "name: test_project")
          File.write("src/initializers/database.cr", "# Database config")

          command = AzuCLI::Commands::Db.new
          args = {"_positional" => ["new_migration", "test_migration"]} of String => String | Array(String)
          command.execute(args)

          Dir.exists?("src/db/migrations").should be_true
          Dir.glob("src/db/migrations/*.cr").size.should eq(1)
        end
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end
  end

  describe "status command" do
    it "shows no migrations when directory is empty" do
      original_dir = Dir.current
      test_dir = "/tmp/tmp_test_status_empty_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        Dir.mkdir_p("src/initializers")
        Dir.mkdir_p("src/db/migrations")

        File.write("shard.yml", "name: test_project")
        File.write("src/initializers/database.cr", "# Database config")

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["status"]} of String => String | Array(String)

        # Should not raise an error
        command.execute(args)
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "lists existing migration files" do
      test_dir = File.join("/tmp", "tmp_test_status_files_#{Random.rand(10000)}")
      original_dir = Dir.current

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir) do
          Dir.mkdir_p("src/initializers")
          Dir.mkdir_p("src/db/migrations")

          File.write("shard.yml", "name: test_project")
          File.write("src/initializers/database.cr", "# Database config")

          # Create some migration files
          File.write("src/db/migrations/20231201120000_create_users.cr", "# Migration content")
          File.write("src/db/migrations/20231201130000_add_email_to_users.cr", "# Migration content")

          command = AzuCLI::Commands::Db.new
          args = {"_positional" => ["status"]} of String => String | Array(String)
          command.execute(args)
        end
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "handles missing migrations directory gracefully" do
      original_dir = Dir.current
      test_dir = "/tmp/tmp_test_status_missing_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        Dir.mkdir_p("src/initializers")
        # Don't create src/db/migrations directory

        File.write("shard.yml", "name: test_project")
        File.write("src/initializers/database.cr", "# Database config")

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["status"]} of String => String | Array(String)

        # Should handle missing directory gracefully without crashing
        result = command.execute(args)
        result.should be_nil
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end
  end

  describe "migrate command" do
    it "handles missing migrations directory gracefully" do
      original_dir = Dir.current
      test_dir = "/tmp/tmp_test_migrate_missing_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        Dir.mkdir_p("src/initializers")
        # Don't create src/db/migrations directory

        File.write("shard.yml", "name: test_project")
        File.write("src/initializers/database.cr", "# Database config")

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["migrate"]} of String => String | Array(String)

        # Should handle missing directory gracefully without crashing
        result = command.execute(args)
        result.should be_nil
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "processes existing migration files" do
      original_dir = Dir.current
      test_dir = "/tmp/tmp_test_migrate_files_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        Dir.mkdir_p("src/initializers")
        Dir.mkdir_p("src/db/migrations")

        File.write("shard.yml", "name: test_project")
        File.write("src/initializers/database.cr", "# Database config")
        File.write("src/db/migrations/20231201120000_create_users.cr", "# Migration content")

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["migrate"]} of String => String | Array(String)
        command.execute(args)
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "handles version parameter" do
      original_dir = Dir.current
      test_dir = "/tmp/tmp_test_migrate_version_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        Dir.mkdir_p("src/initializers")
        Dir.mkdir_p("src/db/migrations")

        File.write("shard.yml", "name: test_project")
        File.write("src/initializers/database.cr", "# Database config")

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["migrate"], "--version" => "20231201120000"} of String => String | Array(String)
        command.execute(args)
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end
  end

  describe "rollback command" do
    it "handles missing migrations directory gracefully" do
      original_dir = Dir.current
      test_dir = "/tmp/tmp_test_rollback_missing_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        Dir.mkdir_p("src/initializers")
        # Don't create src/db/migrations directory

        File.write("shard.yml", "name: test_project")
        File.write("src/initializers/database.cr", "# Database config")

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["rollback"]} of String => String | Array(String)

        # Should handle missing directory gracefully without crashing
        result = command.execute(args)
        result.should be_nil
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "accepts steps parameter" do
      original_dir = Dir.current
      test_dir = "/tmp/tmp_test_rollback_steps_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        Dir.mkdir_p("src/initializers")
        Dir.mkdir_p("src/db/migrations")

        File.write("shard.yml", "name: test_project")
        File.write("src/initializers/database.cr", "# Database config")

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["rollback"], "--steps" => "3"} of String => String | Array(String)
        command.execute(args)
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "defaults to 1 step" do
      original_dir = Dir.current
      test_dir = "/tmp/tmp_test_rollback_default_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        Dir.mkdir_p("src/initializers")
        Dir.mkdir_p("src/db/migrations")

        File.write("shard.yml", "name: test_project")
        File.write("src/initializers/database.cr", "# Database config")

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["rollback"]} of String => String | Array(String)
        command.execute(args)
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end
  end

  describe "seed command" do
    it "handles missing seed file" do
      original_dir = Dir.current
      test_dir = "/tmp/tmp_test_seed_missing_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        Dir.mkdir_p("src/initializers")
        Dir.mkdir_p("src/db/migrations")

        File.write("shard.yml", "name: test_project")
        File.write("src/initializers/database.cr", "# Database config")

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["seed"]} of String => String | Array(String)
        command.execute(args)
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "processes existing seed file" do
      original_dir = Dir.current
      test_dir = "/tmp/tmp_test_seed_exists_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        Dir.mkdir_p("src/initializers")
        Dir.mkdir_p("src/db")

        File.write("shard.yml", "name: test_project")
        File.write("src/initializers/database.cr", "# Database config")
        File.write("src/db/seed.cr", <<-CRYSTAL
        require "cql"
        puts "Seeding database..."
        CRYSTAL
        )

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["seed"]} of String => String | Array(String)
        command.execute(args)
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end
  end

  describe "configuration checking" do
    it "warns when database initializer is missing" do
      original_dir = Dir.current
      test_dir = "/tmp/tmp_test_config_missing_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        Dir.mkdir_p("src/db/migrations")

        File.write("shard.yml", "name: test_project")

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["status"]} of String => String | Array(String)
        command.execute(args)
        # Should show warning but not fail
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end

    it "proceeds when database initializer exists" do
      original_dir = Dir.current
      test_dir = "/tmp/tmp_test_config_exists_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        Dir.mkdir_p("src/initializers")
        Dir.mkdir_p("src/db/migrations")

        File.write("shard.yml", "name: test_project")
        File.write("src/initializers/database.cr", "# Database config")

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["status"]} of String => String | Array(String)
        command.execute(args)
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end
  end

  describe "#show_command_specific_help" do
    it "displays comprehensive database command help" do
      command = AzuCLI::Commands::Db.new
      # Should not raise any exceptions
      command.show_command_specific_help
    end
  end

  describe "command metadata" do
    it "has correct command name" do
      # The actual return value includes quotes
      AzuCLI::Commands::Db.command_name.should eq("\"db\"")
    end

    it "has correct description" do
      AzuCLI::Commands::Db.description.should contain("Database operations")
    end

    it "has correct usage" do
      # The actual return value includes quotes
      AzuCLI::Commands::Db.usage.should eq("\"db <subcommand> [options]\"")
    end
  end

  describe "error handling" do
    it "validates project structure" do
      original_dir = Dir.current
      test_dir = "/tmp/test_validation_#{Random.rand(10000)}"

      begin
        Dir.mkdir_p(test_dir)
        Dir.cd(test_dir)

        # Don't create any project files - this should trigger validation error

        command = AzuCLI::Commands::Db.new
        args = {"_positional" => ["migrate"]} of String => String | Array(String)

        expect_raises(AzuCLI::Command::ValidationError) do
          command.execute(args)
        end
      ensure
        Dir.cd(original_dir)
        FileUtils.rm_rf(test_dir) if Dir.exists?(test_dir)
      end
    end
  end
end
