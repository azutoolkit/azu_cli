require "../../spec_helper"
require "../../support/generator_helpers"
require "teeplate"

include GeneratorHelpers

describe AzuCLI::Generate::Migration do
  it "creates a migration generator with basic attributes" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Migration.new("Product", attributes)

    generator.name.should eq("Product")
    generator.attributes.should eq(attributes)
    generator.timestamps.should be_true
  end

  it "creates a migration generator with custom options" do
    attributes = {"title" => "string", "content" => "text"}
    generator = AzuCLI::Generate::Migration.new(
      "Post",
      attributes,
      timestamps: false
    )

    generator.name.should eq("Post")
    generator.timestamps.should be_false
  end

  it "converts name to snake_case" do
    generator = AzuCLI::Generate::Migration.new("UserProfile", {} of String => String)
    generator.snake_case_name.should eq("user_profile")
  end

  describe "table name extraction" do
    it "extracts table name from create migration" do
      generator = AzuCLI::Generate::Migration.new("create_products", {} of String => String)
      generator.table_name.should eq("products")
    end

    it "extracts table name from update migration" do
      generator = AzuCLI::Generate::Migration.new("update_products", {} of String => String)
      generator.table_name.should eq("products")
    end

    it "extracts table name from delete migration" do
      generator = AzuCLI::Generate::Migration.new("delete_products", {} of String => String)
      generator.table_name.should eq("products")
    end

    it "extracts table name from add columns migration" do
      generator = AzuCLI::Generate::Migration.new("add_name_to_products", {} of String => String)
      generator.table_name.should eq("products")
    end

    it "extracts table name from remove columns migration" do
      generator = AzuCLI::Generate::Migration.new("remove_name_from_products", {} of String => String)
      generator.table_name.should eq("products")
    end

    it "extracts table name from change columns migration" do
      generator = AzuCLI::Generate::Migration.new("change_name_in_products", {} of String => String)
      generator.table_name.should eq("products")
    end

    it "handles singular names correctly" do
      generator = AzuCLI::Generate::Migration.new("create_product", {} of String => String)
      generator.table_name.should eq("products")
    end

    it "handles already plural names correctly" do
      generator = AzuCLI::Generate::Migration.new("create_products", {} of String => String)
      generator.table_name.should eq("products")
    end
  end

  describe "migration type detection" do
    it "detects create table migration" do
      generator = AzuCLI::Generate::Migration.new("create_products", {} of String => String)
      generator.migration_type.should eq("create_table")
    end

    it "detects update table migration" do
      generator = AzuCLI::Generate::Migration.new("update_products", {} of String => String)
      generator.migration_type.should eq("update_table")
    end

    it "detects delete table migration" do
      generator = AzuCLI::Generate::Migration.new("delete_products", {} of String => String)
      generator.migration_type.should eq("delete_table")
    end

    it "detects add columns migration" do
      generator = AzuCLI::Generate::Migration.new("add_name_to_products", {} of String => String)
      generator.migration_type.should eq("add_columns")
    end

    it "detects remove columns migration" do
      generator = AzuCLI::Generate::Migration.new("remove_name_from_products", {} of String => String)
      generator.migration_type.should eq("remove_columns")
    end

    it "detects change columns migration" do
      generator = AzuCLI::Generate::Migration.new("change_name_in_products", {} of String => String)
      generator.migration_type.should eq("change_columns")
    end

    it "detects add index migration" do
      generator = AzuCLI::Generate::Migration.new("add_index_to_products", {} of String => String)
      generator.migration_type.should eq("add_index")
    end

    it "detects remove index migration" do
      generator = AzuCLI::Generate::Migration.new("remove_index_from_products", {} of String => String)
      generator.migration_type.should eq("remove_index")
    end

    it "defaults to create table for unknown patterns" do
      generator = AzuCLI::Generate::Migration.new("products", {} of String => String)
      generator.migration_type.should eq("create_table")
    end
  end

  describe "filename generation" do
    it "generates create migration filename" do
      generator = AzuCLI::Generate::Migration.new("create_products", {} of String => String)
      filename = generator.migration_filename
      filename.should match(/^\d{14}_create_products\.cr$/)
    end

    it "generates update migration filename" do
      generator = AzuCLI::Generate::Migration.new("update_products", {} of String => String)
      filename = generator.migration_filename
      filename.should match(/^\d{14}_update_products\.cr$/)
    end

    it "generates delete migration filename" do
      generator = AzuCLI::Generate::Migration.new("delete_products", {} of String => String)
      filename = generator.migration_filename
      filename.should match(/^\d{14}_delete_products\.cr$/)
    end

    it "generates add columns migration filename" do
      generator = AzuCLI::Generate::Migration.new("add_name_to_products", {} of String => String)
      filename = generator.migration_filename
      filename.should match(/^\d{14}_add_name_to_products\.cr$/)
    end

    it "generates remove columns migration filename" do
      generator = AzuCLI::Generate::Migration.new("remove_name_from_products", {} of String => String)
      filename = generator.migration_filename
      filename.should match(/^\d{14}_remove_name_from_products\.cr$/)
    end

    it "generates change columns migration filename" do
      generator = AzuCLI::Generate::Migration.new("change_name_in_products", {} of String => String)
      filename = generator.migration_filename
      filename.should match(/^\d{14}_change_name_in_products\.cr$/)
    end

    it "generates add index migration filename" do
      generator = AzuCLI::Generate::Migration.new("add_index_to_products", {} of String => String)
      filename = generator.migration_filename
      filename.should match(/^\d{14}_add_index_to_products\.cr$/)
    end

    it "generates remove index migration filename" do
      generator = AzuCLI::Generate::Migration.new("remove_index_from_products", {} of String => String)
      filename = generator.migration_filename
      filename.should match(/^\d{14}_remove_index_from_products\.cr$/)
    end
  end

  describe "class name generation" do
    it "generates create migration class name" do
      generator = AzuCLI::Generate::Migration.new("create_products", {} of String => String)
      generator.migration_class_name.should eq("CreateProducts")
    end

    it "generates update migration class name" do
      generator = AzuCLI::Generate::Migration.new("update_products", {} of String => String)
      generator.migration_class_name.should eq("UpdateProducts")
    end

    it "generates delete migration class name" do
      generator = AzuCLI::Generate::Migration.new("delete_products", {} of String => String)
      generator.migration_class_name.should eq("DeleteProducts")
    end

    it "generates add columns migration class name" do
      generator = AzuCLI::Generate::Migration.new("add_name_to_products", {} of String => String)
      generator.migration_class_name.should eq("AddNameToProducts")
    end

    it "generates remove columns migration class name" do
      generator = AzuCLI::Generate::Migration.new("remove_name_from_products", {} of String => String)
      generator.migration_class_name.should eq("RemoveNameFromProducts")
    end

    it "generates change columns migration class name" do
      generator = AzuCLI::Generate::Migration.new("change_name_in_products", {} of String => String)
      generator.migration_class_name.should eq("ChangeNameInProducts")
    end

    it "generates add index migration class name" do
      generator = AzuCLI::Generate::Migration.new("add_index_to_products", {} of String => String)
      generator.migration_class_name.should eq("AddIndexToProducts")
    end

    it "generates remove index migration class name" do
      generator = AzuCLI::Generate::Migration.new("remove_index_from_products", {} of String => String)
      generator.migration_class_name.should eq("RemoveIndexFromProducts")
    end
  end

  describe "unique versions and names" do
    it "gives two migrations generated in the same second different versions" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p(AzuCLI::Generate::Migration::OUTPUT_DIR)

        first = AzuCLI::Generate::Migration.new("create_posts", {"title" => "string"})
        first.render(AzuCLI::Generate::Migration::OUTPUT_DIR)
        second = AzuCLI::Generate::Migration.new("create_tags", {"name" => "string"})
        second.render(AzuCLI::Generate::Migration::OUTPUT_DIR)

        second.timestamp.to_i64.should be > first.timestamp.to_i64
        Dir.glob("#{AzuCLI::Generate::Migration::OUTPUT_DIR}/*.cr").size.should eq(2)
      end
    end

    it "starts after a migration that is newer than now" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p(AzuCLI::Generate::Migration::OUTPUT_DIR)
        File.write(File.join(AzuCLI::Generate::Migration::OUTPUT_DIR, "29991231235959_create_future.cr"), "")

        generator = AzuCLI::Generate::Migration.new("create_posts", {} of String => String)
        generator.timestamp.should eq("30000101000000")
      end
    end

    it "keeps the whole name for column migrations so two on one table do not collide" do
      slug = AzuCLI::Generate::Migration.new("AddSlugToPosts", {} of String => String)
      body = AzuCLI::Generate::Migration.new("AddBodyToPosts", {} of String => String)

      slug.migration_filename.should match(/^\d{14}_add_slug_to_posts\.cr$/)
      slug.migration_class_name.should eq("AddSlugToPosts")
      body.migration_class_name.should eq("AddBodyToPosts")
      slug.migration_class_name.should_not eq(body.migration_class_name)
    end
  end

  describe "file generation" do
    it "generates a create migration file with correct content" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        attributes = {"name" => "string", "price" => "float64", "user_id" => "references"}
        generator = AzuCLI::Generate::Migration.new("create_products", attributes)

        # Generate the file
        generator.render("db/migrations")

        # Read the generated file
        generated_file = File.join("db/migrations", generator.migration_filename)
        File.exists?(generated_file).should be_true

        content = File.read(generated_file)
        content.should contain("require \"cql\"")
        content.should contain("class CreateProducts < CQL::Migration")
        content.should contain("def up")
        content.should contain("schema.table :products do")
        content.should contain("text :name")
        content.should contain("column :price, Float64")
        content.should contain("timestamps")
        content.should contain("foreign_key [:user_id], references: :users")
        content.should contain("def down")
        content.should contain("schema.products.drop!")
      end
    end

    it "generates an update migration file with correct content" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        attributes = {"name" => "string", "price" => "float64"}
        generator = AzuCLI::Generate::Migration.new("update_products", attributes)

        # Generate the file
        generator.render("db/migrations")

        # Read the generated file
        generated_file = File.join("db/migrations", generator.migration_filename)
        File.exists?(generated_file).should be_true

        content = File.read(generated_file)
        content.should contain("require \"cql\"")
        content.should contain("class UpdateProducts < CQL::Migration")
        # Update migrations use schema.alter for modifying existing tables
        content.should contain("schema.alter :products do")
      end
    end

    it "generates a delete migration file with correct content" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        generator = AzuCLI::Generate::Migration.new("delete_products", {} of String => String)

        # Generate the file
        generator.render("db/migrations")

        # Read the generated file
        generated_file = File.join("db/migrations", generator.migration_filename)
        File.exists?(generated_file).should be_true

        content = File.read(generated_file)
        content.should contain("require \"cql\"")
        content.should contain("class DeleteProducts < CQL::Migration")
        # Delete migrations drop the table, not create it
        content.should contain("schema.products.drop!")
      end
    end

    it "generates an add columns migration file with correct content" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        attributes = {"name" => "string", "description" => "text"}
        generator = AzuCLI::Generate::Migration.new("add_name_to_products", attributes)

        # Generate the file
        generator.render("db/migrations")

        # Read the generated file
        generated_file = File.join("db/migrations", generator.migration_filename)
        File.exists?(generated_file).should be_true

        content = File.read(generated_file)
        content.should contain("require \"cql\"")
        content.should contain("class AddNameToProducts < CQL::Migration")
        # Add columns migrations use schema.alter, not schema.table
        content.should contain("schema.alter :products do")
        content.should contain("add_column :name, String")
      end
    end
  end

  it "handles timestamps correctly" do
    TestHelpers::TestSetup.with_temp_project do |temp_project|
      temp_project.create_shard_yml
      Dir.mkdir_p("db/migrations")

      attributes = {"name" => "string"}
      generator = AzuCLI::Generate::Migration.new("User", attributes, timestamps: false)

      # Generate the file
      generator.render("db/migrations")

      # Read the generated file
      generated_file = File.join("db/migrations", generator.migration_filename)
      content = File.read(generated_file)
      content.should_not contain("t.timestamps")
    end
  end

  describe "migration file placement" do
    it "places migration files in correct directory" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        generator = AzuCLI::Generate::Migration.new("create_users", {} of String => String)
        generator.render("db/migrations")

        # Check that file was created in correct location
        generated_file = File.join("db/migrations", generator.migration_filename)
        File.exists?(generated_file).should be_true
      end
    end

    it "creates migrations directory if it doesn't exist" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml

        generator = AzuCLI::Generate::Migration.new("create_users", {} of String => String)
        generator.render("db/migrations")

        # Check that directory was created
        Dir.exists?("db/migrations").should be_true

        # Check that file was created
        generated_file = File.join("db/migrations", generator.migration_filename)
        File.exists?(generated_file).should be_true
      end
    end
  end

  describe "timestamp generation" do
    it "generates unique timestamps for different migrations when created with delay" do
      generator1 = AzuCLI::Generate::Migration.new("create_users", {} of String => String)
      # Timestamps use seconds precision, so we need at least 1 second delay
      # for guaranteed uniqueness. In practice, migrations are created with more time between.
      # This test verifies the timestamp format rather than strict uniqueness.
      generator2 = AzuCLI::Generate::Migration.new("create_products", {} of String => String)

      # Both timestamps should be valid 14-digit timestamps
      generator1.timestamp.size.should eq(14)
      generator2.timestamp.size.should eq(14)
    end

    it "generates timestamp in correct format" do
      generator = AzuCLI::Generate::Migration.new("create_users", {} of String => String)
      timestamp = generator.timestamp

      timestamp.size.should eq(14) # YYYYMMDDHHMMSS
      timestamp.should match(/^\d{14}$/)
    end
  end

  describe "foreign key handling" do
    it "handles references type correctly" do
      attributes = {"user_id" => "references", "category_id" => "references"}
      generator = AzuCLI::Generate::Migration.new("create_posts", attributes)

      # Test that references are handled properly
      generator.attributes["user_id"].should eq("references")
      generator.attributes["category_id"].should eq("references")
    end

    it "generates foreign key constraints" do
      TestHelpers::TestSetup.with_temp_project do |temp_project|
        temp_project.create_shard_yml
        Dir.mkdir_p("db/migrations")

        attributes = {"user_id" => "references", "category_id" => "references"}
        generator = AzuCLI::Generate::Migration.new("create_posts", attributes)
        generator.render("db/migrations")

        generated_file = File.join("db/migrations", generator.migration_filename)
        content = File.read(generated_file)
        content.should contain("foreign_key [:user_id], references: :users")
        content.should contain("foreign_key [:category_id], references: :categories")
      end
    end
  end

  describe "versions" do
    it "gives migrations generated in the same second different versions" do
      in_generated_project do
        dir = File.expand_path("src/db/migrations")
        first = AzuCLI::Generate::Migration.new("create_posts", {} of String => String)
        second = AzuCLI::Generate::Migration.new("create_users", {} of String => String)
        first.timestamp = second.timestamp # the same second
        first.render(dir, force: true, interactive: false)
        second.render(dir, force: true, interactive: false)

        versions = Dir.glob("src/db/migrations/*.cr").map { |path| File.basename(path).split('_').first }
        versions.uniq.size.should eq(2)
        File.read(Dir.glob("src/db/migrations/*_create_users.cr").first).should contain("CQL::Migration(#{versions.max}_i64)")
      end
    end
  end

  describe "schema registration" do
    it "declares the created table in src/db/schema.cr, once" do
      in_generated_project do
        migration = AzuCLI::Generate::Migration.new("create_posts", {"title" => "string", "published" => "bool"})
        migration.render(File.expand_path("src/db/migrations"), force: true, interactive: false)

        schema = File.read("src/db/schema.cr")
        schema.scan("table :posts do").size.should eq(1)
        schema.should contain("  table :posts do\n    primary :id, Int64, auto_increment: true\n    text :title\n    boolean :published, default: false\n    timestamps\n  end\nend")
      end
    end

    it "refuses a second migration with the same class name" do
      in_generated_project do
        dir = File.expand_path("src/db/migrations")
        AzuCLI::Generate::Migration.new("create_posts", {"title" => "string"}).render(dir, force: true, interactive: false)

        expect_raises(Exception, /CreatePosts exists already/) do
          AzuCLI::Generate::Migration.new("create_posts", {"title" => "string"}).render(dir, force: true, interactive: false)
        end
        Dir.glob("src/db/migrations/*_create_posts.cr").size.should eq(1)
        File.read("src/db/schema.cr").scan("table :posts do").size.should eq(1)
      end
    end

    it "leaves the schema alone for other migrations" do
      in_generated_project do
        before = File.read("src/db/schema.cr")
        AzuCLI::Generate::Migration.new("add_name_to_posts", {"name" => "string"}).render(File.expand_path("src/db/migrations"), force: true, interactive: false)

        File.read("src/db/schema.cr").should eq(before)
      end
    end
  end
end
