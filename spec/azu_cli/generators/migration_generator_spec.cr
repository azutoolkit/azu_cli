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

  it "converts name to table name" do
    generator = AzuCLI::Generate::Migration.new("Product", {} of String => String)
    generator.table_name.should eq("products")
  end

  it "generates migration filename" do
    generator = AzuCLI::Generate::Migration.new("Product", {} of String => String)
    filename = generator.migration_filename

    filename.should match(/^\d{14}_create_products\.cr$/)
  end

  it "generates migration class name" do
    generator = AzuCLI::Generate::Migration.new("Product", {} of String => String)
    generator.migration_class_name.should eq("CreateProducts")
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

  it "generates a migration file with correct content" do
    attributes = {"name" => "string", "price" => "float64", "user_id" => "references"}
    generator = AzuCLI::Generate::Migration.new("Product", attributes)

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
    content.should contain("create_table :products do |t|")
    content.should contain("t.string :name, null: false")
    content.should contain("t.decimal :price")
    content.should contain("t.timestamps")
    content.should contain("add_foreign_key :products, :users, column: :user_id, on_delete: :cascade")
    content.should contain("def down")
    content.should contain("drop_table :products")

    # Clean up
    FileUtils.rm_rf(test_dir)
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
