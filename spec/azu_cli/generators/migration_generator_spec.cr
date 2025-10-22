require "../../spec_helper"
require "teeplate"

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
      filename.should match(/^\d{14}_add_products\.cr$/)
    end

    it "generates remove columns migration filename" do
      generator = AzuCLI::Generate::Migration.new("remove_name_from_products", {} of String => String)
      filename = generator.migration_filename
      filename.should match(/^\d{14}_remove_products\.cr$/)
    end

    it "generates change columns migration filename" do
      generator = AzuCLI::Generate::Migration.new("change_name_in_products", {} of String => String)
      filename = generator.migration_filename
      filename.should match(/^\d{14}_change_products\.cr$/)
    end

    it "generates add index migration filename" do
      generator = AzuCLI::Generate::Migration.new("add_index_to_products", {} of String => String)
      filename = generator.migration_filename
      filename.should match(/^\d{14}_add_index_products\.cr$/)
    end

    it "generates remove index migration filename" do
      generator = AzuCLI::Generate::Migration.new("remove_index_from_products", {} of String => String)
      filename = generator.migration_filename
      filename.should match(/^\d{14}_remove_index_products\.cr$/)
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
      generator.migration_class_name.should eq("AddProducts")
    end

    it "generates remove columns migration class name" do
      generator = AzuCLI::Generate::Migration.new("remove_name_from_products", {} of String => String)
      generator.migration_class_name.should eq("RemoveProducts")
    end

    it "generates change columns migration class name" do
      generator = AzuCLI::Generate::Migration.new("change_name_in_products", {} of String => String)
      generator.migration_class_name.should eq("ChangeProducts")
    end

    it "generates add index migration class name" do
      generator = AzuCLI::Generate::Migration.new("add_index_to_products", {} of String => String)
      generator.migration_class_name.should eq("AddIndexProducts")
    end

    it "generates remove index migration class name" do
      generator = AzuCLI::Generate::Migration.new("remove_index_from_products", {} of String => String)
      generator.migration_class_name.should eq("RemoveIndexProducts")
    end
  end

  it "maps field types to migration field types" do
    generator = AzuCLI::Generate::Migration.new("Test", {} of String => String)

    generator.migration_field_type("string").should eq("string")
    generator.migration_field_type("text").should eq("string")
    generator.migration_field_type("int32").should eq("integer")
    generator.migration_field_type("integer").should eq("integer")
    generator.migration_field_type("int64").should eq("bigint")
    generator.migration_field_type("float32").should eq("float")
    generator.migration_field_type("float64").should eq("decimal")
    generator.migration_field_type("float").should eq("decimal")
    generator.migration_field_type("bool").should eq("boolean")
    generator.migration_field_type("boolean").should eq("boolean")
    generator.migration_field_type("time").should eq("timestamp")
    generator.migration_field_type("datetime").should eq("timestamp")
    generator.migration_field_type("date").should eq("date")
    generator.migration_field_type("email").should eq("string")
    generator.migration_field_type("url").should eq("string")
    generator.migration_field_type("json").should eq("json")
    generator.migration_field_type("uuid").should eq("uuid")
    generator.migration_field_type("unknown").should eq("string")
  end

  it "generates migration field options" do
    generator = AzuCLI::Generate::Migration.new("Test", {} of String => String)

    generator.migration_field_options("string", "name").should eq(", null: false")
    generator.migration_field_options("string", "description").should eq("")
    generator.migration_field_options("email", "email").should eq(", null: false, unique: true")
    generator.migration_field_options("bool", "published").should eq(", default: false")
    generator.migration_field_options("time", "created_at").should eq(", default: -> { \"CURRENT_TIMESTAMP\" }")
  end

  it "determines if field should have index" do
    generator = AzuCLI::Generate::Migration.new("Test", {} of String => String)

    generator.should_add_index?("email", "email").should be_true
    generator.should_add_index?("string", "name").should be_true
    generator.should_add_index?("string", "title").should be_true
    generator.should_add_index?("string", "slug").should be_true
    generator.should_add_index?("int32", "user_id").should be_true
    generator.should_add_index?("bool", "published").should be_true
    generator.should_add_index?("string", "description").should be_false
    generator.should_add_index?("int32", "count").should be_false
  end

  it "generates index options" do
    generator = AzuCLI::Generate::Migration.new("Test", {} of String => String)

    generator.index_options("email", "email").should eq(", unique: true")
    generator.index_options("string", "slug").should eq(", unique: true")
    generator.index_options("string", "name").should eq("")
  end

  describe "file generation" do
    it "generates a create migration file with correct content" do
      attributes = {"name" => "string", "price" => "float64", "user_id" => "references"}
      generator = AzuCLI::Generate::Migration.new("create_products", attributes)

      # Generate the file
      test_dir = "./tmp_test"
      FileUtils.mkdir_p(test_dir)
      generator.render(test_dir)

      # Read the generated file
      generated_file = File.join(test_dir, generator.migration_filename)
      File.exists?(generated_file).should be_true

      content = File.read(generated_file)
      content.should contain("require \"cql\"")
      content.should contain("class CreateProducts < CQL::Migration")
      content.should contain("def up")
      content.should contain("schema.table :products do")
      content.should contain("column :name, String")
      content.should contain("column :price, Float64")
      content.should contain("timestamps")
      content.should contain("foreign_key [:user_id], references: :users")
      content.should contain("def down")
      content.should contain("schema.products.drop!")

      # Clean up
      FileUtils.rm_rf(test_dir)
    end

    it "generates an update migration file with correct content" do
      attributes = {"name" => "string", "price" => "float64"}
      generator = AzuCLI::Generate::Migration.new("update_products", attributes)

      # Generate the file
      test_dir = "./tmp_test"
      FileUtils.mkdir_p(test_dir)
      generator.render(test_dir)

      # Read the generated file
      generated_file = File.join(test_dir, generator.migration_filename)
      File.exists?(generated_file).should be_true

      content = File.read(generated_file)
      content.should contain("require \"cql\"")
      content.should contain("class UpdateProducts < CQL::Migration")
      content.should contain("schema.table :products do")
      content.should contain("column :name, String")
      content.should contain("column :price, Float64")

      # Clean up
      FileUtils.rm_rf(test_dir)
    end

    it "generates a delete migration file with correct content" do
      generator = AzuCLI::Generate::Migration.new("delete_products", {} of String => String)

      # Generate the file
      test_dir = "./tmp_test"
      FileUtils.mkdir_p(test_dir)
      generator.render(test_dir)

      # Read the generated file
      generated_file = File.join(test_dir, generator.migration_filename)
      File.exists?(generated_file).should be_true

      content = File.read(generated_file)
      content.should contain("require \"cql\"")
      content.should contain("class DeleteProducts < CQL::Migration")
      content.should contain("schema.table :products do")
      content.should contain("schema.products.drop!")

      # Clean up
      FileUtils.rm_rf(test_dir)
    end

    it "generates an add columns migration file with correct content" do
      attributes = {"name" => "string", "description" => "text"}
      generator = AzuCLI::Generate::Migration.new("add_name_to_products", attributes)

      # Generate the file
      test_dir = "./tmp_test"
      FileUtils.mkdir_p(test_dir)
      generator.render(test_dir)

      # Read the generated file
      generated_file = File.join(test_dir, generator.migration_filename)
      File.exists?(generated_file).should be_true

      content = File.read(generated_file)
      content.should contain("require \"cql\"")
      content.should contain("class AddProducts < CQL::Migration")
      content.should contain("schema.table :products do")
      content.should contain("column :name, String")
      content.should contain("column :description, String")

      # Clean up
      FileUtils.rm_rf(test_dir)
    end
  end

  it "handles timestamps correctly" do
    attributes = {"name" => "string"}
    generator = AzuCLI::Generate::Migration.new("User", attributes, timestamps: false)

    # Generate the file
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    # Read the generated file
    generated_file = File.join(test_dir, generator.migration_filename)
    content = File.read(generated_file)
    content.should_not contain("t.timestamps")

    # Clean up
    FileUtils.rm_rf(test_dir)
  end
end
