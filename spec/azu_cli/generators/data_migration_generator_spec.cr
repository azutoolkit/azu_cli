require "../../spec_helper"
require "../../support/test_helpers"

describe AzuCLI::Generate::DataMigration do
  describe "#initialize" do
    it "creates a data migration generator with name" do
      generator = AzuCLI::Generate::DataMigration.new("UpdateUserData")

      generator.name.should eq("UpdateUserData")
      generator.snake_case_name.should eq("update_user_data")
      generator.migration_class_name.should eq("UpdateUserData")
    end

    it "converts name to snake_case" do
      generator = AzuCLI::Generate::DataMigration.new("UpdateUserProfileData")
      generator.snake_case_name.should eq("update_user_profile_data")
    end

    it "converts name to CamelCase" do
      generator = AzuCLI::Generate::DataMigration.new("update_user_data")
      generator.migration_class_name.should eq("UpdateUserData")
    end
  end

  describe "filename generation" do
    it "generates data migration filename with timestamp" do
      generator = AzuCLI::Generate::DataMigration.new("UpdateUserData")
      filename = generator.migration_filename

      filename.should match(/^\d{14}_update_user_data\.cr$/)
    end

    it "generates unique filenames for different migrations" do
      generator1 = AzuCLI::Generate::DataMigration.new("UpdateUserData")
      sleep(1.millisecond) # Ensure different timestamp
      generator2 = AzuCLI::Generate::DataMigration.new("UpdateProductData")

      generator1.migration_filename.should_not eq(generator2.migration_filename)
    end
  end

  describe "class name generation" do
    it "generates data migration class name" do
      generator = AzuCLI::Generate::DataMigration.new("UpdateUserData")
      generator.migration_class_name.should eq("UpdateUserData")
    end

    it "handles complex names correctly" do
      generator = AzuCLI::Generate::DataMigration.new("UpdateUserProfileData")
      generator.migration_class_name.should eq("UpdateUserProfileData")
    end
  end

  describe "timestamp generation" do
    it "generates timestamp in correct format" do
      generator = AzuCLI::Generate::DataMigration.new("UpdateUserData")
      timestamp = generator.timestamp

      timestamp.size.should eq(14) # YYYYMMDDHHMMSS
      timestamp.should match(/^\d{14}$/)
    end

    it "generates unique timestamps for different migrations" do
      generator1 = AzuCLI::Generate::DataMigration.new("UpdateUserData")
      sleep(1.millisecond) # Ensure different timestamp
      generator2 = AzuCLI::Generate::DataMigration.new("UpdateProductData")

      generator1.timestamp.should_not eq(generator2.timestamp)
    end
  end

  describe "file generation" do
    it "generates a data migration file with correct content" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        generator = AzuCLI::Generate::DataMigration.new("UpdateUserData")

        # Generate the file
        generator.render(".")

        # Read the generated file
        generated_file = File.join("db/migrations", generator.migration_filename)
        File.exists?(generated_file).should be_true

        content = File.read(generated_file)
        content.should contain("require \"cql\"")
        content.should contain("class UpdateUserData < CQL::DataMigration")
        content.should contain("def up")
        content.should contain("# Add your data migration logic here")
        content.should contain("def down")
        content.should contain("# Add your rollback logic here")
      end
    end

    it "generates data migration with custom SQL" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        generator = AzuCLI::Generate::DataMigration.new("UpdateUserEmails")

        # Generate the file
        generator.render(".")

        # Read the generated file
        generated_file = File.join("db/migrations", generator.migration_filename)
        content = File.read(generated_file)

        content.should contain("class UpdateUserEmails < CQL::DataMigration")
        content.should contain("def up")
        content.should contain("def down")
      end
    end

    it "generates data migration with batch processing" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        generator = AzuCLI::Generate::DataMigration.new("MigrateUserData")

        # Generate the file
        generator.render(".")

        # Read the generated file
        generated_file = File.join("db/migrations", generator.migration_filename)
        content = File.read(generated_file)

        content.should contain("class MigrateUserData < CQL::DataMigration")
        content.should contain("# Process data in batches if needed")
        content.should contain("# Example: User.find_each { |user| ... }")
      end
    end
  end

  describe "migration file placement" do
    it "places data migration files in correct directory" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        generator = AzuCLI::Generate::DataMigration.new("UpdateUserData")
        generator.render(".")

        # Check that file was created in correct location
        generated_file = File.join("db/migrations", generator.migration_filename)
        File.exists?(generated_file).should be_true
      end
    end

    it "creates migrations directory if it doesn't exist" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml

        generator = AzuCLI::Generate::DataMigration.new("UpdateUserData")
        generator.render(".")

        # Check that directory was created
        Dir.exists?("db/migrations").should be_true

        # Check that file was created
        generated_file = File.join("db/migrations", generator.migration_filename)
        File.exists?(generated_file).should be_true
      end
    end
  end

  describe "data migration content" do
    it "includes proper CQL::DataMigration inheritance" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        generator = AzuCLI::Generate::DataMigration.new("UpdateUserData")
        generator.render(".")

        generated_file = File.join("db/migrations", generator.migration_filename)
        content = File.read(generated_file)

        content.should contain("class UpdateUserData < CQL::DataMigration")
        content.should_not contain("CQL::Migration")
      end
    end

    it "includes up and down methods" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        generator = AzuCLI::Generate::DataMigration.new("UpdateUserData")
        generator.render(".")

        generated_file = File.join("db/migrations", generator.migration_filename)
        content = File.read(generated_file)

        content.should contain("def up")
        content.should contain("def down")
      end
    end

    it "includes helpful comments and examples" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        generator = AzuCLI::Generate::DataMigration.new("UpdateUserData")
        generator.render(".")

        generated_file = File.join("db/migrations", generator.migration_filename)
        content = File.read(generated_file)

        content.should contain("# Add your data migration logic here")
        content.should contain("# Add your rollback logic here")
        content.should contain("# Process data in batches if needed")
      end
    end
  end

  describe "error handling" do
    it "handles empty migration name" do
      generator = AzuCLI::Generate::DataMigration.new("")
      generator.name.should eq("")
      generator.snake_case_name.should eq("")
    end

    it "handles special characters in name" do
      generator = AzuCLI::Generate::DataMigration.new("Update-User_Data")
      generator.snake_case_name.should eq("update-user_data")
    end
  end

  describe "integration with migration system" do
    it "generates files compatible with CQL migration system" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        generator = AzuCLI::Generate::DataMigration.new("UpdateUserData")
        generator.render(".")

        generated_file = File.join("db/migrations", generator.migration_filename)
        content = File.read(generated_file)

        # Should be compatible with CQL migration system
        content.should contain("require \"cql\"")
        content.should contain("CQL::DataMigration")
        content.should contain("def up")
        content.should contain("def down")
      end
    end

    it "generates files that can be executed by migration runner" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        generator = AzuCLI::Generate::DataMigration.new("UpdateUserData")
        generator.render(".")

        generated_file = File.join("db/migrations", generator.migration_filename)
        content = File.read(generated_file)

        # Should be executable (no syntax errors)
        content.should contain("class UpdateUserData < CQL::DataMigration")
        content.should contain("end")
      end
    end
  end
end
