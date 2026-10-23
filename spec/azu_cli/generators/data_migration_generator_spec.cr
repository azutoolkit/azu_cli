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
      AzuCLI::Generate::DataMigration.new("UpdateUserProfileData").snake_case_name.should eq("update_user_profile_data")
    end

    it "converts name to CamelCase" do
      AzuCLI::Generate::DataMigration.new("update_user_data").migration_class_name.should eq("UpdateUserData")
    end

    it "handles an empty name" do
      generator = AzuCLI::Generate::DataMigration.new("")
      generator.name.should eq("")
      generator.snake_case_name.should eq("")
    end
  end

  it "writes to src/db/data_migrations" do
    AzuCLI::Generate::DataMigration::OUTPUT_DIR.should eq("./src/db/data_migrations")
  end

  it "names the file <timestamp>_data_<name>.cr" do
    generator = AzuCLI::Generate::DataMigration.new("UpdateUserData")
    generator.migration_filename.should match(/^\d{14}_data_update_user_data\.cr$/)
    generator.timestamp.should match(/^\d{14}$/)
  end

  describe "versions" do
    it "gives data migrations generated back to back different versions" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        dir = AzuCLI::Generate::DataMigration::OUTPUT_DIR
        Dir.mkdir_p(dir)

        first = AzuCLI::Generate::DataMigration.new("UpdateUserData")
        first.render(dir)
        second = AzuCLI::Generate::DataMigration.new("UpdateProductData")
        second.render(dir)

        second.timestamp.to_i64.should be > first.timestamp.to_i64
        Dir.glob("#{dir}/*.cr").size.should eq(2)
      end
    end

    it "does not reuse the version of a schema migration" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p(AzuCLI::Generate::Migration::OUTPUT_DIR)
        File.write(File.join(AzuCLI::Generate::Migration::OUTPUT_DIR, "29991231235959_create_posts.cr"), "")

        AzuCLI::Generate::DataMigration.new("BackfillSlugs").timestamp.should eq("30000101000000")
      end
    end

    it "makes the next schema migration skip the version of a data migration" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p(AzuCLI::Generate::DataMigration::OUTPUT_DIR)
        File.write(File.join(AzuCLI::Generate::DataMigration::OUTPUT_DIR, "29991231235959_data_backfill.cr"), "")

        AzuCLI::Generate::Migration.new("create_posts", {} of String => String).timestamp.should eq("30000101000000")
      end
    end
  end

  describe "file generation" do
    it "generates a CQL::Migration with up and down" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        dir = AzuCLI::Generate::DataMigration::OUTPUT_DIR
        Dir.mkdir_p(dir)

        generator = AzuCLI::Generate::DataMigration.new("UpdateUserData")
        generator.render(dir)

        generated_file = File.join(dir, generator.migration_filename)
        File.exists?(generated_file).should be_true

        content = File.read(generated_file)
        content.should contain("require \"../../models/**\"")
        content.should contain("class UpdateUserData < CQL::Migration(#{generator.timestamp}_i64)")
        content.should_not contain("CQL::DataMigration")
        content.should contain("def up")
        content.should contain("def down")
        content.should contain("azu db:data:migrate")
      end
    end

    it "uses the class name given in snake case" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        dir = AzuCLI::Generate::DataMigration::OUTPUT_DIR
        Dir.mkdir_p(dir)

        generator = AzuCLI::Generate::DataMigration.new("migrate_user_data")
        generator.render(dir)

        File.read(File.join(dir, generator.migration_filename)).should contain("class MigrateUserData < CQL::Migration")
      end
    end
  end
end
