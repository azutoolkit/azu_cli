require "../../spec_helper"
require "teeplate"

describe AzuCLI::Generate::Model do
  it "creates a model generator with basic attributes" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Model.new("Product", attributes)

    generator.name.should eq("Product")
    generator.attributes.should eq(attributes)
    generator.timestamps.should be_true
    generator.database.should eq("AppSchema")
    generator.id_type.should eq("UUID")
    generator.generate_migration.should be_true
  end

  it "creates a model generator with custom options" do
    attributes = {"title" => "string", "content" => "text"}
    generator = AzuCLI::Generate::Model.new(
      "Post",
      attributes,
      timestamps: false,
      database: "AppDB",
      id_type: "Int32",
      generate_migration: false
    )

    generator.name.should eq("Post")
    generator.timestamps.should be_false
    generator.database.should eq("AppDB")
    generator.id_type.should eq("Int32")
    generator.generate_migration.should be_false
  end

  it "converts name to snake_case" do
    generator = AzuCLI::Generate::Model.new("UserProfile", {} of String => String)
    generator.snake_case_name.should eq("user_profile")
  end

  it "converts name to table name" do
    generator = AzuCLI::Generate::Model.new("Product", {} of String => String)
    generator.table_name.should eq("products")
  end

  it "maps field types to Crystal types" do
    generator = AzuCLI::Generate::Model.new("Test", {} of String => String)

    generator.crystal_type("string").should eq("String")
    generator.crystal_type("text").should eq("String")
    generator.crystal_type("int32").should eq("Int32")
    generator.crystal_type("integer").should eq("Int32")
    generator.crystal_type("int64").should eq("Int64")
    generator.crystal_type("float32").should eq("Float32")
    generator.crystal_type("float64").should eq("Float64")
    generator.crystal_type("float").should eq("Float64")
    generator.crystal_type("bool").should eq("Bool")
    generator.crystal_type("boolean").should eq("Bool")
    generator.crystal_type("time").should eq("Time")
    generator.crystal_type("datetime").should eq("Time")
    generator.crystal_type("date").should eq("Date")
    generator.crystal_type("email").should eq("String")
    generator.crystal_type("url").should eq("String")
    generator.crystal_type("json").should eq("JSON::Any")
    generator.crystal_type("uuid").should eq("UUID")
    generator.crystal_type("references").should eq("Int64")
    generator.crystal_type("belongs_to").should eq("Int64")
    generator.crystal_type("unknown").should eq("String")
  end

  it "generates constructor parameters" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Model.new("Product", attributes)

    params = generator.constructor_params
    params.should contain("@name : String")
    params.should contain("@price : Float64")
  end

  it "generates getter declarations" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Model.new("Product", attributes)

    getters = generator.getter_declarations
    getters.should contain("getter id : UUID")
    getters.should contain("getter name : String")
    getters.should contain("getter price : Float64")
    getters.should contain("getter created_at : Time")
    getters.should contain("getter updated_at : Time")
  end

  it "generates validation declarations" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Model.new("Product", attributes)

    validations = generator.validation_declarations
    validations.should contain("validate :name, presence: true")
    validations.should contain("validate :name, length: {min: 2, max: 100}")
    validations.should contain("validate :price, numericality: {greater_than: 0.0}")
  end

  it "generates a model file with correct content and migration by default" do
    attributes = {"name" => "string", "price" => "float64"}
    generator = AzuCLI::Generate::Model.new("Product", attributes)

    # Generate the file
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    # Read the generated file
    generated_file = File.join(test_dir, "product.cr")
    File.exists?(generated_file).should be_true

    content = File.read(generated_file)
    content.should contain("module Product")
    content.should contain("struct ProductModel")
    content.should contain("include CQL::ActiveRecord::Model(UUID)")
    content.should contain("db_context AppSchema, :products")
    content.should contain("getter id : UUID?")
    content.should contain("getter name : String")
    content.should contain("getter price : Float64")
    content.should contain("getter created_at : Time?")
    content.should contain("getter updated_at : Time?")
    content.should contain("validate :name, presence: true")
    content.should contain("validate :name, length: {min: 2, max: 100}")
    content.should contain("validate :price, numericality: {greater_than: 0.0}")
    content.should contain("def initialize(@name : String, @price : Float64)")
    content.should contain("end")

    # Migration file should also be generated by default
    migration_dir = File.join(test_dir, "db", "migrations")
    migration_files = Dir.entries(migration_dir).select { |f| f =~ /create_products/ }
    migration_files.size.should be > 0
    migration_file = migration_files.first
    migration_file.should_not be_nil
    File.exists?(File.join(migration_dir, migration_file)).should be_true

    # Clean up
    FileUtils.rm_rf(test_dir)
  end

  it "does not generate migration if generate_migration is false" do
    attributes = {"name" => "string"}
    generator = AzuCLI::Generate::Model.new("User", attributes, generate_migration: false)

    # Generate the file
    test_dir = "./tmp_test"
    FileUtils.mkdir_p(test_dir)
    generator.render(test_dir)

    # Read the generated file
    generated_file = File.join(test_dir, "user.cr")
    File.exists?(generated_file).should be_true

    # There should be no migration file
    migration_file = Dir.entries(test_dir).find { |f| f =~ /create_users/ }
    migration_file.should be_nil

    # Clean up
    FileUtils.rm_rf(test_dir)
  end

  it "handles associations correctly" do
    attributes = {"user_id" => "references", "comments" => "has_many"}
    generator = AzuCLI::Generate::Model.new("Post", attributes)

    generator.has_associations?.should be_true
    associations = generator.association_declarations
    associations.should contain("belongs_to :user, User")
    associations.should contain("has_many :comments, Comment")
  end

  it "handles scopes correctly" do
    attributes = {"published" => "bool", "title" => "string"}
    generator = AzuCLI::Generate::Model.new("Post", attributes)

    generator.has_scopes?.should be_true
    scopes = generator.scope_declarations
    scopes.should contain("scope :published, -> { where(published: true) }")
    scopes.should contain("scope :by_title, ->(value : String) { where(\"title ILIKE ?\", \"%\" + value + \"%\") }")
  end

  it "handles timestamps correctly" do
    attributes = {"name" => "string"}
    generator = AzuCLI::Generate::Model.new("User", attributes, timestamps: false)

    getters = generator.getter_declarations
    getters.should_not contain("created_at")
    getters.should_not contain("updated_at")
  end

  it "handles different ID types" do
    attributes = {"name" => "string"}
    generator = AzuCLI::Generate::Model.new("User", attributes, id_type: "Int32")

    getters = generator.getter_declarations
    getters.should contain("getter id : Int32")
  end
end
